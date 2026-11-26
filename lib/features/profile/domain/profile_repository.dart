import '../../../core/domain/result.dart';
import '../../observations/domain/observation_types.dart';

final class ObserverProfile {
  const ObserverProfile({
    this.firstName = '',
    this.lastName = '',
    this.studentId = '',
    this.motto = '',
    this.photoMediaId,
  });

  /// Longitudes máximas tras recortar espacios.
  static const int maxNameLength = 60;
  static const int maxStudentIdLength = 30;
  static const int maxMottoLength = 200;

  final String firstName;
  final String lastName;

  /// Texto libre: conserva ceros iniciales y guiones. Nunca se deduce.
  final String studentId;
  final String motto;
  final String? photoMediaId;

  String get fullName => [
    firstName.trim(),
    lastName.trim(),
  ].where((part) => part.isNotEmpty).join(' ');

  bool get isEmpty =>
      fullName.isEmpty &&
      studentId.trim().isEmpty &&
      motto.trim().isEmpty &&
      photoMediaId == null;
}

abstract interface class ProfileRepository {
  /// Success(null) before a profile has been saved or after erase-all.
  Future<Result<ObserverProfile?>> get();

  /// [newPhoto] es el adjunto *staged* cuyo ID coincide con `photoMediaId`.
  /// Se registra en la misma transacción; la foto anterior, si deja de usarse,
  /// pasa a la cola de borrado. El llamador confirma el staged tras el éxito.
  Future<Result<ObserverProfile>> save(
    ObserverProfile profile, {
    ObservationMedia? newPhoto,
  });
}
