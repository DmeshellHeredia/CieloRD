import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/concurrency/write_gate.dart';
import '../../../core/database/app_database.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../../media/domain/media_service.dart';
import '../domain/erase_all_service.dart';

/// Borrado de todo el espacio privado de CieloRD.
///
/// Solo toca: el archivo SQLite, `media/` y `staging/` bajo el directorio de
/// soporte, la caché privada y las preferencias de plugins. Los recursos
/// empaquetados y todo lo que esté fuera de esos directorios no se tocan.
///
/// Es idempotente y sobrevive a la muerte del proceso: un marcador durable se
/// escribe antes de empezar y se elimina solo tras verificar que no queda nada.
/// No es un borrado forense: el sistema de archivos decide cuándo reutiliza
/// los bloques liberados.
final class LocalEraseAllService implements EraseAllService {
  LocalEraseAllService({
    required this.database,
    required this.gate,
    Future<Directory> Function()? supportDirectory,
    this.cacheDirectory,
    this.recorder,
    this.player,
    this.resetStaged,
    this.clearPreferences,
    Future<void> Function(FileSystemEntity entity)? deleteEntity,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _deleteEntity = deleteEntity ?? _delete;

  static const String markerName = 'erase_all.pending';
  static const List<String> managedDirectories = ['media', 'staging'];
  static const List<String> _tables = [
    'observations',
    'media_files',
    'observation_media',
    'observer_profile',
    'app_settings',
    'pending_file_deletions',
  ];

  final AppDatabase database;
  final WriteGate gate;
  final Future<Directory> Function() _supportDirectory;

  /// Caché privada de la app. Nula en plataformas donde el directorio temporal
  /// es compartido con otros programas: ahí no se toca.
  final Future<Directory> Function()? cacheDirectory;
  final VoiceRecorder? recorder;
  final AudioPlayerService? player;
  final void Function()? resetStaged;
  final Future<void> Function()? clearPreferences;
  final Future<void> Function(FileSystemEntity entity) _deleteEntity;

  static Future<void> _delete(FileSystemEntity entity) async {
    await entity.delete();
  }

  Future<File> _marker() async =>
      File(p.join((await _supportDirectory()).path, markerName));

  @override
  Future<bool> hasPendingErase() async {
    try {
      return await (await _marker()).exists();
    } on Object {
      return false;
    }
  }

  @override
  Future<Result<EraseAllPreview>> preview() async {
    try {
      final db = await database.open();
      Future<int> count(String sql) async =>
          (await db.rawQuery(sql)).single.values.single! as int;
      final rows = await db.query(
        'media_files',
        columns: ['id', 'relative_path', 'mime_type'],
      );
      final known = <String>{
        for (final row in rows) ...[
          row['relative_path']! as String,
          if ((row['mime_type']! as String).startsWith('image/'))
            'media/thumbnails/${row['id']}.jpg',
        ],
      };
      final root = await _supportDirectory();
      var temporary = 0;
      for (final name in managedDirectories) {
        for (final entity in await _contents(
          Directory(p.join(root.path, name)),
        )) {
          if (entity is Directory) continue;
          final relative = p.split(p.relative(entity.path, from: root.path));
          if (!known.contains(p.posix.joinAll(relative))) temporary++;
        }
      }
      final cache = await cacheDirectory?.call();
      if (cache != null) {
        temporary += (await _contents(cache)).whereType<File>().length;
      }
      return Success(
        EraseAllPreview(
          published: await count(
            "SELECT COUNT(*) FROM observations WHERE status = 'published'",
          ),
          drafts: await count(
            "SELECT COUNT(*) FROM observations WHERE status = 'draft'",
          ),
          photos: await count(
            "SELECT COUNT(*) FROM observation_media WHERE kind = 'photo'",
          ),
          audios: await count(
            "SELECT COUNT(*) FROM observation_media WHERE kind = 'audio'",
          ),
          hasProfile: await count('SELECT COUNT(*) FROM observer_profile') > 0,
          hasProfilePhoto:
              await count(
                'SELECT COUNT(photo_media_id) FROM observer_profile',
              ) >
              0,
          hasSettings: await count('SELECT COUNT(*) FROM app_settings') > 0,
          temporaryFiles: temporary,
        ),
      );
    } on Object catch (error) {
      return Failure(
        AppFailure(FailureCode.persistence, message: error.toString()),
      );
    }
  }

  @override
  Future<Result<EraseAllReport>> eraseAll() async {
    if (gate.isClosed) return Failure(AppFailure(FailureCode.busy));
    await _quietly(() => recorder?.cancel());
    await _quietly(() => player?.stop());
    try {
      return await gate.exclusive(_erase);
    } on WriteGateClosed {
      return Failure(AppFailure(FailureCode.busy));
    } on Object catch (error) {
      return Failure(AppFailure(FailureCode.io, message: error.toString()));
    }
  }

  Future<Result<EraseAllReport>> _erase() async {
    final root = await _supportDirectory();
    final marker = await _marker();
    // Con el disco lleno no se puede escribir el marcador, pero borrar sigue
    // siendo posible (y es justo lo que liberará espacio).
    await _quietly(() async {
      await root.create(recursive: true);
      await marker.writeAsString('erase-all', flush: true);
    });

    resetStaged?.call();
    await _quietly(database.destroy);

    final cache = await cacheDirectory?.call();
    final targets = [
      for (final name in managedDirectories) Directory(p.join(root.path, name)),
      ?cache,
    ];
    for (final directory in targets) {
      await _wipe(directory);
    }

    var preferencesCleared = true;
    if (clearPreferences != null) {
      try {
        await clearPreferences!();
      } on Object {
        preferencesCleared = false;
      }
    }

    // Reconciliación: se da por hecho solo lo que se comprueba en disco.
    final residual = <String>[];
    for (final directory in targets) {
      final base = directory == cache ? 'cache' : p.basename(directory.path);
      for (final entity in await _contents(directory)) {
        if (entity is Directory) continue;
        residual.add(
          p.posix.joinAll([
            base,
            ...p.split(p.relative(entity.path, from: directory.path)),
          ]),
        );
      }
    }
    final databaseCleared = await _databaseIsClear();
    var report = EraseAllReport(
      pendingFiles: residual.length,
      databaseCleared: databaseCleared,
      preferencesCleared: preferencesCleared,
      residual: List.unmodifiable(residual),
    );
    if (report.isComplete) {
      try {
        if (await marker.exists()) await marker.delete();
      } on Object {
        report = const EraseAllReport(pendingFiles: 1, residual: [markerName]);
      }
    }
    return Success(report);
  }

  /// La base anterior ya no existe y la nueva nace vacía.
  Future<bool> _databaseIsClear() async {
    try {
      for (final file in database.files) {
        if (await file.exists()) return false;
      }
      final db = await database.open();
      for (final table in _tables) {
        final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
        if (rows.single['n'] != 0) return false;
      }
      return true;
    } on Object {
      return false;
    }
  }

  /// Elimina el contenido archivo por archivo: un fallo no detiene al resto.
  /// Los enlaces simbólicos se eliminan sin seguirlos.
  Future<void> _wipe(Directory directory) async {
    final entities = await _contents(directory);
    for (final entity in entities) {
      if (entity is! Directory) await _quietly(() => _deleteEntity(entity));
    }
    for (final entity in entities.reversed) {
      if (entity is Directory) await _quietly(() => _deleteEntity(entity));
    }
  }

  /// Contenido recursivo, padres antes que hijos.
  static Future<List<FileSystemEntity>> _contents(Directory directory) async {
    if (!await directory.exists()) return const [];
    final found = <FileSystemEntity>[];
    final pending = [directory];
    while (pending.isNotEmpty) {
      final current = pending.removeAt(0);
      await for (final entity in current.list(followLinks: false)) {
        found.add(entity);
        if (entity is Directory) pending.add(entity);
      }
    }
    return found;
  }

  static Future<void> _quietly(Future<void>? Function() action) async {
    try {
      await action()?.timeout(const Duration(seconds: 10));
    } on Object {
      // La verificación final decide si quedó algo pendiente.
    }
  }
}
