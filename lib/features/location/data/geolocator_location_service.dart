import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;

import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../../observations/domain/observation_types.dart';
import '../domain/location_service.dart';

typedef CurrentPositionReader = Future<geo.Position> Function(
  geo.LocationSettings settings,
);

/// Foreground-only GPS adapter. It deliberately has no last-known-position
/// dependency, so cached coordinates cannot be presented as a fresh fix.
final class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({
    Future<bool> Function()? isServiceEnabled,
    Future<geo.LocationPermission> Function()? checkPermission,
    Future<geo.LocationPermission> Function()? requestPermission,
    Future<geo.LocationAccuracyStatus> Function()? getAccuracy,
    CurrentPositionReader? getCurrentPosition,
    DateTime Function()? clock,
  }) : _isServiceEnabled =
           isServiceEnabled ?? geo.Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? geo.Geolocator.checkPermission,
       _requestPermission =
           requestPermission ?? geo.Geolocator.requestPermission,
       _getAccuracy = getAccuracy ?? geo.Geolocator.getLocationAccuracy,
       _getCurrentPosition =
           getCurrentPosition ??
           ((settings) =>
               geo.Geolocator.getCurrentPosition(locationSettings: settings)),
       _clock = clock ?? DateTime.now;

  final Future<bool> Function() _isServiceEnabled;
  final Future<geo.LocationPermission> Function() _checkPermission;
  final Future<geo.LocationPermission> Function() _requestPermission;
  final Future<geo.LocationAccuracyStatus> Function() _getAccuracy;
  final CurrentPositionReader _getCurrentPosition;
  final DateTime Function() _clock;

  @override
  Future<Result<LocationPermission>> permission() async {
    try {
      return Success(await _mapPermission(await _checkPermission()));
    } on Object catch (error) {
      return Failure(_failure(error));
    }
  }

  @override
  Future<Result<LocationFix>> current({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      if (!await _isServiceEnabled()) {
        return Failure(AppFailure(FailureCode.serviceDisabled));
      }
      var permission = await _checkPermission();
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.unableToDetermine) {
        permission = await _requestPermission();
      }
      if (permission == geo.LocationPermission.deniedForever) {
        return Failure(AppFailure(FailureCode.permissionPermanentlyDenied));
      }
      if (!_granted(permission)) {
        return Failure(AppFailure(FailureCode.permissionDenied));
      }

      final position = await _getCurrentPosition(
        geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      final capturedAt = _clock().toUtc();
      final location = ObservationLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        source: LocationSource.gps,
        accuracyM: position.accuracy,
        capturedAt: capturedAt,
      );
      return Success(LocationFix(location: location, capturedAt: capturedAt));
    } on Object catch (error) {
      return Failure(_failure(error));
    }
  }

  Future<LocationPermission> _mapPermission(
    geo.LocationPermission permission,
  ) async {
    switch (permission) {
      case geo.LocationPermission.denied:
        return LocationPermission.denied;
      case geo.LocationPermission.deniedForever:
        return LocationPermission.deniedPermanently;
      case geo.LocationPermission.unableToDetermine:
        return LocationPermission.notDetermined;
      case geo.LocationPermission.whileInUse:
      case geo.LocationPermission.always:
        final accuracy = await _getAccuracy();
        return accuracy == geo.LocationAccuracyStatus.precise
            ? LocationPermission.precise
            : LocationPermission.approximate;
    }
  }

  static bool _granted(geo.LocationPermission value) =>
      value == geo.LocationPermission.whileInUse ||
      value == geo.LocationPermission.always;

  static AppFailure _failure(Object error) {
    if (error is TimeoutException) return AppFailure(FailureCode.timeout);
    if (error is geo.LocationServiceDisabledException) {
      return AppFailure(FailureCode.serviceDisabled);
    }
    if (error is geo.PermissionDeniedException) {
      return AppFailure(FailureCode.permissionDenied);
    }
    return AppFailure(FailureCode.unavailable, message: error.toString());
  }
}
