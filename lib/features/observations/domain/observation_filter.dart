import 'observation.dart';
import 'observation_types.dart';

/// AND semantics. [from] inclusive, [until] exclusive. Null status means both.
/// Sort: observedAt DESC (null last), then id DESC. Search is case/accent folded.
final class ObservationFilter {
  ObservationFilter({
    this.query = '',
    DateTime? from,
    DateTime? until,
    this.category,
    this.place = '',
    this.status = ObservationStatus.published,
  }) : from = from?.toUtc(),
       until = until?.toUtc() {
    if (this.from != null &&
        this.until != null &&
        !this.until!.isAfter(this.from!)) {
      throw ArgumentError('until must be after from.');
    }
  }
  final String query;
  final DateTime? from;
  final DateTime? until;
  final ObservationCategory? category;
  final String place;
  final ObservationStatus? status;
}

/// Opaque cursor: valid only for the filter and ordering that produced it.
final class ObservationPage {
  ObservationPage({required List<Observation> items, this.nextCursor})
    : items = List.unmodifiable(items);
  final List<Observation> items;
  final String? nextCursor;
}
