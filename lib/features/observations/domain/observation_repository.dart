import '../../../core/domain/result.dart';
import 'observation.dart';
import 'observation_filter.dart';

/// Read boundary. Mutations belong to ObservationService/DraftService.
abstract interface class ObservationRepository {
  /// limit must be 1..100; invalid cursor/filter => validation Failure.
  Future<Result<ObservationPage>> list({
    required ObservationFilter filter,
    String? cursor,
    int limit = 30,
  });

  /// Missing ID => Failure(notFound), never Success(null).
  Future<Result<Observation>> getById(String id);

  /// C1: exact number of observations matching [filter] (same semantics as
  /// [list], without pagination). Lets the UI show "14 observaciones" and the
  /// pending-drafts count without reading every page.
  Future<Result<int>> count({required ObservationFilter filter});
}
