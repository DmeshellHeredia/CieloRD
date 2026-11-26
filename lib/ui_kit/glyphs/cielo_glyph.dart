import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Glifos propios de CieloRD, dibujados en código sobre una retícula de 24.
///
/// Son vectoriales, monocromos y toman el color del tema: funcionan sin
/// conexión, no requieren dependencias y se vuelven rojos en modo astrónomo.
enum CieloGlyph {
  /// Planeta anillado con un destello.
  astronomy,

  /// Nube con halo.
  atmospheric,

  /// Dos aves en vuelo.
  birds,

  /// Satélite con paneles solares.
  artificial,

  /// Círculo con puntos suspensivos.
  other,

  /// Marca de CieloRD: media luna sobre la cordillera Central.
  brandMark,
}

/// Muestra un [CieloGlyph] con el tamaño y color indicados.
///
/// Si [semanticLabel] es nulo, el glifo se considera decorativo y se excluye
/// del árbol de accesibilidad.
class CieloGlyphIcon extends StatelessWidget {
  const CieloGlyphIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final CieloGlyph glyph;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color resolved = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    final Widget paint = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: CieloGlyphPainter(glyph, resolved)),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: paint);
    return Semantics(label: semanticLabel, image: true, child: ExcludeSemantics(child: paint));
  }
}

/// Pintor público para reutilizar los glifos en marca, icono y splash.
class CieloGlyphPainter extends CustomPainter {
  const CieloGlyphPainter(this.glyph, this.color);

  final CieloGlyph glyph;
  final Color color;

  static const double _grid = 24;
  static const double _stroke = 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = math.min(size.width, size.height) / _grid;
    canvas.save();
    canvas.translate(
      (size.width - _grid * scale) / 2,
      (size.height - _grid * scale) / 2,
    );
    canvas.scale(scale);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    switch (glyph) {
      case CieloGlyph.astronomy:
        _astronomy(canvas, stroke, fill);
      case CieloGlyph.atmospheric:
        _atmospheric(canvas, stroke, fill);
      case CieloGlyph.birds:
        _birds(canvas, stroke);
      case CieloGlyph.artificial:
        _artificial(canvas, stroke, fill);
      case CieloGlyph.other:
        _other(canvas, stroke, fill);
      case CieloGlyph.brandMark:
        _brandMark(canvas, stroke, fill);
    }
    canvas.restore();
  }

  /// Destello de cuatro puntas centrado en [c].
  static Path sparkle(Offset c, double r) {
    final double k = r * 0.22;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
      ..close();
  }

  void _astronomy(Canvas canvas, Paint stroke, Paint fill) {
    const Offset center = Offset(11.5, 13);
    const double planet = 5.2;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.33);
    // El anillo pasa por detrás del planeta en su mitad superior.
    final Path hidden = Path.combine(
      PathOperation.intersect,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: planet + 1.4)),
      Path()..addRect(const Rect.fromLTRB(-12, -12, 12, 0)),
    );
    final Path visible = Path.combine(
      PathOperation.difference,
      Path()..addRect(const Rect.fromLTRB(-14, -14, 14, 14)),
      hidden,
    );
    canvas.clipPath(visible);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 20.5, height: 6.6), stroke);
    canvas.restore();
    canvas.drawCircle(center, planet, stroke);
    canvas.drawPath(sparkle(const Offset(19.6, 4.4), 2.8), fill);
  }

  static Path _cloud(double inflate) {
    Path circle(double x, double y, double r) =>
        Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r + inflate));
    Path p = Path.combine(PathOperation.union, circle(8.2, 15.2, 3.6), circle(12.6, 12.2, 4.6));
    p = Path.combine(PathOperation.union, p, circle(17, 15.4, 3.4));
    p = Path.combine(
      PathOperation.union,
      p,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(8.2 - inflate, 14.6 - inflate, 17 + inflate, 18.8 + inflate),
          Radius.circular(0.8 + inflate),
        )),
    );
    return p;
  }

  void _atmospheric(Canvas canvas, Paint stroke, Paint fill) {
    // Halo parcialmente oculto por la nube.
    canvas.save();
    canvas.clipPath(Path.combine(
      PathOperation.difference,
      Path()..addRect(const Rect.fromLTRB(0, 0, 24, 24)),
      _cloud(1.6),
    ));
    canvas.drawCircle(const Offset(15.2, 8.6), 5.6, stroke);
    canvas.drawCircle(const Offset(15.2, 8.6), 1.4, fill);
    canvas.restore();
    canvas.drawPath(_cloud(0), stroke);
  }

  void _birds(Canvas canvas, Paint stroke) {
    canvas.drawPath(
      Path()
        ..moveTo(2.4, 10.4)
        ..quadraticBezierTo(5.4, 6.2, 8.4, 10.4)
        ..quadraticBezierTo(11.4, 6.2, 14.4, 10.4),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(11.4, 17.2)
        ..quadraticBezierTo(13.7, 14, 16, 17.2)
        ..quadraticBezierTo(18.3, 14, 20.6, 17.2),
      stroke,
    );
  }

  void _artificial(Canvas canvas, Paint stroke, Paint fill) {
    canvas.save();
    canvas.translate(12, 12);
    canvas.rotate(-math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 4.6, height: 5.8), const Radius.circular(1)),
      stroke,
    );
    for (final double dir in <double>[-1, 1]) {
      final Rect panel = Rect.fromLTRB(
        dir < 0 ? -10.6 : 4.8,
        -2.3,
        dir < 0 ? -4.8 : 10.6,
        2.3,
      );
      canvas.drawRect(panel, stroke);
      canvas.drawLine(Offset(panel.center.dx, -2.3), Offset(panel.center.dx, 2.3), stroke);
      canvas.drawLine(Offset(2.3 * dir, 0), Offset(4.8 * dir, 0), stroke);
    }
    canvas.drawLine(const Offset(0, -2.9), const Offset(0, -5.2), stroke);
    canvas.drawCircle(const Offset(0, -6.4), 1.3, fill);
    canvas.restore();
  }

  void _other(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawCircle(const Offset(12, 12), 8.6, stroke);
    for (final double x in <double>[8, 12, 16]) {
      canvas.drawCircle(Offset(x, 12), 1.35, fill);
    }
  }

  void _brandMark(Canvas canvas, Paint stroke, Paint fill) {
    final Path crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: const Offset(9.6, 9.2), radius: 6.6)),
      Path()..addOval(Rect.fromCircle(center: const Offset(12.6, 7), radius: 5.6)),
    );
    canvas.drawPath(crescent, fill);
    // Silueta de la cordillera Central con el pico más alto a la derecha.
    canvas.drawPath(
      Path()
        ..moveTo(1.6, 21.2)
        ..lineTo(6.4, 16.4)
        ..lineTo(9.2, 18.6)
        ..lineTo(14.6, 12.2)
        ..lineTo(17.6, 15.6)
        ..lineTo(19.4, 14.2)
        ..lineTo(22.4, 21.2),
      stroke,
    );
    canvas.drawPath(sparkle(const Offset(19.2, 5), 2.5), fill);
  }

  @override
  bool shouldRepaint(CieloGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
