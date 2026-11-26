import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../../map/domain/offline_province_map.dart';
import '../../observations/data/observation_filter_sql.dart';
import '../../observations/domain/observation_filter.dart';
import '../../observations/domain/observation_types.dart';
import '../domain/stats_service.dart';

/// Agregados calculados por SQLite; nunca carga observaciones completas.
///
/// Todas las consultas corren en una transacción para que las cifras sean
/// coherentes entre sí. Día y hora usan el desplazamiento guardado en cada
/// observación, no la zona del teléfono.
final class SqliteStatsService implements StatsService {
  const SqliteStatsService({
    required this.database,
    this.provinceMap,
    this.maxPlaces = 10,
  });

  final AppDatabase database;

  /// Límites provinciales empaquetados; sin ellos no hay conteo por provincia.
  final OfflineProvinceMap? provinceMap;
  final int maxPlaces;

  static const String _local =
      '(observed_at_utc_ms + utc_offset_minutes * 60000) / 1000.0';

  @override
  Future<Result<ObservationStats>> summarize(ObservationFilter filter) async {
    final where = ObservationFilterSql.from(filter);
    try {
      final db = await database.open();
      return await db.transaction((txn) async {
        Future<List<Map<String, Object?>>> grouped(
          String select,
          String condition,
          String tail,
        ) => txn.rawQuery(
          'SELECT $select, COUNT(*) AS n FROM observations '
          '${where.sqlAnd(condition)} $tail',
          where.args,
        );

        final totals = (await txn.rawQuery(
          'SELECT COUNT(*) AS n, COUNT(duration_seconds) AS known, '
          'COALESCE(SUM(duration_seconds), 0) AS seconds '
          'FROM observations ${where.sql}',
          where.args,
        )).single;
        final categories = await grouped(
          'category_code AS k',
          'category_code IS NOT NULL',
          'GROUP BY category_code',
        );
        final dates = await grouped(
          "strftime('%Y-%m-%d', $_local, 'unixepoch') AS k",
          'observed_at_utc_ms IS NOT NULL',
          'GROUP BY k ORDER BY k',
        );
        final hours = await grouped(
          "CAST(strftime('%H', $_local, 'unixepoch') AS INTEGER) AS k",
          'observed_at_utc_ms IS NOT NULL',
          'GROUP BY k ORDER BY k',
        );
        // Con MAX() SQLite toma place_name de la fila más reciente del grupo.
        final places = await grouped(
          'place_search, place_name AS k, MAX(updated_at) AS recent',
          "place_search IS NOT NULL AND place_search != ''",
          'GROUP BY place_search ORDER BY n DESC, place_search ASC '
              'LIMIT $maxPlaces',
        );
        final points = provinceMap == null
            ? const <Map<String, Object?>>[]
            : await grouped(
                'latitude, longitude',
                'latitude IS NOT NULL',
                'GROUP BY latitude, longitude',
              );
        return Success(
          ObservationStats(
            total: totals['n']! as int,
            withKnownDuration: totals['known']! as int,
            knownDurationSeconds: totals['seconds']! as int,
            byCategory: {
              for (final r in categories)
                ObservationCategory.values.byName(r['k']! as String):
                    r['n']! as int,
            },
            byLocalDate: {
              for (final r in dates) r['k']! as String: r['n']! as int,
            },
            byLocalHour: {
              for (final r in hours) r['k']! as int: r['n']! as int,
            },
            byProvince: _provinces(points),
            byPlace: [
              for (final r in places)
                PlaceCount(place: r['k']! as String, count: r['n']! as int),
            ],
          ),
        );
      });
    } on DatabaseException catch (error) {
      return Failure(
        AppFailure(FailureCode.persistence, message: error.toString()),
      );
    } on Object catch (error) {
      return Failure(
        AppFailure(FailureCode.unexpected, message: error.toString()),
      );
    }
  }

  Map<String, int> _provinces(List<Map<String, Object?>> points) {
    final counts = <String, int>{};
    for (final r in points) {
      final province = provinceMap!.provinceAt(
        GeoCoordinate(
          (r['latitude']! as num).toDouble(),
          (r['longitude']! as num).toDouble(),
        ),
      );
      if (province == null) continue;
      counts[province.name] = (counts[province.name] ?? 0) + (r['n']! as int);
    }
    return counts;
  }
}
