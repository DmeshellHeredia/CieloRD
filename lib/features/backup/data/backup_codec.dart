import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/domain/result.dart';
import '../../observations/domain/observation.dart';
import '../../observations/domain/observation_input.dart';
import '../../observations/domain/observation_types.dart';
import '../../observations/domain/observation_validator.dart';
import '../../profile/data/sqlite_profile_repository.dart';
import '../../profile/domain/profile_repository.dart';

/// Contenido de copia inválido. [reason] es un código de `BackupErrors`.
final class BackupInvalid implements Exception {
  const BackupInvalid(this.reason, [this.detail = '']);
  final String reason;
  final String detail;

  @override
  String toString() => 'BackupInvalid($reason: $detail)';
}

/// Límites comunes a exportación e importación.
final class BackupLimits {
  const BackupLimits({
    this.totalBytes = 2 * 1024 * 1024 * 1024,
    this.mediaBytes = 128 * 1024 * 1024,
    this.dataBytes = 32 * 1024 * 1024,
    this.manifestBytes = 16 * 1024 * 1024,
    this.entries = 20000,
    this.photoPixels = 64 * 1000 * 1000,
  });
  final int totalBytes;
  final int mediaBytes;
  final int dataBytes;
  final int manifestBytes;
  final int entries;
  final int photoPixels;
}

/// Adjunto tal como figura en la copia.
final class BackupMedia {
  const BackupMedia({
    required this.id,
    required this.kind,
    required this.byteSize,
    required this.sha256,
    this.durationMs,
  });
  final String id;
  final MediaKind kind;
  final int byteSize;
  final String sha256;
  final int? durationMs;

  String get path => BackupCodec.mediaPath(kind, id);
  String get mimeType => BackupCodec.mimeType(kind);

  ObservationMedia toMedia(String targetId) => ObservationMedia(
    id: targetId,
    kind: kind,
    relativePath: BackupCodec.mediaPath(kind, targetId),
    mimeType: mimeType,
    byteSize: byteSize,
    sha256: sha256,
    durationMs: durationMs,
  );
}

final class BackupData {
  const BackupData({
    required this.observations,
    required this.media,
    this.profile,
  });

  /// Ordenadas por ID; sus adjuntos conservan los IDs de la copia.
  final List<Observation> observations;
  final Map<String, BackupMedia> media;
  final ObserverProfile? profile;
}

final class BackupManifest {
  const BackupManifest({
    required this.schemaVersion,
    required this.createdAt,
    required this.appVersion,
    required this.dataSize,
    required this.dataSha256,
    required this.media,
    required this.missingMedia,
    required this.observationCount,
    required this.draftCount,
  });
  final int schemaVersion;
  final DateTime createdAt;
  final String appVersion;
  final int dataSize;
  final String dataSha256;
  final Map<String, BackupMedia> media;
  final int missingMedia;
  final int observationCount;
  final int draftCount;
}

/// Serialización v1 de las copias. Estricta al leer: claves exactas, tipos
/// exactos, valores validados con las mismas reglas que el formulario.
abstract final class BackupCodec {
  static const String format = 'cielord-backup';
  static const String jsonFormat = 'cielord-export';
  static const int schemaVersion = 1;
  static const String manifestName = 'manifest.json';
  static const String dataName = 'data.json';

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _sha = RegExp(r'^[a-f0-9]{64}$');
  static final RegExp _utc = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$',
  );

  static String mediaPath(MediaKind kind, String id) => switch (kind) {
    MediaKind.photo => 'media/photos/$id.jpg',
    MediaKind.audio => 'media/audio/$id.m4a',
  };

  static String mimeType(MediaKind kind) => switch (kind) {
    MediaKind.photo => 'image/jpeg',
    MediaKind.audio => 'audio/mp4',
  };

  static bool isSafeId(String id) => _id.hasMatch(id);

  /// JPEG (FF D8 FF) o contenedor MP4 (`ftyp`).
  static bool hasSignature(MediaKind kind, List<int> head) => switch (kind) {
    MediaKind.photo =>
      head.length >= 3 && head[0] == 0xff && head[1] == 0xd8 && head[2] == 0xff,
    MediaKind.audio =>
      head.length >= 8 &&
          head[4] == 0x66 &&
          head[5] == 0x74 &&
          head[6] == 0x79 &&
          head[7] == 0x70,
  };

  // ── Escritura ───────────────────────────────────────────────────────────

  static Map<String, Object?> dataToJson(BackupData data) => {
    'schemaVersion': schemaVersion,
    'observations': [for (final o in data.observations) _observationToJson(o)],
    'media': [for (final m in _sorted(data.media)) _mediaToJson(m)],
    'profile': data.profile == null ? null : _profileToJson(data.profile!),
  };

  static Map<String, Object?> manifestToJson({
    required BackupData data,
    required DateTime createdAt,
    required String appVersion,
    required int databaseVersion,
    required int dataSize,
    required String dataSha256,
    required List<({String id, MediaKind kind})> missing,
  }) => {
    'format': format,
    'schemaVersion': schemaVersion,
    'createdAt': _date(createdAt),
    'appVersion': appVersion,
    'databaseVersion': databaseVersion,
    'counts': counts(data),
    'data': {'path': dataName, 'byteSize': dataSize, 'sha256': dataSha256},
    'files': [for (final m in _sorted(data.media)) _mediaToJson(m)],
    'missingMedia': [
      for (final m in missing) {'id': m.id, 'kind': m.kind.name},
    ],
  };

  /// Exportación de solo metadatos: los adjuntos se describen, no se incluyen.
  static Map<String, Object?> jsonExport({
    required BackupData data,
    required DateTime createdAt,
    required String appVersion,
    required int databaseVersion,
  }) => {
    'format': jsonFormat,
    'createdAt': _date(createdAt),
    'appVersion': appVersion,
    'databaseVersion': databaseVersion,
    'includesMediaFiles': false,
    'counts': counts(data),
    ...dataToJson(data),
  };

  static Map<String, Object?> counts(BackupData data) => {
    'observations': data.observations.length,
    'drafts': data.observations
        .where((o) => o.status == ObservationStatus.draft)
        .length,
    'photos': data.media.values.where((m) => m.kind == MediaKind.photo).length,
    'audios': data.media.values.where((m) => m.kind == MediaKind.audio).length,
    'profile': data.profile != null,
  };

  static List<BackupMedia> _sorted(Map<String, BackupMedia> media) =>
      media.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  static String _date(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
    value.millisecondsSinceEpoch,
    isUtc: true,
  ).toIso8601String();

  static Map<String, Object?> _mediaToJson(BackupMedia m) => {
    'id': m.id,
    'kind': m.kind.name,
    'path': m.path,
    'mimeType': m.mimeType,
    'byteSize': m.byteSize,
    'sha256': m.sha256,
    'durationMs': m.durationMs,
  };

  static Map<String, Object?> _profileToJson(ObserverProfile p) => {
    'firstName': p.firstName,
    'lastName': p.lastName,
    'studentId': p.studentId,
    'motto': p.motto,
    'photoMediaId': p.photoMediaId,
  };

  static Map<String, Object?> _observationToJson(Observation o) => {
    'id': o.id,
    'status': o.status.name,
    ..._inputToJson(o.input),
    'media': [for (final m in o.input.media) m.id],
    'createdAt': _date(o.createdAt),
    'updatedAt': _date(o.updatedAt),
    'revision': o.revision,
  };

  static Map<String, Object?> _inputToJson(ObservationInput i) => {
    'title': i.title,
    'observedAt': i.observedAt == null ? null : _date(i.observedAt!),
    'utcOffsetMinutes': i.utcOffsetMinutes,
    'category': i.category?.name,
    'subtype': i.subtypeCode,
    'sky': i.skyCondition?.code,
    'description': i.description,
    'durationSeconds': i.durationSeconds,
    'direction': i.direction?.code,
    'elevationDegrees': i.elevationDegrees,
    'location': i.location == null
        ? null
        : {
            'placeName': i.location!.placeName,
            'latitude': i.location!.latitude,
            'longitude': i.location!.longitude,
            'source': i.location!.source?.name,
            'accuracyM': i.location!.accuracyM,
            'capturedAt': i.location!.capturedAt == null
                ? null
                : _date(i.location!.capturedAt!),
          },
  };

  /// Huella del contenido visible. No incluye IDs de adjuntos, fechas de
  /// gestión ni revisión: dos registros con la misma huella son el mismo.
  static String fingerprint(
    Observation o,
    String Function(ObservationMedia media) mediaHash,
  ) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            o.status.name,
            _inputToJson(o.input),
            [
              for (final m in o.input.media)
                [m.kind.name, m.durationMs, mediaHash(m)],
            ],
          ]),
        ),
      )
      .toString();

  /// UUID estable para la copia de un registro en conflicto.
  static String copyId(String id, String fingerprint) =>
      _uuidFrom('cielord-import-copy|$id|$fingerprint');

  static String copyMediaId(String targetObservation, String mediaId) =>
      _uuidFrom('cielord-import-media|$targetObservation|$mediaId');

  static String _uuidFrom(String seed) {
    final bytes = sha256.convert(utf8.encode(seed)).bytes.sublist(0, 16);
    bytes[6] = (bytes[6] & 0x0f) | 0x80; // versión 8: derivado a medida
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // ── Lectura ─────────────────────────────────────────────────────────────

  static Object? decodeJson(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException catch (error) {
      throw BackupInvalid('invalid_structure', error.message);
    }
  }

  static BackupManifest readManifest(Object? raw) {
    // La versión se comprueba antes que las claves: un formato futuro debe
    // informarse como "versión más nueva", no como archivo dañado.
    if (raw is! Map<String, Object?> || raw['format'] != format) {
      throw const BackupInvalid('invalid_structure', 'format');
    }
    if (raw['schemaVersion'] != schemaVersion) {
      throw BackupInvalid('unsupported_version', '${raw['schemaVersion']}');
    }
    final json = _Reader('manifest', raw, const {
      'format',
      'schemaVersion',
      'createdAt',
      'appVersion',
      'databaseVersion',
      'counts',
      'data',
      'files',
      'missingMedia',
    });
    final appVersion = json.string('appVersion');
    if (appVersion.length > 40) json.fail('appVersion');
    json.integer('databaseVersion', min: 1);
    final counted = _Reader('counts', json.map('counts'), const {
      'observations',
      'drafts',
      'photos',
      'audios',
      'profile',
    });
    final data = _Reader('data', json.map('data'), const {
      'path',
      'byteSize',
      'sha256',
    });
    if (data.string('path') != dataName) data.fail('path');
    return BackupManifest(
      schemaVersion: schemaVersion,
      createdAt: json.date('createdAt') ?? json.fail('createdAt'),
      appVersion: appVersion,
      dataSize: data.integer('byteSize', min: 2),
      dataSha256: data.hash('sha256'),
      media: _readMedia(json.list('files')),
      missingMedia: json.list('missingMedia').length,
      observationCount: counted.integer('observations', min: 0),
      draftCount: counted.integer('drafts', min: 0),
    );
  }

  static Map<String, BackupMedia> _readMedia(List<Object?> raw) {
    final media = <String, BackupMedia>{};
    for (final item in raw) {
      final json = _Reader('media', item, const {
        'id',
        'kind',
        'path',
        'mimeType',
        'byteSize',
        'sha256',
        'durationMs',
      });
      final id = json.id('id');
      final kind = json.code('kind', MediaKind.values.asNameMap())!;
      final parsed = BackupMedia(
        id: id,
        kind: kind,
        byteSize: json.integer('byteSize', min: 1),
        sha256: json.hash('sha256'),
        durationMs: json.integerOrNull('durationMs'),
      );
      if (json.string('path') != parsed.path) json.fail('path');
      if (json.string('mimeType') != parsed.mimeType) {
        throw BackupInvalid('wrong_type', parsed.path);
      }
      final duration = parsed.durationMs;
      final durationOk = kind == MediaKind.photo
          ? duration == null
          : duration != null && duration >= 1 && duration <= 120000;
      if (!durationOk) json.fail('durationMs');
      if (media.containsKey(id)) json.fail('id');
      media[id] = parsed;
    }
    return media;
  }

  static BackupData readData(Object? raw, BackupManifest manifest) {
    final json = _Reader('data', raw, const {
      'schemaVersion',
      'observations',
      'media',
      'profile',
    });
    if (json.integer('schemaVersion', min: 1) != schemaVersion) {
      throw const BackupInvalid('unsupported_version');
    }
    final media = _readMedia(json.list('media'));
    if (media.length != manifest.media.length ||
        media.values.any((m) => !_same(m, manifest.media[m.id]))) {
      json.fail('media');
    }
    final unused = media.keys.toSet();
    final ids = <String>{};
    final observations = [
      for (final item in json.list('observations'))
        _readObservation(item, media, unused),
    ]..sort((a, b) => a.id.compareTo(b.id));
    if (observations.any((o) => !ids.add(o.id))) json.fail('observations');
    final profile = json.raw('profile') == null
        ? null
        : _readProfile(json.raw('profile'), media, unused);
    if (unused.isNotEmpty) json.fail('media.unreferenced');
    final drafts = observations
        .where((o) => o.status == ObservationStatus.draft)
        .length;
    if (observations.length != manifest.observationCount ||
        drafts != manifest.draftCount) {
      json.fail('counts');
    }
    return BackupData(
      observations: observations,
      media: media,
      profile: profile,
    );
  }

  static bool _same(BackupMedia a, BackupMedia? b) =>
      b != null &&
      a.kind == b.kind &&
      a.byteSize == b.byteSize &&
      a.sha256 == b.sha256 &&
      a.durationMs == b.durationMs;

  static ObserverProfile _readProfile(
    Object? raw,
    Map<String, BackupMedia> media,
    Set<String> unused,
  ) {
    final json = _Reader('profile', raw, const {
      'firstName',
      'lastName',
      'studentId',
      'motto',
      'photoMediaId',
    });
    final photo = json.stringOrNull('photoMediaId');
    if (photo != null &&
        (media[photo]?.kind != MediaKind.photo || !unused.remove(photo))) {
      json.fail('photoMediaId');
    }
    final profile = ObserverProfile(
      firstName: json.string('firstName'),
      lastName: json.string('lastName'),
      studentId: json.string('studentId'),
      motto: json.string('motto'),
      photoMediaId: photo,
    );
    if (SqliteProfileRepository.validate(profile).isNotEmpty) {
      json.fail('fields');
    }
    return profile;
  }

  static Observation _readObservation(
    Object? raw,
    Map<String, BackupMedia> media,
    Set<String> unused,
  ) {
    final json = _Reader('observation', raw, const {
      'id',
      'status',
      'title',
      'observedAt',
      'utcOffsetMinutes',
      'category',
      'subtype',
      'sky',
      'description',
      'durationSeconds',
      'direction',
      'elevationDegrees',
      'location',
      'media',
      'createdAt',
      'updatedAt',
      'revision',
    });
    final attachments = <ObservationMedia>[];
    for (final id in json.list('media')) {
      final item = media[id];
      if (item == null || !unused.remove(id)) json.fail('media');
      attachments.add(item.toMedia(item.id));
    }
    ObservationLocation? location;
    if (json.raw('location') != null) {
      final l = _Reader('location', json.raw('location'), const {
        'placeName',
        'latitude',
        'longitude',
        'source',
        'accuracyM',
        'capturedAt',
      });
      location = ObservationLocation(
        placeName: l.textOrNull('placeName'),
        latitude: l.number('latitude'),
        longitude: l.number('longitude'),
        source: l.code('source', LocationSource.values.asNameMap()),
        accuracyM: l.number('accuracyM'),
        capturedAt: l.date('capturedAt'),
      );
      // Igual que al leer de SQLite: sin datos, no hay ubicación.
      if (location.placeName == null &&
          !location.hasCoordinates &&
          location.source == null) {
        location = null;
      }
    }
    final status = json.code('status', ObservationStatus.values.asNameMap());
    if (status == null) json.fail('status');
    final input = ObservationInput(
      title: json.string('title').trim(),
      observedAt: json.date('observedAt'),
      utcOffsetMinutes: json.integerOrNull('utcOffsetMinutes'),
      category: json.code('category', ObservationCategory.values.asNameMap()),
      subtypeCode: json.stringOrNull('subtype'),
      skyCondition: json.code('sky', {
        for (final s in SkyCondition.values) s.code: s,
      }),
      description: json.textOrNull('description'),
      durationSeconds: json.integerOrNull('durationSeconds'),
      direction: json.code('direction', {
        for (final d in CardinalDirection.values) d.code: d,
      }),
      elevationDegrees: json.number('elevationDegrees'),
      location: location,
      media: attachments,
    );
    final valid = const ObservationValidator().validate(input, status: status);
    if (valid is Failure<ObservationInput>) {
      json.fail(valid.failure.fieldErrors.keys.join(','));
    }
    final createdAt = json.date('createdAt');
    final updatedAt = json.date('updatedAt');
    if (createdAt == null ||
        updatedAt == null ||
        updatedAt.isBefore(createdAt)) {
      json.fail('updatedAt');
    }
    return Observation(
      id: json.id('id'),
      status: status,
      input: input,
      createdAt: createdAt,
      updatedAt: updatedAt,
      revision: json.integer('revision', min: 1),
    );
  }
}

/// Acceso tipado con claves exactas.
final class _Reader {
  _Reader(this.name, Object? raw, Set<String> keys)
    : _json = _check(name, raw, keys);

  final String name;
  final Map<String, Object?> _json;

  static Map<String, Object?> _check(
    String name,
    Object? raw,
    Set<String> keys,
  ) {
    if (raw is! Map<String, Object?>) {
      throw BackupInvalid('invalid_structure', name);
    }
    if (raw.length != keys.length || !raw.keys.every(keys.contains)) {
      throw BackupInvalid('invalid_structure', '$name keys');
    }
    return raw;
  }

  Never fail(String key) =>
      throw BackupInvalid('invalid_structure', '$name.$key');

  Object? raw(String key) => _json[key];

  T _as<T>(String key) {
    final value = _json[key];
    return value is T ? value : fail(key);
  }

  String string(String key) => _as<String>(key);
  String? stringOrNull(String key) => _as<String?>(key);

  /// Texto recortado; en blanco equivale a ausente, como en SQLite.
  String? textOrNull(String key) {
    final value = stringOrNull(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  List<Object?> list(String key) => _as<List<Object?>>(key);
  Map<String, Object?> map(String key) => _as<Map<String, Object?>>(key);
  int? integerOrNull(String key) => _as<int?>(key);

  int integer(String key, {required int min}) {
    final value = _as<int>(key);
    return value < min ? fail(key) : value;
  }

  double? number(String key) => _as<num?>(key)?.toDouble();

  String id(String key) {
    final value = string(key);
    return BackupCodec.isSafeId(value) ? value : fail(key);
  }

  String hash(String key) {
    final value = string(key);
    return BackupCodec._sha.hasMatch(value) ? value : fail(key);
  }

  T? code<T>(String key, Map<String, T> values) {
    final value = stringOrNull(key);
    if (value == null) return null;
    return values[value] ?? fail(key);
  }

  DateTime? date(String key) {
    final value = stringOrNull(key);
    if (value == null) return null;
    if (!BackupCodec._utc.hasMatch(value)) fail(key);
    final parsed = DateTime.tryParse(value);
    // `tryParse` normaliza fechas imposibles (31 de febrero): se rechazan.
    if (parsed == null || parsed.toIso8601String() != value) fail(key);
    return parsed;
  }
}
