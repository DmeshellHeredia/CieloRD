import 'package:flutter/foundation.dart';

import '../../../../app/contracts.dart';
import '../../../../l10n/cielo_strings.dart';

/// Rangos de fecha rápidos del Diario. Se convierten a instantes locales
/// (inicio inclusivo, final exclusivo) al construir el [ObservationFilter].
enum DiaryDateRange {
  any(CieloStrings.dateAny),
  today(CieloStrings.dateToday),
  last7Days(CieloStrings.dateLast7),
  last30Days(CieloStrings.dateLast30),
  thisMonth(CieloStrings.dateThisMonth),
  thisYear(CieloStrings.dateThisYear);

  const DiaryDateRange(this.label);
  final String label;

  /// `(from, until)` en hora local del dispositivo; `null` para [any].
  (DateTime, DateTime)? resolve(DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime tomorrow = DateTime(now.year, now.month, now.day + 1);
    return switch (this) {
      DiaryDateRange.any => null,
      DiaryDateRange.today => (today, tomorrow),
      DiaryDateRange.last7Days => (DateTime(now.year, now.month, now.day - 6), tomorrow),
      DiaryDateRange.last30Days => (DateTime(now.year, now.month, now.day - 29), tomorrow),
      DiaryDateRange.thisMonth => (DateTime(now.year, now.month), DateTime(now.year, now.month + 1)),
      DiaryDateRange.thisYear => (DateTime(now.year), DateTime(now.year + 1)),
    };
  }
}

/// Qué estados muestra el Diario.
enum DiaryStatusView {
  published(CieloStrings.statusPublished, ObservationStatus.published),
  drafts(CieloStrings.statusDrafts, ObservationStatus.draft),
  all(CieloStrings.statusAll, null);

  const DiaryStatusView(this.label, this.status);
  final String label;
  final ObservationStatus? status;
}

/// Criterios elegidos en la UI. Inmutable; se traduce a [ObservationFilter].
@immutable
class DiaryCriteria {
  const DiaryCriteria({
    this.query = '',
    this.dateRange = DiaryDateRange.any,
    this.category,
    this.place = '',
    this.statusView = DiaryStatusView.published,
  });

  final String query;
  final DiaryDateRange dateRange;
  final ObservationCategory? category;
  final String place;
  final DiaryStatusView statusView;

  /// Filtros distintos de la búsqueda de texto (para el contador del botón).
  int get activeFilterCount =>
      (dateRange != DiaryDateRange.any ? 1 : 0) +
      (category != null ? 1 : 0) +
      (place.trim().isNotEmpty ? 1 : 0) +
      (statusView != DiaryStatusView.published ? 1 : 0);

  /// `true` si algo reduce el resultado respecto al Diario completo.
  bool get isRefined => query.trim().isNotEmpty || activeFilterCount > 0;

  ObservationFilter toFilter(DateTime now) {
    final (DateTime, DateTime)? range = dateRange.resolve(now);
    return ObservationFilter(
      query: query.trim(),
      from: range?.$1,
      until: range?.$2,
      category: category,
      place: place.trim(),
      status: statusView.status,
    );
  }

  DiaryCriteria copyWith({
    String? query,
    DiaryDateRange? dateRange,
    ObservationCategory? Function()? category,
    String? place,
    DiaryStatusView? statusView,
  }) =>
      DiaryCriteria(
        query: query ?? this.query,
        dateRange: dateRange ?? this.dateRange,
        category: category == null ? this.category : category(),
        place: place ?? this.place,
        statusView: statusView ?? this.statusView,
      );

  /// Vuelve al Diario completo de observaciones publicadas, sin búsqueda.
  static const DiaryCriteria initial = DiaryCriteria();

  @override
  bool operator ==(Object other) =>
      other is DiaryCriteria &&
      other.query == query &&
      other.dateRange == dateRange &&
      other.category == category &&
      other.place == place &&
      other.statusView == statusView;

  @override
  int get hashCode => Object.hash(query, dateRange, category, place, statusView);
}
