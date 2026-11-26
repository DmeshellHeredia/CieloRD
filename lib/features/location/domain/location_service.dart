import '../../../core/domain/result.dart';
import '../../observations/domain/observation_types.dart';

enum LocationPermission {
  notDetermined,
  denied,
  deniedPermanently,
  approximate,
  precise,
}

final class LocationFix {
  LocationFix({required this.location, required DateTime capturedAt})
    : capturedAt = capturedAt.toUtc();
  final ObservationLocation location;
  final DateTime capturedAt;
}

abstract interface class LocationService {
  /// Does not trigger a permission dialog.
  Future<Result<LocationPermission>> permission();

  /// May request foreground permission only after a user action.
  Future<Result<LocationFix>> current({
    Duration timeout = const Duration(seconds: 20),
  });
}
