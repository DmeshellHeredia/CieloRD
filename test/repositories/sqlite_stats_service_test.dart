import 'dart:io';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/map/domain/offline_province_map.dart';
import 'package:cielo_rd/features/statistics/data/sqlite_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/hito_c_env.dart';

void main() {
  final map = OfflineProvinceMap.parse(
    File('assets/maps/dominican_republic_adm1.geojson').readAsStringSync(),
  );
  final published = ObservationFilter(status: ObservationStatus.published);

  ObservationLocation text(String place) =>
      ObservationLocation(placeName: place, source: LocationSource.text);
  ObservationLocation point(double lat, double lon) => ObservationLocation(
    latitude: lat,
    longitude: lon,
    source: LocationSource.manual,
  );

  test('sin datos: todo en cero y sin errores', () async {
    final env = await HitoCEnv.create();
    final stats = ok(
      await SqliteStatsService(
        database: env.database,
        provinceMap: map,
      ).summarize(published),
    );
    expect(stats.total, 0);
    expect(stats.knownDurationSeconds, 0);
    expect(stats.withKnownDuration, 0);
    expect(stats.byCategory, isEmpty);
    expect(stats.byLocalMonth, isEmpty);
    expect(stats.byLocalHour, isEmpty);
    expect(stats.byProvince, isEmpty);
    expect(stats.byPlace, isEmpty);
    expect(stats.inMonthOf(DateTime(2026, 11)), 0);
  });

  test(
    'conjunto conocido: categorías, meses, horas, lugares y duración',
    () async {
      final env = await HitoCEnv.create();
      // 22 nov 2026 02:00Z − 4 h = 21 nov 22:00 local.
      await env.add(
        env.input(
          at: DateTime.utc(2026, 11, 22, 2),
          duration: 90,
          location: text('Constanza'),
        ),
      );
      await env.add(
        env.input(
          at: DateTime.utc(2026, 11, 22, 2, 59, 59, 999),
          duration: 0,
          location: text('  CONSTANZÁ '),
        ),
      );
      await env.add(
        env.input(
          at: DateTime.utc(2026, 10, 5, 12),
          category: ObservationCategory.birds,
          location: text('Samaná'),
        ),
      );
      // Santo Domingo (Distrito Nacional) dos veces y Santiago una vez.
      await env.add(env.input(location: point(18.4861, -69.9312)));
      await env.add(env.input(location: point(18.4861, -69.9312)));
      await env.add(env.input(location: point(19.4517, -70.6970)));
      // En el mar Caribe: cuenta en el total, no en provincias.
      await env.add(env.input(location: point(16.0, -70.0)));

      final stats = ok(
        await SqliteStatsService(
          database: env.database,
          provinceMap: map,
        ).summarize(published),
      );
      expect(stats.total, 7);
      expect(stats.byCategory, {
        ObservationCategory.astronomy: 6,
        ObservationCategory.birds: 1,
      });
      expect(stats.byLocalMonth, {'2026-10': 1, '2026-11': 6});
      expect(stats.byLocalMonth.keys.toList(), ['2026-10', '2026-11']);
      expect(stats.byLocalHour, {8: 1, 22: 6});
      expect(
        stats.withKnownDuration,
        2,
        reason: '0 s es una duración conocida',
      );
      expect(stats.knownDurationSeconds, 90);
      expect(stats.inMonthOf(DateTime(2026, 11, 30)), 6);
      expect(stats.inMonthOf(DateTime(2025, 11, 30)), 0);
      expect(stats.byProvince.values.fold(0, (a, b) => a + b), 3);
      expect(
        stats.byProvince[map
            .provinceAt(const GeoCoordinate(18.4861, -69.9312))!
            .name],
        2,
      );
      expect(stats.byPlace.map((p) => p.count), [2, 1]);
      expect(stats.byPlace.last.place, 'Samaná');
    },
  );

  test('los borradores se excluyen por defecto y se pueden incluir', () async {
    final env = await HitoCEnv.create();
    await env.add(env.input(duration: 10));
    await env.add(
      env.input(duration: 500, location: text('Borrador')),
      status: ObservationStatus.draft,
    );
    final service = SqliteStatsService(database: env.database);
    final defaults = ok(await service.summarize(ObservationFilter()));
    expect(defaults.total, 1);
    expect(defaults.knownDurationSeconds, 10);
    expect(defaults.byPlace, isEmpty);
    final all = ok(await service.summarize(ObservationFilter(status: null)));
    expect(all.total, 2);
    expect(all.knownDurationSeconds, 510);
  });

  test('límites: fin de mes, de año y desplazamientos opuestos', () async {
    final env = await HitoCEnv.create();
    // Último milisegundo de 2026 y primero de 2027, hora dominicana.
    await env.add(env.input(at: DateTime.utc(2027, 1, 1, 3, 59, 59, 999)));
    await env.add(env.input(at: DateTime.utc(2027, 1, 1, 4)));
    // Mismo instante, otra zona: ya es 1 de enero a las 13:00.
    await env.add(env.input(at: DateTime.utc(2027, 1, 1, 4), offset: 540));
    // Año bisiesto y fecha anterior a 1970.
    await env.add(env.input(at: DateTime.utc(2028, 3, 1, 3, 30)));
    await env.add(env.input(at: DateTime.utc(1969, 12, 31, 23, 30), offset: 0));
    final stats = ok(
      await SqliteStatsService(database: env.database).summarize(published),
    );
    expect(stats.byLocalDate, {
      '1969-12-31': 1,
      '2026-12-31': 1,
      '2027-01-01': 2,
      '2028-02-29': 1,
    });
    expect(stats.byLocalHour, {0: 1, 13: 1, 23: 3});
    expect(stats.inMonthOf(DateTime(2026, 12, 1)), 1);
    expect(stats.inMonthOf(DateTime(2027, 1, 31)), 2);
  });

  test(
    'el filtro por fecha es inclusivo al inicio y exclusivo al final',
    () async {
      final env = await HitoCEnv.create();
      final from = DateTime.utc(2026, 11, 1, 4);
      final until = DateTime.utc(2026, 12, 1, 4);
      await env.add(env.input(at: from));
      await env.add(env.input(at: until));
      final stats = ok(
        await SqliteStatsService(database: env.database)
            .summarize(ObservationFilter(from: from, until: until)),
      );
      expect(stats.total, 1);
    },
  );

  test('cuenta lo mismo que el Diario con 600 registros', () async {
    final env = await HitoCEnv.create();
    final db = await env.database.open();
    final batch = db.batch();
    for (var i = 0; i < 600; i++) {
      batch.insert('observations', {
        'id': 'bulk-$i',
        'status': i % 5 == 0 ? 'draft' : 'published',
        'title': 'Registro $i',
        'observed_at_utc_ms': 1760000000000 + i * 3600000,
        'utc_offset_minutes': -240,
        'category_code': ObservationCategory.values[i % 5].name,
        'created_at': 1,
        'updated_at': 1,
        'revision': 1,
      });
    }
    await batch.commit(noResult: true);
    final stats = ok(
      await SqliteStatsService(database: env.database).summarize(published),
    );
    expect(stats.total, ok(await env.store.count(filter: published)));
    expect(stats.total, 480);
    expect(stats.byLocalHour.values.fold(0, (a, b) => a + b), 480);
    expect(stats.byLocalDate.values.fold(0, (a, b) => a + b), 480);
  });
}
