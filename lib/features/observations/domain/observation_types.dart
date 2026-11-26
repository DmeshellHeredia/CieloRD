enum ObservationStatus { draft, published }

enum ObservationCategory { astronomy, atmospheric, birds, artificial, other }

enum SkyCondition {
  clear('clear'),
  partlyCloudy('partly_cloudy'),
  cloudy('cloudy'),
  mist('mist'),
  saharanDust('saharan_dust'),
  lightRain('light_rain'),
  other('other'),
  unknown('unknown');

  const SkyCondition(this.code);
  final String code;
}

enum CardinalDirection {
  north('n'),
  northEast('ne'),
  east('e'),
  southEast('se'),
  south('s'),
  southWest('sw'),
  west('w'),
  northWest('nw');

  const CardinalDirection(this.code);
  final String code;
}

enum LocationSource { text, manual, gps }

enum MediaKind { photo, audio }

final class ObservationLocation {
  const ObservationLocation({
    this.placeName,
    this.latitude,
    this.longitude,
    this.source,
    this.accuracyM,
    this.capturedAt,
  });
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final LocationSource? source;
  final double? accuracyM;

  /// UTC instant when a fresh GPS fix was obtained. Null for manual/text data
  /// and for legacy observations created before schema v3.
  final DateTime? capturedAt;
  bool get hasCoordinates => latitude != null && longitude != null;
}

/// An app-managed attachment (including a staged attachment before commit).
/// UI resolves its ID through MediaService; it never opens relativePath itself.
final class ObservationMedia {
  const ObservationMedia({
    required this.id,
    required this.kind,
    required this.relativePath,
    required this.mimeType,
    required this.byteSize,
    this.sha256,
    this.durationMs,
  });
  final String id;
  final MediaKind kind;
  final String relativePath;
  final String mimeType;
  final int byteSize;
  final String? sha256;
  final int? durationMs;
}
