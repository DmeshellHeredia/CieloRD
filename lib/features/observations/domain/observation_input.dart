import 'observation_types.dart';

/// Incomplete values are intentional: a form and a draft may be incomplete.
/// Validate at the application boundary before committing either status.
final class ObservationInput {
  ObservationInput({
    this.title = '',
    DateTime? observedAt,
    this.utcOffsetMinutes,
    this.category,
    this.subtypeCode,
    this.skyCondition,
    this.description,
    this.durationSeconds,
    this.direction,
    this.elevationDegrees,
    this.location,
    List<ObservationMedia> media = const [],
  }) : observedAt = observedAt?.toUtc(),
       media = List.unmodifiable(media);
  final String title;
  final DateTime? observedAt;
  final int? utcOffsetMinutes;
  final ObservationCategory? category;

  /// Optional stable snake_case code; the subtype vocabulary is extensible.
  final String? subtypeCode;
  final SkyCondition? skyCondition;
  final String? description;
  final int? durationSeconds;
  final CardinalDirection? direction;
  final double? elevationDegrees;
  final ObservationLocation? location;
  final List<ObservationMedia> media;

  /// Nullable fields use callbacks: omit to retain; () => null to clear.
  ObservationInput copyWith({
    String? title,
    DateTime? Function()? observedAt,
    int? Function()? utcOffsetMinutes,
    ObservationCategory? Function()? category,
    String? Function()? subtypeCode,
    SkyCondition? Function()? skyCondition,
    String? Function()? description,
    int? Function()? durationSeconds,
    CardinalDirection? Function()? direction,
    double? Function()? elevationDegrees,
    ObservationLocation? Function()? location,
    List<ObservationMedia>? media,
  }) => ObservationInput(
    title: title ?? this.title,
    observedAt: observedAt == null ? this.observedAt : observedAt(),
    utcOffsetMinutes: utcOffsetMinutes == null
        ? this.utcOffsetMinutes
        : utcOffsetMinutes(),
    category: category == null ? this.category : category(),
    subtypeCode: subtypeCode == null ? this.subtypeCode : subtypeCode(),
    skyCondition: skyCondition == null ? this.skyCondition : skyCondition(),
    description: description == null ? this.description : description(),
    durationSeconds: durationSeconds == null
        ? this.durationSeconds
        : durationSeconds(),
    direction: direction == null ? this.direction : direction(),
    elevationDegrees: elevationDegrees == null
        ? this.elevationDegrees
        : elevationDegrees(),
    location: location == null ? this.location : location(),
    media: media ?? this.media,
  );
}
