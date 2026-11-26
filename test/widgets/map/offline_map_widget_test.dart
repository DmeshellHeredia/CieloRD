import 'dart:ui' show PointerDeviceKind;

import 'package:cielo_rd/app/cielo_app.dart';
import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/design/design.dart';
import 'package:cielo_rd/features/map/domain/offline_province_map.dart';
import 'package:cielo_rd/features/map/presentation/province_map_view.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';

OfflineProvinceMap _tinyMap() => OfflineProvinceMap.parse('''
{"type":"FeatureCollection","features":[{"type":"Feature",
"properties":{"shapeName":"Santiago"},"geometry":{"type":"Polygon",
"coordinates":[[[-71,19],[-70,19],[-70,20],[-71,20],[-71,19]]]}}]}
''');

Offset _canvasOffset(
  OfflineProvinceMap map,
  GeoCoordinate coordinate,
  Size size,
) {
  const padding = 32.0;
  final nw = WebMercator.project(
    GeoCoordinate(map.bounds.north, map.bounds.west),
  );
  final se = WebMercator.project(
    GeoCoordinate(map.bounds.south, map.bounds.east),
  );
  final point = WebMercator.project(coordinate);
  return Offset(
    padding + (point.x - nw.x) / (se.x - nw.x) * (size.width - padding * 2),
    padding + (point.y - nw.y) / (se.y - nw.y) * (size.height - padding * 2),
  );
}

void main() {
  testWidgets(
    'manual map selection returns province and reports outside coverage',
    (tester) async {
      final map = _tinyMap();
      OfflineMapSelection? selected;
      GeoCoordinate? outside;
      await pumpCielo(
        tester,
        ProvinceMapView(
          map: map,
          onSelected: (value) => selected = value,
          onOutsideCoverage: (value) => outside = value,
        ),
        scrollable: false,
      );
      final detector = tester.widget<GestureDetector>(
        find.byKey(const ValueKey<String>('province_map_surface')),
      );
      detector.onTapUp!(
        TapUpDetails(
          kind: PointerDeviceKind.touch,
          localPosition: _canvasOffset(
            map,
            const GeoCoordinate(19.4517, -70.6970),
            tester.getSize(
              find.byKey(const ValueKey<String>('province_map_surface')),
            ),
          ),
        ),
      );
      expect(selected?.province.name, 'Santiago');
      detector.onTapUp!(
        TapUpDetails(
          kind: PointerDeviceKind.touch,
          localPosition: Offset(-1000, -1000),
        ),
      );
      expect(outside, isNotNull);
    },
  );

  for (final variant in CieloThemeVariant.values) {
    testWidgets(
      'Diary map route renders marker and attribution in ${variant.name}',
      (tester) async {
        final map = _tinyMap();
        final observation = Observation(
          id: 'mapped',
          status: ObservationStatus.published,
          revision: 1,
          createdAt: DateTime.utc(2026, 11, 23),
          updatedAt: DateTime.utc(2026, 11, 23),
          input: ObservationInput(
            title: 'Santiago',
            observedAt: DateTime.utc(2026, 11, 23),
            utcOffsetMinutes: -240,
            category: ObservationCategory.astronomy,
            location: const ObservationLocation(
              latitude: 19.4517,
              longitude: -70.6970,
              source: LocationSource.manual,
            ),
          ),
        );
        final store = InMemoryObservationRepository(
          observations: [observation],
        );
        await tester.pumpWidget(
          CieloApp(
            observations: store,
            observationService: store,
            drafts: store,
            initialVariant: variant,
            provinceMap: map,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byTooltip('Mapa offline'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Mapa offline'), findsOneWidget);
        expect(find.text('1 observaciones con coordenadas'), findsOneWidget);
        expect(find.text('geoBoundaries · Natural Earth'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
