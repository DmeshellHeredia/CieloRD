import 'package:cielo_rd/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contraste WCAG AA de los pares de color que la UI realmente usa.
void main() {
  for (final CieloThemeVariant variant in CieloThemeVariant.values) {
    final CieloColors c = CieloColors.forVariant(variant);

    group('Contraste ${variant.name}', () {
      final Map<String, (Color, Color)> textPairs = <String, (Color, Color)>{
        'textPrimary / background': (c.textPrimary, c.background),
        'textPrimary / surface1': (c.textPrimary, c.surface1),
        'textPrimary / surface2': (c.textPrimary, c.surface2),
        'textPrimary / surface3': (c.textPrimary, c.surface3),
        'textSecondary / background': (c.textSecondary, c.background),
        'textSecondary / surface1': (c.textSecondary, c.surface1),
        'textSecondary / surface2': (c.textSecondary, c.surface2),
        'onPrimary / primary': (c.onPrimary, c.primary),
        'onPrimaryContainer / primaryContainer': (c.onPrimaryContainer, c.primaryContainer),
        'onAccent / accent': (c.onAccent, c.accent),
        'onAccentContainer / accentContainer': (c.onAccentContainer, c.accentContainer),
        'onDanger / danger': (c.onDanger, c.danger),
        'onDangerContainer / dangerContainer': (c.onDangerContainer, c.dangerContainer),
        'primary / background (TextButton)': (c.primary, c.background),
        'primary / surface1 (TextButton)': (c.primary, c.surface1),
        'danger / background (error)': (c.danger, c.background),
        'danger / surface1 (error)': (c.danger, c.surface1),
        'accent / surface1 (matrícula pendiente)': (c.accent, c.surface1),
        'accent / background (matrícula pendiente)': (c.accent, c.background),
        'onFilled / filledBackground (botón relleno)': (c.onFilled, c.filledBackground),
        'onDangerFilled / dangerFilledBackground': (c.onDangerFilled, c.dangerFilledBackground),
      };

      final Map<String, (Color, Color)> uiPairs = <String, (Color, Color)>{
        'outlineStrong / background': (c.outlineStrong, c.background),
        'outlineStrong / surface1': (c.outlineStrong, c.surface1),
        'outlineStrong / surface2': (c.outlineStrong, c.surface2),
        'primary / surface2 (borde seleccionado)': (c.primary, c.surface2),
        'primary / primaryContainer (borde seleccionado)': (c.primary, c.primaryContainer),
        'accent / surface1 (borde de borrador)': (c.accent, c.surface1),
        'success / surface1': (c.success, c.surface1),
        'warning / surface1': (c.warning, c.surface1),
        'categoryAstronomy / surface2': (c.categoryAstronomy, c.surface2),
        'categoryAtmospheric / surface2': (c.categoryAtmospheric, c.surface2),
        'categoryBirds / surface2': (c.categoryBirds, c.surface2),
        'categoryArtificial / surface2': (c.categoryArtificial, c.surface2),
        'categoryOther / surface2': (c.categoryOther, c.surface2),
        'categoryAstronomy / surface1': (c.categoryAstronomy, c.surface1),
        'categoryOther / surface1': (c.categoryOther, c.surface1),
      };

      textPairs.forEach((String name, (Color, Color) pair) {
        test('texto $name ≥ 4.5:1', () {
          expect(contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(CieloContrast.text));
        });
      });

      uiPairs.forEach((String name, (Color, Color) pair) {
        test('control $name ≥ 3:1', () {
          expect(contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(CieloContrast.ui));
        });
      });
    });
  }

  test('contrastRatio coincide con valores WCAG de referencia', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(contrastRatio(const Color(0xFFFF0000), const Color(0xFF000000)), closeTo(5.25, 0.01));
    expect(contrastRatio(const Color(0xFF777777), const Color(0xFF777777)), 1);
  });

  group('Modo astrónomo exclusivamente rojo', () {
    final CieloColors astro = CieloColors.astro;
    final ThemeData theme = CieloTheme.astro();
    final ColorScheme s = theme.colorScheme;

    test('todos los tokens de CieloColors.astro', () {
      astro.tokens.forEach((String name, Color color) {
        expect(isRedOnly(color), isTrue, reason: '$name = $color');
      });
    });

    test('todos los colores del ColorScheme', () {
      final Map<String, Color> scheme = <String, Color>{
        'primary': s.primary, 'onPrimary': s.onPrimary, 'primaryContainer': s.primaryContainer,
        'onPrimaryContainer': s.onPrimaryContainer, 'primaryFixed': s.primaryFixed,
        'primaryFixedDim': s.primaryFixedDim, 'onPrimaryFixed': s.onPrimaryFixed,
        'onPrimaryFixedVariant': s.onPrimaryFixedVariant, 'secondary': s.secondary,
        'onSecondary': s.onSecondary, 'secondaryContainer': s.secondaryContainer,
        'onSecondaryContainer': s.onSecondaryContainer, 'secondaryFixed': s.secondaryFixed,
        'tertiary': s.tertiary, 'onTertiary': s.onTertiary, 'tertiaryContainer': s.tertiaryContainer,
        'onTertiaryContainer': s.onTertiaryContainer, 'error': s.error, 'onError': s.onError,
        'errorContainer': s.errorContainer, 'onErrorContainer': s.onErrorContainer,
        'surface': s.surface, 'onSurface': s.onSurface, 'surfaceDim': s.surfaceDim,
        'surfaceBright': s.surfaceBright, 'surfaceContainerLowest': s.surfaceContainerLowest,
        'surfaceContainerLow': s.surfaceContainerLow, 'surfaceContainer': s.surfaceContainer,
        'surfaceContainerHigh': s.surfaceContainerHigh,
        'surfaceContainerHighest': s.surfaceContainerHighest, 'onSurfaceVariant': s.onSurfaceVariant,
        'outline': s.outline, 'outlineVariant': s.outlineVariant, 'shadow': s.shadow, 'scrim': s.scrim,
        'inverseSurface': s.inverseSurface, 'onInverseSurface': s.onInverseSurface,
        'inversePrimary': s.inversePrimary, 'surfaceTint': s.surfaceTint,
      };
      scheme.forEach((String name, Color color) {
        expect(isRedOnly(color), isTrue, reason: 'ColorScheme.$name = $color');
      });
    });

    test('colores sueltos de ThemeData (sin grises ni azules por defecto)', () {
      final Map<String, Color> loose = <String, Color>{
        'scaffoldBackgroundColor': theme.scaffoldBackgroundColor,
        'canvasColor': theme.canvasColor,
        'cardColor': theme.cardColor,
        'dividerColor': theme.dividerColor,
        'disabledColor': theme.disabledColor,
        'hintColor': theme.hintColor,
        'focusColor': theme.focusColor,
        'hoverColor': theme.hoverColor,
        'highlightColor': theme.highlightColor,
        'splashColor': theme.splashColor,
        'unselectedWidgetColor': theme.unselectedWidgetColor,
        'shadowColor': theme.shadowColor,
        'primaryColor': theme.primaryColor,
        'primaryColorDark': theme.primaryColorDark,
        'primaryColorLight': theme.primaryColorLight,
        'secondaryHeaderColor': theme.secondaryHeaderColor,
        'iconTheme': theme.iconTheme.color!,
        'bodyLarge': theme.textTheme.bodyLarge!.color!,
        'headlineSmall': theme.textTheme.headlineSmall!.color!,
      };
      loose.forEach((String name, Color color) {
        expect(isRedOnly(color), isTrue, reason: 'ThemeData.$name = $color');
      });
    });

    test('los botones rellenos no son bloques rojos brillantes', () {
      expect(astro.filledBackground.computeLuminance(), lessThan(0.01));
      expect(astro.dangerFilledBackground.computeLuminance(), lessThan(0.01));
      expect(theme.filledButtonTheme.style!.backgroundColor!.resolve(<WidgetState>{}), astro.primaryContainer);
    });

    test('filtro de medios convierte a rojo monocromo', () {
      expect(astro.mediaFilter, isNotNull);
      expect(CieloColors.night.mediaFilter, isNull);
      expect(CieloColors.day.mediaFilter, isNull);
    });
  });
}
