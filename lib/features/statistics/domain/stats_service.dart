import '../../../core/domain/result.dart';
import '../../observations/domain/observation_filter.dart';
import '../../observations/domain/observation_types.dart';

/// Conteo de un lugar escrito, con la grafía más reciente.
final class PlaceCount {
  const PlaceCount({required this.place, required this.count});
  final String place;
  final int count;
}

final class ObservationStats {
  ObservationStats({
    required this.total,
    required this.knownDurationSeconds,
    required this.withKnownDuration,
    required Map<ObservationCategory, int> byCategory,
    required Map<String, int> byLocalDate,
    required Map<int, int> byLocalHour,
    required Map<String, int> byProvince,
    List<PlaceCount> byPlace = const [],
  }) : byCategory = Map.unmodifiable(byCategory),
       byLocalDate = Map.unmodifiable(byLocalDate),
       byLocalHour = Map.unmodifiable(byLocalHour),
       byProvince = Map.unmodifiable(byProvince),
       byPlace = List.unmodifiable(byPlace);
  final int total;
  final int knownDurationSeconds;
  final int withKnownDuration;
  final Map<ObservationCategory, int> byCategory;

  /// YYYY-MM-DD in each observation's recorded offset.
  final Map<String, int> byLocalDate;
  final Map<int, int> byLocalHour;

  /// Stable province code derived offline; unmapped records excluded.
  final Map<String, int> byProvince;

  /// Lugares escritos, de más a menos frecuente (agrupados sin acentos ni
  /// mayúsculas). Las observaciones sin lugar escrito no cuentan.
  final List<PlaceCount> byPlace;

  /// YYYY-MM → conteo, en orden cronológico.
  late final Map<String, int> byLocalMonth = _months();

  Map<String, int> _months() {
    final months = <String, int>{};
    for (final date in byLocalDate.keys.toList()..sort()) {
      final month = date.substring(0, 7);
      months[month] = (months[month] ?? 0) + byLocalDate[date]!;
    }
    return Map.unmodifiable(months);
  }

  /// Observaciones cuyo mes local coincide con el de [now] (hora de pared).
  int inMonthOf(DateTime now) => byLocalMonth[monthKey(now)] ?? 0;

  static String monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';
}

abstract interface class StatsService {
  Future<Result<ObservationStats>> summarize(ObservationFilter filter);
}
