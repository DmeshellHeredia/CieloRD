import 'dart:convert';
import 'dart:math' as math;

final class GeoCoordinate {
  const GeoCoordinate(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

final class ProjectedCoordinate {
  const ProjectedCoordinate(this.x, this.y);
  final double x;
  final double y;
}

final class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });
  final double south;
  final double west;
  final double north;
  final double east;
  bool contains(GeoCoordinate point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;
}

abstract final class WebMercator {
  static const double _maxLatitude = 85.05112878;

  static ProjectedCoordinate project(GeoCoordinate value) {
    final latitude = value.latitude.clamp(-_maxLatitude, _maxLatitude);
    final radians = latitude * math.pi / 180;
    return ProjectedCoordinate(
      (value.longitude + 180) / 360,
      (1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) / 2,
    );
  }

  static GeoCoordinate unproject(ProjectedCoordinate value) {
    final longitude = value.x * 360 - 180;
    final n = math.pi * (1 - 2 * value.y);
    final latitude =
        180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return GeoCoordinate(latitude, longitude);
  }
}

final class ProvincePolygon {
  ProvincePolygon(Iterable<Iterable<GeoCoordinate>> rings)
    : rings = List.unmodifiable(
        rings.map((ring) => List<GeoCoordinate>.unmodifiable(ring)),
      );
  final List<List<GeoCoordinate>> rings;
}

final class ProvinceBoundary {
  ProvinceBoundary({
    required this.name,
    required Iterable<ProvincePolygon> polygons,
  }) : polygons = List.unmodifiable(polygons);
  final String name;
  final List<ProvincePolygon> polygons;
}

final class OfflineProvinceMap {
  OfflineProvinceMap._(this.provinces, this.bounds);

  final List<ProvinceBoundary> provinces;
  final GeoBounds bounds;

  factory OfflineProvinceMap.parse(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?> ||
        decoded['type'] != 'FeatureCollection') {
      throw const FormatException('Expected a GeoJSON FeatureCollection.');
    }
    final rawFeatures = decoded['features'];
    if (rawFeatures is! List) {
      throw const FormatException('Missing GeoJSON features.');
    }
    final provinces = <ProvinceBoundary>[];
    var south = double.infinity;
    var west = double.infinity;
    var north = double.negativeInfinity;
    var east = double.negativeInfinity;

    List<GeoCoordinate> ring(Object? raw) {
      if (raw is! List) throw const FormatException('Invalid polygon ring.');
      return raw
          .map((pair) {
            if (pair is! List ||
                pair.length < 2 ||
                pair[0] is! num ||
                pair[1] is! num) {
              throw const FormatException('Invalid GeoJSON coordinate.');
            }
            final coordinate = GeoCoordinate(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
            south = math.min(south, coordinate.latitude);
            west = math.min(west, coordinate.longitude);
            north = math.max(north, coordinate.latitude);
            east = math.max(east, coordinate.longitude);
            return coordinate;
          })
          .toList(growable: false);
    }

    ProvincePolygon polygon(Object? raw) {
      if (raw is! List || raw.isEmpty) {
        throw const FormatException('Empty polygon.');
      }
      return ProvincePolygon(raw.map(ring));
    }

    for (final rawFeature in rawFeatures) {
      if (rawFeature is! Map) {
        throw const FormatException('Invalid GeoJSON feature.');
      }
      final properties = rawFeature['properties'];
      final geometry = rawFeature['geometry'];
      if (properties is! Map || geometry is! Map) {
        throw const FormatException('Incomplete GeoJSON feature.');
      }
      final name = properties['shapeName'];
      final type = geometry['type'];
      final coordinates = geometry['coordinates'];
      if (name is! String || name.trim().isEmpty) {
        throw const FormatException('Province without a name.');
      }
      final polygons = switch (type) {
        'Polygon' => <ProvincePolygon>[polygon(coordinates)],
        'MultiPolygon' when coordinates is List =>
          coordinates.map(polygon).toList(growable: false),
        _ => throw FormatException('Unsupported geometry: $type.'),
      };
      provinces.add(ProvinceBoundary(name: name, polygons: polygons));
    }
    if (provinces.isEmpty || !south.isFinite) {
      throw const FormatException('Empty boundary collection.');
    }
    return OfflineProvinceMap._(
      List.unmodifiable(provinces),
      GeoBounds(south: south, west: west, north: north, east: east),
    );
  }

  ProvinceBoundary? provinceAt(GeoCoordinate point) {
    if (!bounds.contains(point)) return null;
    for (final province in provinces) {
      for (final polygon in province.polygons) {
        if (polygon.rings.isEmpty || !_insideRing(point, polygon.rings.first)) {
          continue;
        }
        final insideHole = polygon.rings
            .skip(1)
            .any((ring) => _insideRing(point, ring));
        if (!insideHole) return province;
      }
    }
    return null;
  }

  static bool _insideRing(GeoCoordinate point, List<GeoCoordinate> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i];
      final b = ring[j];
      final crosses =
          (a.latitude > point.latitude) != (b.latitude > point.latitude);
      if (crosses) {
        final longitude =
            (b.longitude - a.longitude) *
                (point.latitude - a.latitude) /
                (b.latitude - a.latitude) +
            a.longitude;
        if (point.longitude < longitude) inside = !inside;
      }
    }
    return inside;
  }
}
