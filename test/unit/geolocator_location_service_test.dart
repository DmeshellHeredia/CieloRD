import 'dart:async';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/location/data/geolocator_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;

void main() {
  geo.Position position() => geo.Position(
    longitude: -69.9312,
    latitude: 18.4861,
    timestamp: DateTime.utc(2026, 11, 22, 18, 30),
    accuracy: 8.5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  test(
    'permission checks without requesting and reports approximate access',
    () async {
      var requests = 0;
      final service = GeolocatorLocationService(
        isServiceEnabled: () async => true,
        checkPermission: () async => geo.LocationPermission.whileInUse,
        requestPermission: () async {
          requests++;
          return geo.LocationPermission.whileInUse;
        },
        getAccuracy: () async => geo.LocationAccuracyStatus.reduced,
        getCurrentPosition: (_) async => position(),
      );
      final result = await service.permission() as Success<LocationPermission>;
      expect(result.value, LocationPermission.approximate);
      expect(requests, 0);
    },
  );

  test(
    'current requests foreground permission only after explicit call',
    () async {
      var requests = 0;
      final service = GeolocatorLocationService(
        isServiceEnabled: () async => true,
        checkPermission: () async => geo.LocationPermission.denied,
        requestPermission: () async {
          requests++;
          return geo.LocationPermission.whileInUse;
        },
        getAccuracy: () async => geo.LocationAccuracyStatus.precise,
        getCurrentPosition: (_) async => position(),
        clock: () => DateTime.utc(2026, 11, 22, 18, 30),
      );
      final result = await service.current() as Success<LocationFix>;
      expect(requests, 1);
      expect(result.value.location.source, LocationSource.gps);
      expect(result.value.location.latitude, 18.4861);
      expect(result.value.location.longitude, -69.9312);
      expect(result.value.location.accuracyM, 8.5);
      expect(
        result.value.location.capturedAt,
        DateTime.utc(2026, 11, 22, 18, 30),
      );
      expect(result.value.capturedAt, result.value.location.capturedAt);
    },
  );

  test(
    'current reports disabled, denied, denied forever and timeout',
    () async {
      GeolocatorLocationService service({
        bool enabled = true,
        geo.LocationPermission checked = geo.LocationPermission.denied,
        geo.LocationPermission requested = geo.LocationPermission.denied,
        Future<geo.Position> Function(geo.LocationSettings)? current,
      }) => GeolocatorLocationService(
        isServiceEnabled: () async => enabled,
        checkPermission: () async => checked,
        requestPermission: () async => requested,
        getAccuracy: () async => geo.LocationAccuracyStatus.precise,
        getCurrentPosition: current ?? (_) async => position(),
        clock: () => DateTime.utc(2026, 11, 22, 18, 30),
      );

      expect(
        (await service(enabled: false).current() as Failure<LocationFix>)
            .failure
            .code,
        FailureCode.serviceDisabled,
      );
      expect(
        (await service().current() as Failure<LocationFix>).failure.code,
        FailureCode.permissionDenied,
      );
      expect(
        (await service(requested: geo.LocationPermission.deniedForever)
                    .current()
                as Failure<LocationFix>)
            .failure
            .code,
        FailureCode.permissionPermanentlyDenied,
      );
      expect(
        (await service(
                  checked: geo.LocationPermission.whileInUse,
                  current: (_) => throw TimeoutException('GPS'),
                ).current()
                as Failure<LocationFix>)
            .failure
            .code,
        FailureCode.timeout,
      );
    },
  );
}
