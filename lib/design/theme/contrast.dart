import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Relación de contraste WCAG 2.x entre dos colores opacos (1.0 a 21.0).
double contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Umbrales WCAG AA usados por CieloRD.
abstract final class CieloContrast {
  /// Texto normal.
  static const double text = 4.5;

  /// Bordes de controles, iconos y glifos informativos.
  static const double ui = 3.0;
}

/// `true` si el color solo usa el canal rojo (verde y azul en 0).
bool isRedOnly(Color color) => color.g == 0 && color.b == 0;
