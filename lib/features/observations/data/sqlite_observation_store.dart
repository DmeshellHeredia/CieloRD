import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/concurrency/write_gate.dart';
import '../../../core/database/app_database.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../../../core/ids/id_generator.dart';
import '../../../core/text/search_normalizer.dart';
import 'observation_filter_sql.dart';
import '../domain/observation.dart';
import '../domain/observation_filter.dart';
import '../domain/observation_input.dart';
import '../domain/observation_repository.dart';
import '../domain/observation_service.dart';
import '../domain/observation_types.dart';
import '../domain/observation_validator.dart';

/// Implementación C1 sobre SQLite de [ObservationRepository],
/// [ObservationService] y [DraftService].
///
/// * Valida con [ObservationValidator] antes de escribir; el DDL repite las
///   invariantes como segunda barrera.
/// * Concurrencia optimista: `UPDATE ... WHERE id = ? AND revision = ?`.
///   Revisión distinta → `conflict`; ID inexistente → `notFound`.
/// * Búsqueda: cada palabra normalizada debe aparecer en `search_text` (AND).
/// * Paginación por clave (fecha, id): estable aunque se inserten registros
///   entre páginas. Orden compatible con el SQLite antiguo de Android
///   (sin `NULLS LAST`).
/// * Borrar una observación elimina sus enlaces y los medios que ya nadie
///   usa, y encola sus archivos en `pending_file_deletions` (no promete que el
///   disco ya esté limpio).
final class SqliteObservationStore
    implements ObservationRepository, ObservationService, DraftService {
  SqliteObservationStore({
    required this.database,
    this.validator = const ObservationValidator(),
    DateTime Function()? clock,
    String Function()? newId,
    WriteGate? gate,
  }) : _gate = gate ?? WriteGate(),
       _clock = clock ?? DateTime.now,
       _newId = newId ?? IdGenerator.uuidV4;

  final AppDatabase database;
  final ObservationValidator validator;
  final DateTime Function() _clock;
  final String Function() _newId;
  final WriteGate _gate;

  static const String _table = 'observations';
  static const String _order =
      'ORDER BY (observed_at_utc_ms IS NULL) ASC, observed_at_utc_ms DESC, id DESC';

  // ── Lectura ─────────────────────────────────────────────────────────────

  @override
  Future<Result<ObservationPage>> list({
    required ObservationFilter filter,
    String? cursor,
    int limit = 30,
  }) async {
    if (limit < 1 || limit > 100) {
      return Failure(
        AppFailure(
          FailureCode.validation,
          fieldErrors: {'limit': 'out_of_range'},
        ),
      );
    }
    final ObservationFilterSql where = ObservationFilterSql.from(filter);
    final String signature = _signature(filter);
    _Cursor? after;
    if (cursor != null) {
      after = _Cursor.decode(cursor, signature);
      if (after == null) {
        return Failure(
          AppFailure(
            FailureCode.validation,
            fieldErrors: {'cursor': 'invalid'},
          ),
        );
      }
    }
    return _guard(() async {
      final Database db = await database.open();
      final List<String> clauses = [...where.clauses];
      final List<Object?> args = [...where.args];
      if (after != null) {
        if (after.observedAtMs != null) {
          clauses.add(
            '(observed_at_utc_ms IS NULL OR observed_at_utc_ms < ? OR '
            '(observed_at_utc_ms = ? AND id < ?))',
          );
          args.addAll([after.observedAtMs, after.observedAtMs, after.id]);
        } else {
          clauses.add('(observed_at_utc_ms IS NULL AND id < ?)');
          args.add(after.id);
        }
      }
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT * FROM $_table ${ObservationFilterSql.whereSql(clauses)} $_order LIMIT ?',
        [...args, limit + 1],
      );
      final bool hasMore = rows.length > limit;
      final List<Map<String, Object?>> pageRows = hasMore
          ? rows.sublist(0, limit)
          : rows;
      final Map<String, List<ObservationMedia>> media = await _mediaFor(
        db,
        pageRows.map((r) => r['id']! as String).toList(),
      );
      final List<Observation> items = [
        for (final r in pageRows) _toObservation(r, media[r['id']] ?? const []),
      ];
      String? next;
      if (hasMore) {
        final Map<String, Object?> last = pageRows.last;
        next = _Cursor(
          signature,
          last['observed_at_utc_ms'] as int?,
          last['id']! as String,
        ).encode();
      }
      return Success(ObservationPage(items: items, nextCursor: next));
    });
  }

  @override
  Future<Result<int>> count({required ObservationFilter filter}) =>
      _guard(() async {
        final Database db = await database.open();
        final ObservationFilterSql where = ObservationFilterSql.from(filter);
        final List<Map<String, Object?>> rows = await db.rawQuery(
          'SELECT COUNT(*) AS n FROM $_table ${where.sql}',
          where.args,
        );
        return Success(rows.first['n']! as int);
      });

  @override
  Future<Result<Observation>> getById(String id) => _guard(() async {
    final Database db = await database.open();
    final Observation? found = await _read(db, id);
    return found == null
        ? Failure(AppFailure(FailureCode.notFound))
        : Success(found);
  });

  // ── ObservationService ──────────────────────────────────────────────────

  @override
  Future<Result<Observation>> create(
    ObservationInput input, {
    required ObservationStatus status,
  }) => _create(input, status);

  @override
  Future<Result<Observation>> update(
    String id,
    ObservationInput input, {
    required ObservationStatus status,
    required int expectedRevision,
  }) => _update(id, input, status: status, expectedRevision: expectedRevision);

  @override
  Future<Result<Unit>> delete(
    String id, {
    required int expectedRevision,
  }) => _write(() async {
    final Database db = await database.open();
    final AppFailure? failure = await db.transaction((Transaction txn) async {
      final AppFailure? check = await _checkRevision(txn, id, expectedRevision);
      if (check != null) return check;
      final List<String> mediaIds = await _linkedMediaIds(txn, id);
      await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
      await _releaseMedia(txn, mediaIds);
      return null;
    });
    return failure == null ? const Success(Unit.value) : Failure(failure);
  });

  // ── DraftService ────────────────────────────────────────────────────────

  @override
  Future<Result<Observation>> save(
    ObservationInput input, {
    String? id,
    int? expectedRevision,
  }) {
    if ((id == null) != (expectedRevision == null)) {
      return Future.value(
        Failure(
          AppFailure(
            FailureCode.validation,
            fieldErrors: {'id': 'pair_required'},
          ),
        ),
      );
    }
    if (id == null) return _create(input, ObservationStatus.draft);
    return _update(
      id,
      input,
      status: ObservationStatus.draft,
      expectedRevision: expectedRevision!,
      requireDraft: true,
    );
  }

  @override
  Future<Result<Observation>> publish(
    String id, {
    required int expectedRevision,
  }) => _write(() async {
    final Database db = await database.open();
    final Object outcome = await db.transaction((Transaction txn) async {
      final AppFailure? check = await _checkRevision(txn, id, expectedRevision);
      if (check != null) return check;
      final Observation current = (await _read(txn, id))!;
      if (current.status == ObservationStatus.published) {
        return AppFailure(
          FailureCode.conflict,
          fieldErrors: {'status': 'already_published'},
        );
      }
      final Result<ObservationInput> valid = validator.validate(
        current.input,
        status: ObservationStatus.published,
      );
      if (valid is Failure<ObservationInput>) return valid.failure;
      final int changed = await txn.update(
        _table,
        {
          'status': ObservationStatus.published.name,
          'updated_at': _updatedAt(current.createdAt),
          'revision': expectedRevision + 1,
        },
        where: 'id = ? AND revision = ?',
        whereArgs: [id, expectedRevision],
      );
      if (changed != 1) return AppFailure(FailureCode.conflict);
      return (await _read(txn, id))!;
    });
    return outcome is AppFailure
        ? Failure(outcome)
        : Success(outcome as Observation);
  });

  // ── Escritura común ─────────────────────────────────────────────────────

  Future<Result<Observation>> _create(
    ObservationInput input,
    ObservationStatus status,
  ) async {
    final Result<ObservationInput> valid = validator.validate(
      input,
      status: status,
    );
    if (valid is Failure<ObservationInput>) return Failure(valid.failure);
    return _write(() async {
      final Database db = await database.open();
      final int now = _clock().toUtc().millisecondsSinceEpoch;
      final String id = _newId();
      final Observation created = await db.transaction((Transaction txn) async {
        await txn.insert(_table, {
          ...columnsOf(input),
          'id': id,
          'status': status.name,
          'created_at': now,
          'updated_at': now,
          'revision': 1,
        });
        await _replaceMedia(txn, id, input.media, now);
        return (await _read(txn, id))!;
      });
      return Success(created);
    });
  }

  Future<Result<Observation>> _update(
    String id,
    ObservationInput input, {
    required ObservationStatus status,
    required int expectedRevision,
    bool requireDraft = false,
  }) async {
    final Result<ObservationInput> valid = validator.validate(
      input,
      status: status,
    );
    if (valid is Failure<ObservationInput>) return Failure(valid.failure);
    return _write(() async {
      final Database db = await database.open();
      final int now = _clock().toUtc().millisecondsSinceEpoch;
      final Object outcome = await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> rows = await txn.query(
          _table,
          columns: ['revision', 'created_at', 'status'],
          where: 'id = ?',
          whereArgs: [id],
        );
        if (rows.isEmpty) return AppFailure(FailureCode.notFound);
        if (rows.first['revision'] != expectedRevision) {
          return AppFailure(FailureCode.conflict);
        }
        if (requireDraft &&
            rows.first['status'] != ObservationStatus.draft.name) {
          return AppFailure(
            FailureCode.validation,
            fieldErrors: {'status': 'not_a_draft'},
          );
        }
        final int createdAt = rows.first['created_at']! as int;
        final int changed = await txn.update(
          _table,
          {
            ...columnsOf(input),
            'status': status.name,
            'updated_at': now < createdAt ? createdAt : now,
            'revision': expectedRevision + 1,
          },
          where: 'id = ? AND revision = ?',
          whereArgs: [id, expectedRevision],
        );
        if (changed != 1) return AppFailure(FailureCode.conflict);
        await _replaceMedia(txn, id, input.media, now);
        return (await _read(txn, id))!;
      });
      return outcome is AppFailure
          ? Failure(outcome)
          : Success(outcome as Observation);
    });
  }

  int _updatedAt(DateTime createdAt) {
    final int now = _clock().toUtc().millisecondsSinceEpoch;
    final int created = createdAt.millisecondsSinceEpoch;
    return now < created ? created : now;
  }

  Future<AppFailure?> _checkRevision(
    DatabaseExecutor db,
    String id,
    int expectedRevision,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      columns: ['revision'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return AppFailure(FailureCode.notFound);
    if (rows.first['revision'] != expectedRevision) {
      return AppFailure(FailureCode.conflict);
    }
    return null;
  }

  /// Columnas editables de una fila. La importación las reutiliza para no
  /// duplicar la conversión.
  static Map<String, Object?> columnsOf(ObservationInput i) {
    final ObservationLocation? loc = i.location;
    final String? place = _blankToNull(loc?.placeName);
    return {
      'title': i.title.trim(),
      'observed_at_utc_ms': i.observedAt?.millisecondsSinceEpoch,
      'utc_offset_minutes': i.utcOffsetMinutes,
      'category_code': i.category?.name,
      'subtype_code': i.subtypeCode,
      'sky_condition_code': i.skyCondition?.code,
      'description': _blankToNull(i.description),
      'duration_seconds': i.durationSeconds,
      'direction_code': i.direction?.code,
      'elevation_degrees': i.elevationDegrees,
      'place_name': place,
      'place_search': place == null ? null : SearchNormalizer.normalize(place),
      'latitude': loc?.latitude,
      'longitude': loc?.longitude,
      'location_source': loc?.source?.name,
      'accuracy_m': loc?.accuracyM,
      'location_captured_at': loc?.capturedAt?.millisecondsSinceEpoch,
      'search_text': SearchNormalizer.document(
        title: i.title,
        description: i.description,
        place: place,
      ),
    };
  }

  static String? _blankToNull(String? text) {
    final String? t = text?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  // ── Medios ──────────────────────────────────────────────────────────────

  Future<void> _replaceMedia(
    Transaction txn,
    String observationId,
    List<ObservationMedia> media,
    int now,
  ) async {
    final List<String> previous = await _linkedMediaIds(txn, observationId);
    await txn.delete(
      'observation_media',
      where: 'observation_id = ?',
      whereArgs: [observationId],
    );
    for (int i = 0; i < media.length; i++) {
      final ObservationMedia m = media[i];
      await txn.rawInsert(
        'INSERT OR IGNORE INTO media_files '
        '(id, relative_path, mime_type, byte_size, sha256, duration_ms, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          m.id,
          m.relativePath,
          m.mimeType,
          m.byteSize,
          m.sha256,
          m.durationMs,
          now,
        ],
      );
      await txn.insert('observation_media', {
        'observation_id': observationId,
        'media_id': m.id,
        'kind': m.kind.name,
        'sort_order': i,
      });
    }
    final Set<String> kept = media.map((ObservationMedia m) => m.id).toSet();
    await _releaseMedia(
      txn,
      previous.where((String id) => !kept.contains(id)).toList(),
    );
  }

  Future<List<String>> _linkedMediaIds(
    DatabaseExecutor db,
    String observationId,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      'observation_media',
      columns: ['media_id'],
      where: 'observation_id = ?',
      whereArgs: [observationId],
    );
    return rows.map((r) => r['media_id']! as String).toList();
  }

  /// Borra los registros de medios que ya nadie referencia y encola sus
  /// archivos para limpieza durable.
  Future<void> _releaseMedia(Transaction txn, List<String> mediaIds) async {
    final int now = _clock().toUtc().millisecondsSinceEpoch;
    for (final String id in mediaIds) {
      final List<Map<String, Object?>> stillUsed = await txn.rawQuery(
        'SELECT 1 FROM observation_media WHERE media_id = ? '
        'UNION ALL SELECT 1 FROM observer_profile WHERE photo_media_id = ? LIMIT 1',
        [id, id],
      );
      if (stillUsed.isNotEmpty) continue;
      final List<Map<String, Object?>> file = await txn.query(
        'media_files',
        columns: ['relative_path'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (file.isEmpty) continue;
      await txn.delete('media_files', where: 'id = ?', whereArgs: [id]);
      await txn.rawInsert(
        'INSERT OR IGNORE INTO pending_file_deletions (relative_path, created_at, attempts) VALUES (?, ?, 0)',
        [file.first['relative_path'], now],
      );
    }
  }

  Future<Map<String, List<ObservationMedia>>> _mediaFor(
    DatabaseExecutor db,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final String marks = List<String>.filled(ids.length, '?').join(', ');
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT om.observation_id, om.kind, mf.id, mf.relative_path, mf.mime_type, mf.byte_size, '
      'mf.sha256, mf.duration_ms FROM observation_media om '
      'JOIN media_files mf ON mf.id = om.media_id '
      'WHERE om.observation_id IN ($marks) ORDER BY om.observation_id, om.sort_order',
      ids,
    );
    final Map<String, List<ObservationMedia>> byObservation = {};
    for (final Map<String, Object?> r in rows) {
      byObservation
          .putIfAbsent(r['observation_id']! as String, () => [])
          .add(
            ObservationMedia(
              id: r['id']! as String,
              kind: MediaKind.values.byName(r['kind']! as String),
              relativePath: r['relative_path']! as String,
              mimeType: r['mime_type']! as String,
              byteSize: r['byte_size']! as int,
              sha256: r['sha256'] as String?,
              durationMs: r['duration_ms'] as int?,
            ),
          );
    }
    return byObservation;
  }

  Future<Observation?> _read(DatabaseExecutor db, String id) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final Map<String, List<ObservationMedia>> media = await _mediaFor(db, [id]);
    return _toObservation(rows.first, media[id] ?? const []);
  }

  // ── Conversión de filas ─────────────────────────────────────────────────

  static Observation _toObservation(
    Map<String, Object?> r,
    List<ObservationMedia> media,
  ) {
    T? decode<T>(String column, T Function(String code) parse) {
      final String? code = r[column] as String?;
      if (code == null) return null;
      try {
        return parse(code);
      } on Object {
        throw FormatException('Código desconocido en $column: $code');
      }
    }

    DateTime? utc(Object? ms) => ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);
    double? real(Object? v) => (v as num?)?.toDouble();

    final double? lat = real(r['latitude']);
    final String? place = r['place_name'] as String?;
    final LocationSource? source = decode(
      'location_source',
      LocationSource.values.byName,
    );
    final bool hasLocation = place != null || lat != null || source != null;

    return Observation(
      id: r['id']! as String,
      status: ObservationStatus.values.byName(r['status']! as String),
      revision: r['revision']! as int,
      createdAt: utc(r['created_at'])!,
      updatedAt: utc(r['updated_at'])!,
      input: ObservationInput(
        title: r['title'] as String? ?? '',
        observedAt: utc(r['observed_at_utc_ms']),
        utcOffsetMinutes: r['utc_offset_minutes'] as int?,
        category: decode('category_code', ObservationCategory.values.byName),
        subtypeCode: r['subtype_code'] as String?,
        skyCondition: decode(
          'sky_condition_code',
          (c) => SkyCondition.values.firstWhere((s) => s.code == c),
        ),
        description: r['description'] as String?,
        durationSeconds: r['duration_seconds'] as int?,
        direction: decode(
          'direction_code',
          (c) => CardinalDirection.values.firstWhere((d) => d.code == c),
        ),
        elevationDegrees: real(r['elevation_degrees']),
        location: hasLocation
            ? ObservationLocation(
                placeName: place,
                latitude: lat,
                longitude: real(r['longitude']),
                source: source,
                accuracyM: real(r['accuracy_m']),
                capturedAt: utc(r['location_captured_at']),
              )
            : null,
        media: media,
      ),
    );
  }

  // ── Errores ─────────────────────────────────────────────────────────────

  Future<Result<T>> _write<T>(Future<Result<T>> Function() body) =>
      _guard(() => _gate.write(body));

  Future<Result<T>> _guard<T>(Future<Result<T>> Function() body) async {
    try {
      return await body();
    } on WriteGateClosed {
      return Failure(AppFailure(FailureCode.busy));
    } on DatabaseException catch (e) {
      return Failure(mapDatabaseError(e));
    } on FormatException catch (e) {
      return Failure(AppFailure(FailureCode.corruptData, message: e.message));
    } on StateError catch (e) {
      final bool newer = e.message.contains('newer');
      return Failure(
        AppFailure(
          newer ? FailureCode.unsupportedVersion : FailureCode.persistence,
          message: e.message,
        ),
      );
    } on Object catch (e) {
      return Failure(AppFailure(FailureCode.unexpected, message: e.toString()));
    }
  }

  static AppFailure mapDatabaseError(DatabaseException e) {
    final String text = e.toString();
    final int? code = e.getResultCode();
    if (e.isUniqueConstraintError()) {
      return AppFailure(FailureCode.conflict, message: text);
    }
    if (code == 13 ||
        text.contains('SQLITE_FULL') ||
        text.contains('disk is full')) {
      return AppFailure(FailureCode.storageFull, message: text);
    }
    if (code == 19 || text.toLowerCase().contains('constraint')) {
      return AppFailure(FailureCode.validation, message: text);
    }
    if (e.isDatabaseClosedError()) {
      return AppFailure(FailureCode.unavailable, message: text);
    }
    return AppFailure(FailureCode.persistence, message: text);
  }
}

/// Huella estable del filtro (FNV-1a 32 bits): un cursor solo vale para el
/// filtro que lo produjo.
String _signature(ObservationFilter f) {
  final String text = [
    f.query.trim(),
    f.from?.millisecondsSinceEpoch,
    f.until?.millisecondsSinceEpoch,
    f.category?.name,
    f.place.trim(),
    f.status?.name,
  ].join('|');
  int hash = 0x811c9dc5;
  for (final int unit in utf8.encode(text)) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(36);
}

final class _Cursor {
  const _Cursor(this.signature, this.observedAtMs, this.id);
  final String signature;
  final int? observedAtMs;
  final String id;

  String encode() =>
      base64Url.encode(utf8.encode(jsonEncode([signature, observedAtMs, id])));

  static _Cursor? decode(String cursor, String expectedSignature) {
    try {
      final Object? raw = jsonDecode(utf8.decode(base64Url.decode(cursor)));
      if (raw is! List || raw.length != 3) return null;
      final [Object? sig, Object? at, Object? id] = raw;
      if (sig != expectedSignature ||
          id is! String ||
          (at != null && at is! int)) {
        return null;
      }
      return _Cursor(sig as String, at as int?, id);
    } on Object {
      return null;
    }
  }
}
