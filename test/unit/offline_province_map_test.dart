import 'dart:io';

import 'package:cielo_rd/features/map/domain/offline_province_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late OfflineProvinceMap map;
  setUpAll(() async {
    map = OfflineProvinceMap.parse(
      await File('assets/maps/dominican_republic_adm1.geojson').readAsString(),
    );
  });

  test('parses the licensed 32-unit ADM1 asset', () {
    expect(map.provinces, hasLength(32));
    expect(
      map.provinces.map((p) => p.name),
      containsAll(<String>['Santiago', 'La Altagracia', 'Distrito Nacional']),
    );
    expect(map.bounds.contains(const GeoCoordinate(18.4861, -69.9312)), isTrue);
  });

  test('Web Mercator round-trips Dominican coordinates', () {
    const coordinate = GeoCoordinate(19.4517, -70.6970);
    final projected = WebMercator.project(coordinate);
    final restored = WebMercator.unproject(projected);
    expect(restored.latitude, closeTo(coordinate.latitude, 1e-9));
    expect(restored.longitude, closeTo(coordinate.longitude, 1e-9));
  });

  test('selects a province and rejects locations outside coverage', () {
    expect(
      map.provinceAt(const GeoCoordinate(19.4517, -70.6970))?.name,
      'Santiago',
    );
    expect(map.provinceAt(const GeoCoordinate(0, 0)), isNull);
  });
}
