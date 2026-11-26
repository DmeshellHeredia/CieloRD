import 'package:flutter/widgets.dart';

/// Espaciado en múltiplos de 4. Usar siempre estos valores, nunca números
/// sueltos en los widgets.
abstract final class CieloSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Margen lateral de pantalla.
  static const double gutter = 16;
}

/// Radios por jerarquía: cuanto más grande el contenedor, más suave la curva.
abstract final class CieloRadius {
  static const double badge = 999;
  static const double chip = 12;
  static const double field = 14;
  static const double tile = 16;
  static const double card = 20;
  static const double sheet = 28;

  static const BorderRadius chipAll = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius fieldAll = BorderRadius.all(Radius.circular(field));
  static const BorderRadius tileAll = BorderRadius.all(Radius.circular(tile));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Tamaños mínimos y de iconografía.
abstract final class CieloSize {
  /// Mínimo de área táctil para cualquier control.
  static const double minTouch = 48;

  /// Controles que se usan en el campo (registro rápido, selección).
  static const double fieldTouch = 56;

  /// Acción principal del registro rápido.
  static const double heroTouch = 64;

  static const double iconSm = 18;
  static const double iconMd = 24;
  static const double iconLg = 32;

  /// Miniatura de tarjeta de observación.
  static const double thumbnail = 56;

  /// Ancho máximo de contenido de lectura.
  static const double maxContentWidth = 640;
}

/// Movimiento discreto. Toda animación debe pasar por [resolve] para respetar
/// la preferencia de movimiento reducido (`MediaQuery.disableAnimations`).
///
/// Para forzar movimiento reducido desde los ajustes de la app, basta con
/// envolver la app en un `MediaQuery` con `disableAnimations: true`.
abstract final class CieloMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);

  static const Curve standard = Curves.easeInOutCubicEmphasized;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  static bool isReduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);

  static Duration resolve(BuildContext context, Duration duration) =>
      isReduced(context) ? Duration.zero : duration;
}
