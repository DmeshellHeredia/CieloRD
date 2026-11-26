// ignore_for_file: prefer_initializing_formals

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/concurrency/write_gate.dart';
import '../../../core/database/app_database.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../../observations/domain/observation_types.dart';
import '../domain/media_service.dart';

typedef PhotoPicker = Future<XFile?> Function(PhotoSource source);
typedef LostPhotoReader = Future<List<XFile>> Function();

final class LocalAudioDraft {
  const LocalAudioDraft({required this.id, required this.partPath});
  final String id;
  final String partPath;
}

/// Owns only copies below the app support directory. Source files returned by
/// the system picker are read, never moved or deleted.
final class LocalMediaService implements MediaService {
  LocalMediaService({
    required AppDatabase database,
    Future<Directory> Function()? supportDirectory,
    PhotoPicker? pick,
    LostPhotoReader? recover,
    String Function()? newId,
    ImagePicker? imagePicker,
    WriteGate? gate,
  }) : _gate = gate ?? WriteGate(),
       _database = database,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _pick = pick,
       _recover = recover,
       _newId = newId ?? _randomId,
       _imagePicker = imagePicker ?? ImagePicker();

  final AppDatabase _database;
  final Future<Directory> Function() _supportDirectory;
  final PhotoPicker? _pick;
  final LostPhotoReader? _recover;
  final String Function() _newId;
  final ImagePicker _imagePicker;
  final WriteGate _gate;
  final Map<String, ObservationMedia> _staged = {};

  @override
  Future<Result<ObservationMedia?>> pickPhoto(PhotoSource source) async {
    try {
      final XFile? file = _pick == null
          ? await _imagePicker.pickImage(
              source: source == PhotoSource.camera
                  ? ImageSource.camera
                  : ImageSource.gallery,
            )
          : await _pick(source);
      if (file == null) return const Success(null);
      return Success(await _gate.write(() => _import(file)));
    } on Object catch (error) {
      return Failure(_ioFailure(error));
    }
  }

  @override
  Future<Result<List<ObservationMedia>>> recoverPhotos() async {
    final imported = <ObservationMedia>[];
    try {
      final List<XFile> files;
      if (_recover != null) {
        files = await _recover();
      } else {
        final response = await _imagePicker.retrieveLostData();
        if (response.exception != null) throw response.exception!;
        files = response.files ?? const [];
      }
      for (final file in files) {
        imported.add(await _gate.write(() => _import(file)));
      }
      return Success(List.unmodifiable(imported));
    } on Object catch (error) {
      for (final media in imported) {
        await _discard(media);
      }
      return Failure(_ioFailure(error));
    }
  }

  Future<ObservationMedia> _import(XFile source) async {
    return _importBytes(await source.readAsBytes());
  }

  /// Importa una foto empaquetada sin pasar por cámara o galería.
  Future<Result<ObservationMedia>> stageBundledPhoto(
    Uint8List bytes, {
    Uint8List? thumbnailBytes,
  }) async {
    try {
      return Success(
        await _gate.write(
          () => thumbnailBytes == null
              ? _importBytes(bytes)
              : _importPreparedJpeg(bytes, thumbnailBytes),
        ),
      );
    } on Object catch (error) {
      return Failure(_ioFailure(error));
    }
  }

  Future<ObservationMedia> _importPreparedJpeg(
    Uint8List sourceBytes,
    Uint8List thumbnailBytes,
  ) async {
    if (!_looksLikeJpeg(sourceBytes) || !_looksLikeJpeg(thumbnailBytes)) {
      throw const FormatException('Invalid prepared JPEG data.');
    }
    final id = _newId();
    if (!_safeId(id)) throw StateError('Unsafe generated media id.');
    final relative = 'media/photos/$id.jpg';
    final thumbRelative = 'media/thumbnails/$id.jpg';
    final root = await _supportDirectory();
    await _writeAtomic(root, relative, sourceBytes);
    try {
      await _writeAtomic(root, thumbRelative, thumbnailBytes);
    } on Object {
      await _deleteRelative(root, relative);
      rethrow;
    }
    final media = ObservationMedia(
      id: id,
      kind: MediaKind.photo,
      relativePath: relative,
      mimeType: 'image/jpeg',
      byteSize: sourceBytes.length,
      sha256: sha256.convert(sourceBytes).toString(),
    );
    _staged[id] = media;
    return media;
  }

  Future<ObservationMedia> _importBytes(Uint8List sourceBytes) async {
    final decoded = image.decodeImage(sourceBytes);
    if (decoded == null) throw const FormatException('Unsupported image data.');
    final id = _newId();
    if (!_safeId(id)) throw StateError('Unsafe generated media id.');
    final relative = 'media/photos/$id.jpg';
    final thumbRelative = 'media/thumbnails/$id.jpg';
    final fullBytes = image.encodeJpg(decoded, quality: 92);
    final thumbnail = image.copyResize(
      decoded,
      width: decoded.width > 480 ? 480 : decoded.width,
      interpolation: image.Interpolation.average,
    );
    final thumbBytes = image.encodeJpg(thumbnail, quality: 82);
    final root = await _supportDirectory();
    await _writeAtomic(root, relative, fullBytes);
    try {
      await _writeAtomic(root, thumbRelative, thumbBytes);
    } on Object {
      await _deleteRelative(root, relative);
      rethrow;
    }
    final media = ObservationMedia(
      id: id,
      kind: MediaKind.photo,
      relativePath: relative,
      mimeType: 'image/jpeg',
      byteSize: fullBytes.length,
      sha256: sha256.convert(fullBytes).toString(),
    );
    _staged[id] = media;
    return media;
  }

  /// Olvida los adjuntos sin confirmar. Solo para Borrar Todo, que elimina los
  /// archivos por su cuenta.
  void resetStaged() => _staged.clear();

  Future<LocalAudioDraft> allocateAudioDraft() =>
      _gate.write(_allocateAudioDraft);

  Future<LocalAudioDraft> _allocateAudioDraft() async {
    final id = _newId();
    if (!_safeId(id)) throw StateError('Unsafe generated media id.');
    final path = await _absolute('media/audio/$id.m4a.part');
    await File(path).parent.create(recursive: true);
    return LocalAudioDraft(id: id, partPath: path);
  }

  Future<ObservationMedia> finalizeAudioDraft(
    LocalAudioDraft draft,
    Duration duration,
  ) => _gate.write(() => _finalizeAudioDraft(draft, duration));

  Future<ObservationMedia> _finalizeAudioDraft(
    LocalAudioDraft draft,
    Duration duration,
  ) async {
    final durationMs = duration.inMilliseconds.clamp(1, 120000);
    final part = File(draft.partPath);
    if (!await part.exists()) {
      throw const FileSystemException('Recording file missing.');
    }
    final finalRelative = 'media/audio/${draft.id}.m4a';
    final finalPath = await _absolute(finalRelative);
    final finalized = await part.rename(finalPath);
    final bytes = await finalized.readAsBytes();
    if (bytes.isEmpty) {
      await finalized.delete();
      throw const FormatException('Empty recording.');
    }
    final media = ObservationMedia(
      id: draft.id,
      kind: MediaKind.audio,
      relativePath: finalRelative,
      mimeType: 'audio/mp4',
      byteSize: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      durationMs: durationMs,
    );
    _staged[draft.id] = media;
    return media;
  }

  Future<void> discardAudioDraft(LocalAudioDraft? draft) async {
    if (draft == null) return;
    final file = File(draft.partPath);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<Result<Unit>> commitStaged(Iterable<String> mediaIds) async {
    final ids = mediaIds.toSet();
    if (ids.any((id) => !_staged.containsKey(id))) {
      return Failure(AppFailure(FailureCode.notFound));
    }
    for (final id in ids) {
      _staged.remove(id);
    }
    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit>> discardStaged(String mediaId) async {
    final media = _staged.remove(mediaId);
    if (media == null) return Failure(AppFailure(FailureCode.notFound));
    try {
      await _discard(media);
      return const Success(Unit.value);
    } on Object catch (error) {
      _staged[mediaId] = media;
      return Failure(_ioFailure(error));
    }
  }

  Future<void> _discard(ObservationMedia media) async {
    final root = await _supportDirectory();
    await _deleteRelative(root, media.relativePath);
    await _deleteRelative(root, 'media/thumbnails/${media.id}.jpg');
    _staged.remove(media.id);
  }

  @override
  Future<Result<String>> resolveLocalPath(String mediaId) async {
    try {
      final staged = _staged[mediaId];
      final relative =
          staged?.relativePath ?? await _relativeFromDatabase(mediaId);
      if (relative == null) return Failure(AppFailure(FailureCode.notFound));
      final file = File(await _absolute(relative));
      return await file.exists()
          ? Success(file.path)
          : Failure(
              AppFailure(
                FailureCode.corruptData,
                message: 'Media file missing.',
              ),
            );
    } on Object catch (error) {
      return Failure(_ioFailure(error));
    }
  }

  @override
  Future<Result<String>> resolveThumbnailPath(String mediaId) async {
    if (!_safeId(mediaId)) return Failure(AppFailure(FailureCode.corruptData));
    try {
      final file = File(await _absolute('media/thumbnails/$mediaId.jpg'));
      return await file.exists()
          ? Success(file.path)
          : Failure(AppFailure(FailureCode.notFound));
    } on Object catch (error) {
      return Failure(_ioFailure(error));
    }
  }

  Future<String?> _relativeFromDatabase(String id) async {
    final db = await _database.open();
    final rows = await db.query(
      'media_files',
      columns: ['relative_path'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['relative_path']! as String;
  }

  Future<String> _absolute(String relative) async {
    if (!_safeRelative(relative)) {
      throw const FormatException('Unsafe media path.');
    }
    final root = await _supportDirectory();
    final rootPath = p.normalize(p.absolute(root.path));
    final target = p.normalize(p.join(rootPath, p.fromUri(relative)));
    if (!p.isWithin(rootPath, target)) {
      throw const FormatException('Escaping media path.');
    }
    return target;
  }

  static Future<void> _writeAtomic(
    Directory root,
    String relative,
    List<int> bytes,
  ) async {
    final target = File(p.join(root.path, p.fromUri(relative)));
    await target.parent.create(recursive: true);
    final part = File('${target.path}.part');
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(target.path);
  }

  static Future<void> _deleteRelative(Directory root, String relative) async {
    if (!_safeRelative(relative)) {
      throw const FormatException('Unsafe media path.');
    }
    final file = File(p.join(root.path, p.fromUri(relative)));
    if (await file.exists()) await file.delete();
  }

  static bool _safeId(String id) => RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id);
  static bool _looksLikeJpeg(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[bytes.length - 2] == 0xff &&
      bytes[bytes.length - 1] == 0xd9;
  static bool _safeRelative(String value) =>
      value.startsWith('media/') &&
      !value.contains('\\') &&
      !value.contains(':') &&
      value
          .split('/')
          .every((part) => part.isNotEmpty && part != '.' && part != '..');

  static String _randomId() {
    final random = Random.secure();
    final entropy = List<int>.generate(12, (_) => random.nextInt(256));
    return '${DateTime.now().microsecondsSinceEpoch}-${sha256.convert(entropy).toString().substring(0, 16)}';
  }

  static AppFailure _ioFailure(Object error) {
    if (error is WriteGateClosed) return AppFailure(FailureCode.busy);
    if (error is FormatException) {
      return AppFailure(FailureCode.corruptData, message: error.message);
    }
    final message = error.toString();
    if (message.contains('No space left') || message.contains('disk full')) {
      return AppFailure(FailureCode.storageFull, message: message);
    }
    return AppFailure(FailureCode.io, message: message);
  }
}
