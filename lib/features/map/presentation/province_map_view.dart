import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../domain/offline_province_map.dart';

final class OfflineMapMarker {
  const OfflineMapMarker({required this.id, required this.coordinate});
  final String id;
  final GeoCoordinate coordinate;
}

final class OfflineMapSelection {
  const OfflineMapSelection({required this.coordinate, required this.province});
  final GeoCoordinate coordinate;
  final ProvinceBoundary province;
}

class ProvinceMapView extends StatelessWidget {
  const ProvinceMapView({
    super.key,
    required this.map,
    this.markers = const [],
    this.selected,
    this.onSelected,
    this.onOutsideCoverage,
    this.height = 360,
  });

  final OfflineProvinceMap map;
  final List<OfflineMapMarker> markers;
  final GeoCoordinate? selected;
  final ValueChanged<OfflineMapSelection>? onSelected;
  final ValueChanged<GeoCoordinate>? onOutsideCoverage;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = CieloColors.of(context);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: CieloRadius.cardAll,
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final viewport = _MapViewport(map.bounds, canvasSize);
                  return ColoredBox(
                    color: colors.surface1,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 8,
                      boundaryMargin: const EdgeInsets.all(120),
                      child: GestureDetector(
                        key: const ValueKey<String>('province_map_surface'),
                        behavior: HitTestBehavior.opaque,
                        onTapUp: onSelected == null
                            ? null
                            : (details) {
                                final coordinate = viewport.coordinate(
                                  details.localPosition,
                                );
                                final province = map.provinceAt(coordinate);
                                if (province != null) {
                                  onSelected!(
                                    OfflineMapSelection(
                                      coordinate: coordinate,
                                      province: province,
                                    ),
                                  );
                                } else {
                                  onOutsideCoverage?.call(coordinate);
                                }
                              },
                        child: CustomPaint(
                          size: canvasSize,
                          painter: _ProvincePainter(
                            map: map,
                            viewport: viewport,
                            markers: markers,
                            selected: selected,
                            line: colors.outline,
                            marker: colors.accent,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Material(
                color: colors.surface1.withValues(alpha: 0.9),
                borderRadius: CieloRadius.chipAll,
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => const AlertDialog(
                      title: Text('Datos del mapa'),
                      content: Text(
                        'Límites ADM1: geoBoundaries / Natural Earth, '
                        'dominio público. Año de representación: 2022.',
                      ),
                    ),
                  ),
                  child: const Text('geoBoundaries · Natural Earth'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _MapViewport {
  _MapViewport(GeoBounds bounds, this.size)
    : northWest = WebMercator.project(GeoCoordinate(bounds.north, bounds.west)),
      southEast = WebMercator.project(GeoCoordinate(bounds.south, bounds.east));
  final Size size;
  final ProjectedCoordinate northWest;
  final ProjectedCoordinate southEast;
  static const double padding = 32;

  Offset offset(GeoCoordinate coordinate) {
    final p = WebMercator.project(coordinate);
    final width = size.width - padding * 2;
    final height = size.height - padding * 2;
    return Offset(
      padding + (p.x - northWest.x) / (southEast.x - northWest.x) * width,
      padding + (p.y - northWest.y) / (southEast.y - northWest.y) * height,
    );
  }

  GeoCoordinate coordinate(Offset offset) {
    final width = size.width - padding * 2;
    final height = size.height - padding * 2;
    return WebMercator.unproject(
      ProjectedCoordinate(
        northWest.x +
            (offset.dx - padding) / width * (southEast.x - northWest.x),
        northWest.y +
            (offset.dy - padding) / height * (southEast.y - northWest.y),
      ),
    );
  }
}

final class _ProvincePainter extends CustomPainter {
  const _ProvincePainter({
    required this.map,
    required this.viewport,
    required this.markers,
    required this.selected,
    required this.line,
    required this.marker,
  });
  final OfflineProvinceMap map;
  final _MapViewport viewport;
  final List<OfflineMapMarker> markers;
  final GeoCoordinate? selected;
  final Color line;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final province in map.provinces) {
      for (final polygon in province.polygons) {
        for (final ring in polygon.rings) {
          if (ring.length < 2) continue;
          var previous = viewport.offset(ring.first);
          for (final point in ring.skip(1)) {
            final current = viewport.offset(point);
            canvas.drawLine(previous, current, linePaint);
            previous = current;
          }
          canvas.drawLine(previous, viewport.offset(ring.first), linePaint);
        }
      }
    }
    final markerPaint = Paint()..color = marker;
    for (final item in markers) {
      final point = viewport.offset(item.coordinate);
      canvas.drawCircle(point, 6, markerPaint);
      canvas.drawCircle(point, 8, linePaint);
    }
    if (selected != null) {
      final point = viewport.offset(selected!);
      canvas.drawCircle(
        point,
        10,
        markerPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProvincePainter oldDelegate) =>
      oldDelegate.map != map ||
      oldDelegate.markers != markers ||
      oldDelegate.selected != selected ||
      oldDelegate.line != line ||
      oldDelegate.marker != marker;
}
