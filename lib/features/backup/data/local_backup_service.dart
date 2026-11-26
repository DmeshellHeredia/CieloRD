import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/concurrency/write_gate.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_migrations.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../../../core/ids/id_generator.dart';
import '../../observations/data/sqlite_observation_store.dart';
import '../../observations/domain/observation.dart';
import '../../observations/domain/observation_filter.dart';
import '../../observations/domain/observation_repository.dart';
import '../../observations/domain/observation_types.dart';
import '../../profile/domain/profile_repository.dart';
import '../domain/backup_service.dart';
import 'backup_codec.dart';
import 'platform_documents.dart';
import 'strict_zip.dart';

/// Copias de CieloRD: exportación JSON y ZIP, inspección e importación.
///
/// Estrategia de importación y formato:
/// `docs/superpowers/specs/2026-11-23-hito-c-design.md`.
final class LocalBackupService implements BackupService {
  LocalBackupService({
    required this.database,
    required this.observations,
    required this.profile,
    required this.gate,
    required this.documents,
    required this.appVersion,
    this.limits = const BackupLimits(),
    Future<Directory> Function()? supportDirectory,
    DateTime Function()? clock,
    this.onStep,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _clock = clock ?? DateTime.now;

  final AppDatabase database;
  final ObservationRepository observations;
  final ProfileRepository profile;
  final WriteGate gate;
  final DocumentStore documents;
  final String appVersion;
  final BackupLimits limits;
  final Future<Directory> Function() _supportDirectory;
  final DateTime Function() _clock;

  /// Solo pruebas: permite simular un fallo en un punto de la importación.
  final FutureOr<void> Function(String step)? onStep;

  final _progress = StreamController<BackupProgress>.broadcast();
  _Inspection? _inspection;

  @override
  Stream<BackupProgress> get progress => _progress.stream;

  // ── Exportación ─────────────────────────────────────────────────────────

  @override
  Future<Result<BackupReceipt>> export({
    required ObservationFilter filter,
    required BackupFormat format,
    required Uri destination,
    bool includeProfile = false,
  }) async {
    final operation = IdGenerator.uuidV4();
    Directory? work;
    var writing = false;
    final result = await _guard<BackupReceipt>(() async {
      work = await _workDirectory('export-$operation');
      final file = File(p.join(work!.path, 'out'));
      // En exclusiva: nada cambia entre leer los registros y sus archivos.
      final built = await gate.exclusive(
        () => _build(operation, file, filter, format, includeProfile),
      );
      if (format == BackupFormat.zipComplete) {
        _report(operation, 'verify');
        await _validate(file);
      }
      _report(operation, 'write');
      writing = true;
      await documents.write(file, destination);
      return BackupReceipt(
        destination: destination,
        observationCount: built.data.observations.length,
        includesMedia: format == BackupFormat.zipComplete,
        mediaCount: built.data.media.length,
        missingMedia: built.missing.length,
        byteSize: await file.length(),
      );
    });
    if (result is Failure<BackupReceipt>) {
      // No dejar un documento vacío o a medias que parezca una copia válida.
      // Si aún no se escribió nada, un archivo con contenido es de la persona
      // (eligió sobrescribirlo) y no se toca.
      try {
        await documents.discard(destination, onlyIfEmpty: !writing);
      } on Object {
        // El proveedor puede no admitir borrado; el fallo ya se informa.
      }
    }
    await _remove(work);
    return result;
  }

  Future<({BackupData data, List<({String id, MediaKind kind})> missing})>
  _build(
    String operation,
    File file,
    ObservationFilter filter,
    BackupFormat format,
    bool includeProfile,
  ) async {
    final createdAt = _clock().toUtc();
    final items = <Observation>[];
    String? cursor;
    do {
      final page = _unwrap(
        await observations.list(filter: filter, cursor: cursor, limit: 100),
      );
      items.addAll(page.items);
      cursor = page.nextCursor;
      _report(operation, 'read', items.length);
    } while (cursor != null);
    final owner = includeProfile ? _unwrap(await profile.get()) : null;

    final db = await database.open();
    final wanted = <ObservationMedia>[
      for (final o in items) ...o.input.media,
      if (owner?.photoMediaId != null)
        ...await _mediaRows(db, [owner!.photoMediaId!]),
    ];
    final root = await _supportDirectory();
    final included = <String, BackupMedia>{};
    final missing = <({String id, MediaKind kind})>[];
    final zip = format == BackupFormat.zipComplete
        ? await StreamingZipWriter.create(file, createdAt)
        : null;
    try {
      var total = 0;
      for (final (index, media) in wanted.indexed) {
        _report(operation, 'media', index, wanted.length);
        final source = File(p.join(root.path, p.fromUri(media.relativePath)));
        final written = await _addMedia(zip, media, source);
        if (written == null) {
          missing.add((id: media.id, kind: media.kind));
          continue;
        }
        included[media.id] = written;
        total += written.byteSize;
        if (total > limits.totalBytes || included.length > limits.entries - 2) {
          throw const BackupInvalid(BackupErrors.tooLarge, 'media');
        }
      }
      final data = BackupData(
        observations: [
          for (final o in items)
            _withMedia(o, [
              for (final m in o.input.media)
                if (included.containsKey(m.id)) m,
            ]),
        ]..sort((a, b) => a.id.compareTo(b.id)),
        media: included,
        profile: owner == null
            ? null
            : ObserverProfile(
                firstName: owner.firstName,
                lastName: owner.lastName,
                studentId: owner.studentId,
                motto: owner.motto,
                photoMediaId: included.containsKey(owner.photoMediaId)
                    ? owner.photoMediaId
                    : null,
              ),
      );
      if (zip == null) {
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            BackupCodec.jsonExport(
              data: data,
              createdAt: createdAt,
              appVersion: appVersion,
              databaseVersion: DatabaseMigrations.currentVersion,
            ),
          ),
          flush: true,
        );
        return (data: data, missing: missing);
      }
      final dataBytes = utf8.encode(jsonEncode(BackupCodec.dataToJson(data)));
      if (dataBytes.length > limits.dataBytes) {
        throw const BackupInvalid(BackupErrors.tooLarge, 'data');
      }
      await zip.addBytes(BackupCodec.dataName, dataBytes);
      await zip.addBytes(
        BackupCodec.manifestName,
        utf8.encode(
          const JsonEncoder.withIndent('  ').convert(
            BackupCodec.manifestToJson(
              data: data,
              createdAt: createdAt,
              appVersion: appVersion,
              databaseVersion: DatabaseMigrations.currentVersion,
              dataSize: dataBytes.length,
              dataSha256: sha256.convert(dataBytes).toString(),
              missing: missing,
            ),
          ),
        ),
      );
      await zip.finish();
      return (data: data, missing: missing);
    } on Object {
      await zip?.abort().catchError((Object _) {});
      rethrow;
    }
  }

  /// `null` si el archivo falta, está vacío, no cabe o no es del tipo dicho.
  Future<BackupMedia?> _addMedia(
    StreamingZipWriter? zip,
    ObservationMedia media,
    File source,
  ) async {
    if (!BackupCodec.isSafeId(media.id) ||
        (media.kind == MediaKind.audio && media.durationMs == null)) {
      return null;
    }
    final start = await zip?.position();
    try {
      final size = await source.length();
      if (size == 0 || size > limits.mediaBytes) return null;
      final head = await source.openRead(0, 16).expand((b) => b).toList();
      if (!BackupCodec.hasSignature(media.kind, head)) return null;
      final name = BackupCodec.mediaPath(media.kind, media.id);
      final written = zip == null
          ? (
              size: size,
              sha256: (await sha256.bind(source.openRead()).first).toString(),
            )
          : await zip.addFile(name, source);
      return BackupMedia(
        id: media.id,
        kind: media.kind,
        byteSize: written.size,
        sha256: written.sha256,
        durationMs: media.durationMs,
      );
    } on PathNotFoundException {
      if (start != null) await zip!.rewind(start);
      return null;
    }
  }

  static Observation _withMedia(Observation o, List<ObservationMedia> media) =>
      media.length == o.input.media.length
      ? o
      : Observation(
          id: o.id,
          status: o.status,
          input: o.input.copyWith(media: media),
          createdAt: o.createdAt,
          updatedAt: o.updatedAt,
          revision: o.revision,
        );

  // ── Inspección ──────────────────────────────────────────────────────────

  @override
  Future<Result<BackupInspection>> inspect(Uri source) async {
    final token = IdGenerator.uuidV4();
    final previous = _inspection;
    _inspection = null;
    await _remove(previous?.directory);
    Directory? work;
    final result = await _guard<BackupInspection>(() async {
      work = await _workDirectory('import-$token');
      final file = File(p.join(work!.path, 'backup.zip'));
      _report(token, 'copy');
      await documents.read(source, file, maxBytes: limits.totalBytes);
      final valid = await _validate(file);
      final plan = await _plan(await database.open(), valid.data);
      final media = valid.data.media.values;
      _inspection = _Inspection(
        token: token,
        directory: work!,
        file: file,
        sha256: await _fileHash(file),
        data: valid.data,
      );
      return BackupInspection(
        token: token,
        formatVersion: valid.manifest.schemaVersion,
        appVersion: valid.manifest.appVersion,
        createdAt: valid.manifest.createdAt,
        observationCount: valid.data.observations.length,
        draftCount: valid.manifest.draftCount,
        mediaCount: media.length,
        photoCount: media.where((m) => m.kind == MediaKind.photo).length,
        audioCount: media.where((m) => m.kind == MediaKind.audio).length,
        uncompressedBytes: valid.uncompressedBytes,
        newCount: plan.observations.where((o) => !o.isCopy).length,
        copyCount: plan.observations.where((o) => o.isCopy).length,
        identicalCount: plan.identical,
        hasProfile: !(valid.data.profile?.isEmpty ?? true),
        willImportProfile: plan.importProfile,
        warnings: [
          if (valid.manifest.missingMedia > 0)
            'missing_media:${valid.manifest.missingMedia}',
        ],
      );
    });
    if (result is Failure<BackupInspection>) await _remove(work);
    return result;
  }

  @override
  Future<void> discardInspection(String inspectionToken) async {
    final current = _inspection;
    if (current?.token != inspectionToken) return;
    _inspection = null;
    await _remove(current!.directory);
  }

  /// Comprueba el archivo entero: estructura, rutas, tamaños, hashes y tipos.
  Future<({BackupManifest manifest, BackupData data, int uncompressedBytes})>
  _validate(File file) async {
    final zip = await StrictZipReader.open(
      file,
      maxEntries: limits.entries,
      maxTotalBytes: limits.totalBytes,
    );
    // Rutas y conjunto exacto de archivos, antes de leer ningún contenido.
    for (final name in zip.entries.keys) {
      if (name != BackupCodec.manifestName &&
          name != BackupCodec.dataName &&
          !_mediaName.hasMatch(name)) {
        throw ZipRejected(BackupErrors.unexpectedEntry, name);
      }
    }
    if (!zip.entries.containsKey(BackupCodec.manifestName) ||
        !zip.entries.containsKey(BackupCodec.dataName)) {
      throw const BackupInvalid(BackupErrors.structure, 'missing json');
    }
    final (manifestBytes, _) = await zip.readAll(
      BackupCodec.manifestName,
      maxBytes: limits.manifestBytes,
      staging: file.parent,
    );
    final manifest = BackupCodec.readManifest(
      BackupCodec.decodeJson(manifestBytes),
    );
    final expected = {for (final m in manifest.media.values) m.path: m};
    for (final name in zip.entries.keys) {
      if (_mediaName.hasMatch(name) && !expected.containsKey(name)) {
        throw ZipRejected(BackupErrors.unexpectedEntry, name);
      }
    }
    for (final MapEntry(key: name, value: media) in expected.entries) {
      final entry = zip.entries[name];
      if (entry == null) throw BackupInvalid(BackupErrors.structure, name);
      if (entry.size > limits.mediaBytes) {
        throw BackupInvalid(BackupErrors.tooLarge, name);
      }
      if (entry.size != media.byteSize) {
        throw BackupInvalid(BackupErrors.size, name);
      }
    }
    if (zip.entries[BackupCodec.dataName]!.size != manifest.dataSize) {
      throw const BackupInvalid(BackupErrors.size, BackupCodec.dataName);
    }
    final (dataBytes, dataDigest) = await zip.readAll(
      BackupCodec.dataName,
      maxBytes: limits.dataBytes,
      staging: file.parent,
    );
    if (dataDigest.sha256 != manifest.dataSha256) {
      throw const BackupInvalid(BackupErrors.hash, BackupCodec.dataName);
    }
    final data = BackupCodec.readData(
      BackupCodec.decodeJson(dataBytes),
      manifest,
    );
    for (final MapEntry(key: name, value: media) in expected.entries) {
      _checkMedia(name, media, await zip.verify(name));
    }
    return (
      manifest: manifest,
      data: data,
      uncompressedBytes: zip.entries.values.fold(0, (sum, e) => sum + e.size),
    );
  }

  static final RegExp _mediaName = RegExp(
    r'^media/(photos/[A-Za-z0-9_-]{1,128}\.jpg|audio/[A-Za-z0-9_-]{1,128}\.m4a)$',
  );

  static void _checkMedia(String name, BackupMedia media, ZipDigest digest) {
    if (digest.sha256 != media.sha256) {
      throw BackupInvalid(BackupErrors.hash, name);
    }
    if (!BackupCodec.hasSignature(media.kind, digest.head)) {
      throw BackupInvalid(BackupErrors.type, name);
    }
  }

  // ── Importación ─────────────────────────────────────────────────────────

  @override
  Future<Result<ImportReport>> importZip(
    String inspectionToken, {
    ImportConflictPolicy policy = ImportConflictPolicy.importAsCopies,
  }) async {
    final inspection = _inspection;
    if (inspection == null || inspection.token != inspectionToken) {
      return Failure(
        AppFailure(
          FailureCode.validation,
          fieldErrors: {'backup': BackupErrors.expired},
        ),
      );
    }
    final result = await _guard<ImportReport>(
      () => gate.exclusive(() => _import(inspection)),
    );
    if (result is Success<ImportReport>) {
      await discardInspection(inspectionToken);
    }
    return result;
  }

  Future<ImportReport> _import(_Inspection inspection) async {
    // Los bytes que se van a importar son exactamente los inspeccionados.
    if (await _fileHash(inspection.file) != inspection.sha256) {
      throw const BackupInvalid(BackupErrors.hash, 'staged copy');
    }
    final db = await database.open();
    final plan = await _plan(db, inspection.data);
    final root = await _supportDirectory();
    final extracted = Directory(p.join(inspection.directory.path, 'files'));
    await _remove(extracted);
    await extracted.create(recursive: true);
    final moved = <File>[];
    try {
      final files = await _extract(inspection, plan, extracted);
      await onStep?.call('extracted');
      for (final MapEntry(key: relative, value: staged) in files.entries) {
        final target = File(p.join(root.path, p.fromUri(relative)));
        await target.parent.create(recursive: true);
        // Nadie referencia este destino (el plan usa IDs libres): si existe,
        // es un huérfano a la espera de limpieza.
        if (await target.exists()) await target.delete();
        moved.add(target);
        await staged.rename(target.path);
      }
      await onStep?.call('moved');
      await db.transaction((txn) async {
        await _insert(txn, inspection.data, plan);
        await onStep?.call('inserted');
      });
    } on Object {
      for (final file in moved) {
        try {
          if (await file.exists()) await file.delete();
        } on Object {
          // Huérfano: lo elimina la reconciliación del próximo arranque.
        }
      }
      rethrow;
    } finally {
      await _remove(extracted);
    }
    return ImportReport(
      importedObservations: plan.observations.length,
      importedMedia: plan.mediaCount,
      importedAsCopies: plan.observations.where((o) => o.isCopy).length,
      skippedIdentical: plan.identical,
      profileImported: plan.importProfile,
    );
  }

  /// Extrae y comprueba los adjuntos planificados y genera sus miniaturas.
  /// Devuelve ruta relativa definitiva → archivo temporal.
  Future<Map<String, File>> _extract(
    _Inspection inspection,
    _ImportPlan plan,
    Directory target,
  ) async {
    final zip = await StrictZipReader.open(
      inspection.file,
      maxEntries: limits.entries,
      maxTotalBytes: limits.totalBytes,
    );
    final files = <String, File>{};
    final total = plan.mediaCount;
    for (final (index, item) in plan.media.indexed) {
      _report(inspection.token, 'extract', index, total);
      final source = inspection.data.media[item.sourceId]!;
      final file = File(p.join(target.path, '$index'));
      _checkMedia(
        source.path,
        source,
        await zip.verify(source.path, output: file),
      );
      files[BackupCodec.mediaPath(source.kind, item.targetId)] = file;
      if (source.kind == MediaKind.photo) {
        final thumbnail = await _thumbnail(file, limits.photoPixels);
        if (thumbnail == null) {
          throw BackupInvalid(BackupErrors.type, source.path);
        }
        final thumbnailFile = File(p.join(target.path, '$index.thumb'));
        await thumbnailFile.writeAsBytes(thumbnail, flush: true);
        files['media/thumbnails/${item.targetId}.jpg'] = thumbnailFile;
      }
    }
    return files;
  }

  /// Decodifica en otro isolate; `null` si no es un JPEG válido o es excesivo.
  static Future<Uint8List?> _thumbnail(File file, int maxPixels) async {
    final path = file.path;
    return Isolate.run(() {
      try {
        final bytes = File(path).readAsBytesSync();
        final info = image.JpegDecoder().startDecode(bytes);
        if (info == null || info.width * info.height > maxPixels) return null;
        final decoded = image.decodeJpg(bytes);
        if (decoded == null) return null;
        return image.encodeJpg(
          image.copyResize(
            decoded,
            width: decoded.width > 480 ? 480 : decoded.width,
            interpolation: image.Interpolation.average,
          ),
          quality: 82,
        );
      } on Object {
        return null;
      }
    });
  }

  Future<_ImportPlan> _plan(DatabaseExecutor db, BackupData data) async {
    Future<Set<String>> existing(String table, List<String> ids) async {
      final found = <String>{};
      for (var i = 0; i < ids.length; i += 400) {
        final chunk = ids.sublist(
          i,
          i + 400 > ids.length ? ids.length : i + 400,
        );
        final marks = List.filled(chunk.length, '?').join(',');
        final rows = await db.rawQuery(
          'SELECT id FROM $table WHERE id IN ($marks)',
          chunk,
        );
        found.addAll(rows.map((r) => r['id']! as String));
      }
      return found;
    }

    final present = await existing('observations', [
      for (final o in data.observations) o.id,
    ]);
    final planned = <_PlannedObservation>[];
    final candidates = <_PlannedObservation>[];
    var identical = 0;
    for (final o in data.observations) {
      final print = BackupCodec.fingerprint(o, (m) => data.media[m.id]!.sha256);
      if (!present.contains(o.id)) {
        planned.add(_PlannedObservation(o, o.id, isCopy: false));
      } else if (await _localFingerprint(o.id) == print) {
        identical++;
      } else {
        candidates.add(
          _PlannedObservation(o, BackupCodec.copyId(o.id, print), isCopy: true),
        );
      }
    }
    final taken = await existing('observations', [
      for (final c in candidates) c.targetId,
    ]);
    // Un ID de copia puede coincidir con un ID original de la misma copia de
    // seguridad (se exportó después de una importación en conflicto).
    taken.addAll(planned.map((o) => o.targetId));
    for (final candidate in candidates) {
      if (taken.add(candidate.targetId)) {
        planned.add(candidate);
      } else {
        identical++;
      }
    }

    final usedMedia = await existing('media_files', data.media.keys.toList());
    final media = <_PlannedMedia>[];
    final reserved = {...usedMedia, ...data.media.keys};
    String assign(String sourceId, String owner) {
      if (!usedMedia.contains(sourceId)) return sourceId;
      final derived = BackupCodec.copyMediaId(owner, sourceId);
      if (!reserved.add(derived)) {
        throw BackupInvalid(BackupErrors.structure, 'media id: $derived');
      }
      return derived;
    }

    for (final o in planned) {
      for (final m in o.source.input.media) {
        final target = assign(m.id, o.targetId);
        o.mediaIds[m.id] = target;
        media.add(_PlannedMedia(m.id, target));
      }
    }
    final imported = data.profile;
    final local = _unwrap(await profile.get());
    final importProfile =
        imported != null && !imported.isEmpty && (local?.isEmpty ?? true);
    String? photo;
    if (importProfile && imported.photoMediaId != null) {
      photo = assign(imported.photoMediaId!, 'profile');
      media.add(_PlannedMedia(imported.photoMediaId!, photo));
    }
    return _ImportPlan(
      observations: planned,
      media: media,
      identical: identical,
      importProfile: importProfile,
      profilePhotoId: photo,
    );
  }

  Future<String?> _localFingerprint(String id) async {
    final local = _unwrap(await observations.getById(id));
    final hashes = <String, String>{};
    final root = await _supportDirectory();
    for (final m in local.input.media) {
      hashes[m.id] =
          m.sha256 ??
          await _fileHash(File(p.join(root.path, p.fromUri(m.relativePath))));
    }
    return BackupCodec.fingerprint(local, (m) => hashes[m.id]!);
  }

  Future<void> _insert(
    Transaction txn,
    BackupData data,
    _ImportPlan plan,
  ) async {
    final now = _clock().toUtc().millisecondsSinceEpoch;
    Future<void> insertMedia(String sourceId, String targetId) async {
      final media = data.media[sourceId]!.toMedia(targetId);
      await txn.insert('media_files', {
        'id': media.id,
        'relative_path': media.relativePath,
        'mime_type': media.mimeType,
        'byte_size': media.byteSize,
        'sha256': media.sha256,
        'duration_ms': media.durationMs,
        'created_at': now,
      });
      // La cola de borrado no debe eliminar un archivo recién recuperado.
      await txn.delete(
        'pending_file_deletions',
        where: 'relative_path = ?',
        whereArgs: [media.relativePath],
      );
    }

    for (final planned in plan.observations) {
      final o = planned.source;
      await txn.insert('observations', {
        ...SqliteObservationStore.columnsOf(o.input),
        'id': planned.targetId,
        'status': o.status.name,
        'created_at': o.createdAt.millisecondsSinceEpoch,
        'updated_at': o.updatedAt.millisecondsSinceEpoch,
        'revision': o.revision,
      });
      for (final (index, m) in o.input.media.indexed) {
        final target = planned.mediaIds[m.id]!;
        await insertMedia(m.id, target);
        await txn.insert('observation_media', {
          'observation_id': planned.targetId,
          'media_id': target,
          'kind': m.kind.name,
          'sort_order': index,
        });
      }
    }
    if (plan.importProfile) {
      final imported = data.profile!;
      if (plan.profilePhotoId != null) {
        await insertMedia(imported.photoMediaId!, plan.profilePhotoId!);
      }
      await txn.insert('observer_profile', {
        'id': 1,
        'first_name': imported.firstName,
        'last_name': imported.lastName,
        'student_id': imported.studentId,
        'motto': imported.motto,
        'photo_media_id': plan.profilePhotoId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ── Utilidades ──────────────────────────────────────────────────────────

  Future<List<ObservationMedia>> _mediaRows(
    DatabaseExecutor db,
    List<String> ids,
  ) async {
    final rows = await db.query(
      'media_files',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    return [
      for (final r in rows)
        ObservationMedia(
          id: r['id']! as String,
          kind: (r['mime_type']! as String).startsWith('image/')
              ? MediaKind.photo
              : MediaKind.audio,
          relativePath: r['relative_path']! as String,
          mimeType: r['mime_type']! as String,
          byteSize: r['byte_size']! as int,
          sha256: r['sha256'] as String?,
          durationMs: r['duration_ms'] as int?,
        ),
    ];
  }

  Future<Directory> _workDirectory(String name) async {
    final root = await _supportDirectory();
    final directory = Directory(p.join(root.path, 'staging', name));
    await directory.create(recursive: true);
    return directory;
  }

  /// Elimina restos de exportaciones o inspecciones de otra sesión.
  Future<void> purgeStaging() async {
    _inspection = null;
    final root = await _supportDirectory();
    await _remove(Directory(p.join(root.path, 'staging')));
  }

  static Future<void> _remove(Directory? directory) async {
    try {
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on Object {
      // Se reintenta al arrancar (purgeStaging) y en Borrar Todo.
    }
  }

  static Future<String> _fileHash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  void _report(String id, String phase, [int completed = 0, int? total]) {
    if (_progress.isClosed) return;
    _progress.add(
      BackupProgress(
        operationId: id,
        phase: phase,
        completed: completed,
        total: total,
      ),
    );
  }

  static T _unwrap<T>(Result<T> result) => switch (result) {
    Success<T>(:final value) => value,
    Failure<T>(:final failure) => throw _Failed(failure),
  };

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    AppFailure rejected(String reason, String detail) => AppFailure(
      reason == BackupErrors.version
          ? FailureCode.unsupportedVersion
          : FailureCode.corruptData,
      message: detail,
      fieldErrors: {'backup': reason},
    );
    try {
      return Success(await body());
    } on WriteGateClosed {
      return Failure(AppFailure(FailureCode.busy));
    } on _Failed catch (e) {
      return Failure(e.failure);
    } on ZipRejected catch (e) {
      return Failure(rejected(e.reason, e.detail));
    } on BackupInvalid catch (e) {
      return Failure(rejected(e.reason, e.detail));
    } on DocumentTooLarge {
      return Failure(rejected(BackupErrors.tooLarge, 'document'));
    } on DatabaseException catch (e) {
      return Failure(SqliteObservationStore.mapDatabaseError(e));
    } on FileSystemException catch (e) {
      final text = e.toString();
      final full = text.contains('No space left') || text.contains('disk full');
      return Failure(
        AppFailure(
          full ? FailureCode.storageFull : FailureCode.io,
          message: text,
        ),
      );
    } on Object catch (e) {
      return Failure(AppFailure(FailureCode.io, message: e.toString()));
    }
  }

  Future<void> dispose() => _progress.close();
}

final class _Failed implements Exception {
  const _Failed(this.failure);
  final AppFailure failure;
}

final class _Inspection {
  const _Inspection({
    required this.token,
    required this.directory,
    required this.file,
    required this.sha256,
    required this.data,
  });
  final String token;
  final Directory directory;
  final File file;
  final String sha256;
  final BackupData data;
}

final class _PlannedObservation {
  _PlannedObservation(this.source, this.targetId, {required this.isCopy});
  final Observation source;
  final String targetId;
  final bool isCopy;

  /// ID en la copia → ID definitivo.
  final Map<String, String> mediaIds = {};
}

final class _PlannedMedia {
  const _PlannedMedia(this.sourceId, this.targetId);
  final String sourceId;
  final String targetId;
}

final class _ImportPlan {
  const _ImportPlan({
    required this.observations,
    required this.media,
    required this.identical,
    required this.importProfile,
    required this.profilePhotoId,
  });
  final List<_PlannedObservation> observations;
  final List<_PlannedMedia> media;
  final int identical;
  final bool importProfile;
  final String? profilePhotoId;

  int get mediaCount => media.length;
}
