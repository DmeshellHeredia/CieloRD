import 'observation_input.dart';
import 'observation_types.dart';

final class Observation {
  Observation({
    required this.id,
    required this.status,
    required this.input,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.revision,
  }) : createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    if (id.trim().isEmpty ||
        revision < 1 ||
        this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError(
        'Invalid persisted observation identity, revision or timestamps.',
      );
    }
  }
  final String id;
  final ObservationStatus status;
  final ObservationInput input;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
}
