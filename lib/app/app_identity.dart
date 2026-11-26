import '../features/profile/domain/profile_repository.dart';

/// Identidad académica definitiva empaquetada con CieloRD.
abstract final class AppIdentity {
  static const String firstName = 'Michael Dmeshell';
  static const String lastName = 'Sanchez Heredia';
  static const String fullName = 'Michael Dmeshell Sanchez Heredia';
  static const String studentId = '2024-0063';
  static const String motto = '«¡Quiero vivir!» — Nico Robin';
  static const String profilePhotoAsset = 'assets/profile/michael_heredia.webp';
  static const String profilePhotoJpegAsset =
      'assets/profile/michael_heredia_seed.jpg';
  static const String profilePhotoThumbnailAsset =
      'assets/profile/michael_heredia_seed_thumb.jpg';

  static const ObserverProfile profile = ObserverProfile(
    firstName: firstName,
    lastName: lastName,
    studentId: studentId,
    motto: motto,
  );
}
