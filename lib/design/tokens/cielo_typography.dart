import 'dart:ui' show FontFeature, FontVariation;

import 'package:flutter/material.dart' show FontWeight, TextStyle, TextTheme;

/// Familias tipográficas empaquetadas en `assets/fonts/` (licencia OFL 1.1).
///
/// Hasta que Codex las registre en `pubspec.yaml`, Flutter usará la fuente
/// del sistema como respaldo sin errores; los tamaños y pesos se mantienen.
abstract final class CieloFonts {
  /// Títulos y cifras: geometría técnica con carácter propio.
  static const String display = 'SpaceGrotesk';

  /// Texto e interfaz: diseñada para máxima legibilidad con baja visión,
  /// útil con poca luz y brillo reducido.
  static const String body = 'AtkinsonHyperlegible';
}

/// Escala tipográfica de CieloRD mapeada a los roles de Material 3.
///
/// Cuerpo mínimo de 15 sp y texto de campo de 17 sp para lectura en exteriores.
abstract final class CieloTypography {
  static TextStyle _display(double size, double lineHeight, double weight,
          {double letterSpacing = -0.2}) =>
      TextStyle(
        fontFamily: CieloFonts.display,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
        fontVariations: <FontVariation>[FontVariation('wght', weight)],
        letterSpacing: letterSpacing,
      );

  static TextStyle _body(double size, double lineHeight, FontWeight weight,
          {double letterSpacing = 0.1}) =>
      TextStyle(
        fontFamily: CieloFonts.body,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      );

  /// Tema de texto sin color: `ThemeData` lo combina con el `ColorScheme`.
  static TextTheme textTheme() => TextTheme(
        displayLarge: _display(44, 52, 700, letterSpacing: -0.8),
        displayMedium: _display(36, 44, 700, letterSpacing: -0.6),
        displaySmall: _display(30, 38, 600, letterSpacing: -0.4),
        headlineLarge: _display(28, 36, 600, letterSpacing: -0.3),
        headlineMedium: _display(24, 32, 600),
        headlineSmall: _display(21, 28, 600),
        titleLarge: _body(20, 28, FontWeight.w700, letterSpacing: 0),
        titleMedium: _body(17, 24, FontWeight.w700, letterSpacing: 0),
        titleSmall: _body(15, 22, FontWeight.w700),
        bodyLarge: _body(17, 26, FontWeight.w400),
        bodyMedium: _body(15, 22, FontWeight.w400),
        bodySmall: _body(13, 18, FontWeight.w400, letterSpacing: 0.2),
        labelLarge: _body(16, 20, FontWeight.w700, letterSpacing: 0.2),
        labelMedium: _body(14, 18, FontWeight.w700, letterSpacing: 0.2),
        labelSmall: _body(12, 16, FontWeight.w700, letterSpacing: 0.3),
      );

  /// Cifras de ancho fijo para horas, duraciones y coordenadas,
  /// sin recurrir a una fuente monoespaciada.
  static TextStyle tabular(TextStyle style) => style.copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );
}
