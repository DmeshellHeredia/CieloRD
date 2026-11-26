import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/core/concurrency/write_gate.dart';
import 'package:cielo_rd/core/database/app_database.dart';
import 'package:cielo_rd/features/backup/data/backup_codec.dart';
import 'package:cielo_rd/features/backup/data/local_backup_service.dart';
import 'package:cielo_rd/features/backup/data/platform_documents.dart';
import 'package:cielo_rd/features/maintenance/data/local_erase_all_service.dart';
import 'package:cielo_rd/features/media/data/local_media_service.dart';
import 'package:cielo_rd/features/media/data/media_maintenance_service.dart';
import 'package:cielo_rd/features/observations/data/sqlite_observation_store.dart';
import 'package:cielo_rd/features/profile/data/sqlite_profile_repository.dart';
import 'package:cielo_rd/features/settings/data/sqlite_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

T ok<T>(Result<T> result) => switch (result) {
  Success<T>(:final T value) => value,
  Failure<T>(:final AppFailure failure) => throw TestFailure(
    'Failure ${failure.code}: ${failure.message} ${failure.fieldErrors}',
  ),
};

AppFailure failed<T>(Result<T> result) => switch (result) {
  Success<T>(:final T value) => throw TestFailure('Success inesperado: $value'),
  Failure<T>(:final AppFailure failure) => failure,
};

/// Un "teléfono" completo: SQLite/FFI real y sistema de archivos real en un
/// directorio temporal, con los mismos colaboradores que `main.dart`.
final class HitoCEnv {
  HitoCEnv._(this.root, {DateTime Function()? clock})
    : clock = clock ?? (() => DateTime.utc(2026, 11, 23, 22)) {
    support.createSync(recursive: true);
    cache.createSync(recursive: true);
    outside.createSync(recursive: true);
    open();
  }

  static Future<HitoCEnv> create({DateTime Function()? clock}) async {
    sqfliteFfiInit();
    final root = await Directory.systemTemp.createTemp('cielord_hito_c_');
    final env = HitoCEnv._(root, clock: clock);
    addTearDown(env.dispose);
    return env;
  }

  final Directory root;
  final DateTime Function() clock;
  late final Directory support = Directory('${root.path}/support');
  late final Directory cache = Directory('${root.path}/cache');

  /// Galería y documentos: fuera del espacio privado.
  late final Directory outside = Directory('${root.path}/outside');

  late AppDatabase database;
  late WriteGate gate;
  late SqliteObservationStore store;
  late LocalMediaService media;
  late MediaMaintenanceService maintenance;
  late SqliteProfileRepository profile;
  late SqliteSettingsRepository settings;
  late LocalBackupService backup;
  int _seq = 0;
  int _shade = 0;
  String prefix = 'a';
  XFile? nextPick;
  FutureOr<void> Function(String step)? onImportStep;
  DocumentStore documents = const PlatformDocuments();
  BackupLimits limits = const BackupLimits();

  /// Equivale a arrancar la app.
  void open() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${root.path}/cielo_rd.db',
    );
    gate = WriteGate();
    Future<Directory> dir() async => support;
    store = SqliteObservationStore(
      database: database,
      gate: gate,
      clock: clock,
      newId: () => '$prefix-obs-${++_seq}',
    );
    media = LocalMediaService(
      database: database,
      gate: gate,
      supportDirectory: dir,
      pick: (_) async => nextPick,
      recover: () async => const [],
      newId: () => '$prefix-media-${++_seq}',
    );
    maintenance = MediaMaintenanceService(
      database: database,
      gate: gate,
      supportDirectory: dir,
    );
    profile = SqliteProfileRepository(
      database: database,
      gate: gate,
      clock: clock,
    );
    settings = SqliteSettingsRepository(database: database, gate: gate);
    rebuildBackup();
  }

  void rebuildBackup() => backup = LocalBackupService(
    database: database,
    observations: store,
    profile: profile,
    gate: gate,
    documents: documents,
    appVersion: '1.0.0',
    limits: limits,
    supportDirectory: () async => support,
    clock: clock,
    onStep: (step) => onImportStep?.call(step),
  );

  Future<void> restart() async {
    await database.close();
    open();
  }

  Future<void> dispose() async {
    await backup.dispose();
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  }

  LocalEraseAllService eraser({
    VoiceRecorder? recorder,
    AudioPlayerService? player,
    Future<void> Function()? clearPreferences,
    Future<void> Function(FileSystemEntity entity)? deleteEntity,
  }) => LocalEraseAllService(
    database: database,
    gate: gate,
    supportDirectory: () async => support,
    cacheDirectory: () async => cache,
    recorder: recorder,
    player: player,
    resetStaged: media.resetStaged,
    clearPreferences: clearPreferences,
    deleteEntity: deleteEntity,
  );

  /// Foto de galería distinta cada vez, fuera del espacio privado.
  File galleryPhoto([String? name]) {
    final canvas = image.Image(width: 32, height: 24);
    image.fill(canvas, color: image.ColorRgb8(++_shade * 20 % 256, 80, 120));
    return File('${outside.path}/${name ?? 'gallery_$_shade.png'}')
      ..writeAsBytesSync(image.encodePng(canvas));
  }

  Future<ObservationMedia> stagePhoto() async {
    nextPick = XFile(galleryPhoto().path);
    final picked = await media.pickPhoto(PhotoSource.gallery);
    return ok<ObservationMedia?>(picked)!;
  }

  static Uint8List m4aBytes(int seed) => Uint8List.fromList([
    0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x4d, 0x34, 0x41, 0x20, //
    for (var i = 0; i < 400; i++) (i * 7 + seed) % 256,
  ]);

  Future<ObservationMedia> stageAudio({int seconds = 5}) async {
    final draft = await media.allocateAudioDraft();
    File(draft.partPath).writeAsBytesSync(m4aBytes(++_shade));
    return media.finalizeAudioDraft(draft, Duration(seconds: seconds));
  }

  ObservationInput input({
    String title = 'Leónidas sobre Constanza',
    DateTime? at,
    int offset = -240,
    ObservationCategory category = ObservationCategory.astronomy,
    int? duration,
    ObservationLocation? location,
    List<ObservationMedia> media = const [],
  }) => ObservationInput(
    title: title,
    observedAt: at ?? DateTime.utc(2026, 11, 22, 2),
    utcOffsetMinutes: offset,
    category: category,
    subtypeCode: 'meteor_shower',
    skyCondition: SkyCondition.partlyCloudy,
    description: 'Con acentos: ñ, á y 🌠',
    durationSeconds: duration,
    direction: CardinalDirection.northEast,
    elevationDegrees: 42.5,
    location: location,
    media: media,
  );

  Future<Observation> add(
    ObservationInput value, {
    ObservationStatus status = ObservationStatus.published,
  }) async {
    final created = ok(await store.create(value, status: status));
    ok(await media.commitStaged(value.media.map((m) => m.id)));
    return created;
  }

  /// Publicada con GPS, dos fotos y un audio; un borrador; perfil con foto.
  Future<({Observation full, Observation draft})> seed() async {
    final full = await add(
      input(
        duration: 95,
        location: ObservationLocation(
          placeName: 'Valle Nuevo',
          latitude: 18.8012345,
          longitude: -70.6854321,
          source: LocationSource.gps,
          accuracyM: 6.5,
          capturedAt: DateTime.utc(2026, 11, 22, 1, 59, 30, 250),
        ),
        media: [await stagePhoto(), await stagePhoto(), await stageAudio()],
      ),
    );
    final draft = await add(
      ObservationInput(title: 'Pendiente'),
      status: ObservationStatus.draft,
    );
    final photo = await stagePhoto();
    ok(
      await profile.save(
        ObserverProfile(
          firstName: 'Persona',
          lastName: 'De Prueba',
          studentId: '00-PRUEBA',
          motto: 'Mirar arriba',
          photoMediaId: photo.id,
        ),
        newPhoto: photo,
      ),
    );
    ok(await media.commitStaged([photo.id]));
    return (full: full, draft: draft);
  }

  Uri outsideUri(String name) => File('${outside.path}/$name').absolute.uri;

  File file(String relative) => File('${support.path}/$relative');

  /// Archivos privados (sin la base), con `/`, ordenados.
  List<String> privateFiles() => [
    for (final (directory, label) in [(support, 'support'), (cache, 'cache')])
      for (final entity in directory.listSync(recursive: true))
        if (entity is File)
          '$label/${entity.path.substring(directory.path.length + 1).replaceAll('\\', '/')}',
  ]..sort();

  Future<Map<String, int>> rowCounts() async {
    final db = await database.open();
    return {
      for (final table in const [
        'observations',
        'media_files',
        'observation_media',
        'observer_profile',
        'app_settings',
        'pending_file_deletions',
      ])
        table:
            (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n']!
                as int,
    };
  }

  /// Volcado completo para comparar "no cambió nada".
  Future<String> dump() async {
    final db = await database.open();
    final buffer = StringBuffer();
    for (final table in const [
      'observations',
      'media_files',
      'observation_media',
      'observer_profile',
      'app_settings',
      'pending_file_deletions',
    ]) {
      buffer.writeln(table);
      for (final row in await db.query(table)) {
        buffer.writeln(row);
      }
    }
    return buffer.toString();
  }
}
