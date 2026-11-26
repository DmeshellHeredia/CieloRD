import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../../media/data/local_media_service.dart';
import '../domain/profile_repository.dart';

typedef ProfileAssetLoader = Future<Uint8List> Function(String assetPath);

/// Instala la identidad inicial una sola vez por instalación de Android.
///
/// El marcador no contiene datos personales y vive fuera de las carpetas que
/// administra Borrar Todo. Así, después de borrar, el perfil queda vacío y se
/// puede recrear desde Editar perfil sin que la identidad reaparezca sola.
final class InitialProfileSeeder {
  const InitialProfileSeeder({
    required this.repository,
    required this.media,
    required this.supportDirectory,
    required this.profile,
    required this.photoAsset,
    required this.photoThumbnailAsset,
    required this.loadAsset,
  });

  static const String markerName = 'initial_profile_seeded.v1';

  final ProfileRepository repository;
  final LocalMediaService media;
  final Future<Directory> Function() supportDirectory;
  final ObserverProfile profile;
  final String photoAsset;
  final String photoThumbnailAsset;
  final ProfileAssetLoader loadAsset;

  Future<Result<Unit>> run() async {
    try {
      final File marker = File(
        p.join((await supportDirectory()).path, markerName),
      );
      if (await marker.exists()) return const Success(Unit.value);

      final Result<ObserverProfile?> current = await repository.get();
      switch (current) {
        case Failure<ObserverProfile?>(:final failure):
          return Failure(failure);
        case Success<ObserverProfile?>(value: final existing?)
            when !existing.isEmpty:
          await _writeMarker(marker);
          return const Success(Unit.value);
        case Success<ObserverProfile?>():
          break;
      }

      final Uint8List bytes = await loadAsset(photoAsset);
      final Uint8List thumbnailBytes = await loadAsset(photoThumbnailAsset);
      final stagedResult = await media.stageBundledPhoto(
        bytes,
        thumbnailBytes: thumbnailBytes,
      );
      if (stagedResult case Failure(:final failure)) {
        return Failure(failure);
      }
      final staged = (stagedResult as Success).value;
      final Result<ObserverProfile> saved = await repository.save(
        ObserverProfile(
          firstName: profile.firstName,
          lastName: profile.lastName,
          studentId: profile.studentId,
          motto: profile.motto,
          photoMediaId: staged.id,
        ),
        newPhoto: staged,
      );
      if (saved case Failure<ObserverProfile>(:final failure)) {
        await media.discardStaged(staged.id);
        return Failure(failure);
      }
      final Result<Unit> committed = await media.commitStaged([staged.id]);
      if (committed case Failure<Unit>()) return committed;
      await _writeMarker(marker);
      return const Success(Unit.value);
    } on Object catch (error) {
      return Failure(AppFailure(FailureCode.io, message: error.toString()));
    }
  }

  static Future<void> _writeMarker(File marker) async {
    await marker.parent.create(recursive: true);
    final File part = File('${marker.path}.part');
    await part.writeAsString('1', flush: true);
    await part.rename(marker.path);
  }
}
