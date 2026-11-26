import '../../../core/domain/result.dart';
import 'observation.dart';
import 'observation_input.dart';
import 'observation_types.dart';

abstract interface class ObservationService {
  Future<Result<Observation>> create(
    ObservationInput input, {
    required ObservationStatus status,
  });
  Future<Result<Observation>> update(
    String id,
    ObservationInput input, {
    required ObservationStatus status,
    required int expectedRevision,
  });

  /// Logical deletion + durable file-cleanup queue; not a forensic erase.
  Future<Result<Unit>> delete(String id, {required int expectedRevision});
}

abstract interface class DraftService {
  /// id and expectedRevision must both be null (new) or both present (update).
  Future<Result<Observation>> save(
    ObservationInput input, {
    String? id,
    int? expectedRevision,
  });
  Future<Result<Observation>> publish(
    String id, {
    required int expectedRevision,
  });
}
