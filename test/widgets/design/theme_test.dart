import 'package:cielo_rd/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Noche es el tema predeterminado', () {
    expect(CieloTheme.defaultVariant, CieloThemeVariant.night);
  });

  for (final CieloThemeVariant variant in CieloThemeVariant.values) {
    group('Tema ${variant.name}', () {
      final ThemeData theme = CieloTheme.build(variant);

      test('incluye CieloColors de la misma variante', () {
        final CieloColors? colors = theme.extension<CieloColors>();
        expect(colors, isNotNull);
        expect(colors!.variant, variant);
        expect(theme.colorScheme.primary, colors.primary);
        expect(theme.scaffoldBackgroundColor, colors.background);
      });

      test('brillo coherente con la variante', () {
        expect(theme.brightness, variant.isDark ? Brightness.dark : Brightness.light);
        expect(theme.colorScheme.brightness, theme.brightness);
      });

      test('botones con alto mínimo de 48 dp y áreas táctiles amplias', () {
        expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
        for (final ButtonStyle? style in <ButtonStyle?>[
          theme.filledButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.textButtonTheme.style,
          theme.elevatedButtonTheme.style,
          theme.iconButtonTheme.style,
        ]) {
          final Size? min = style?.minimumSize?.resolve(<WidgetState>{});
          expect(min, isNotNull);
          expect(min!.height, greaterThanOrEqualTo(CieloSize.minTouch));
        }
      });

      test('tipografía empaquetada: display Space Grotesk, cuerpo Atkinson', () {
        expect(theme.textTheme.headlineSmall?.fontFamily, CieloFonts.display);
        expect(theme.textTheme.bodyLarge?.fontFamily, CieloFonts.body);
        expect(theme.textTheme.bodyLarge!.fontSize, greaterThanOrEqualTo(17));
        expect(theme.textTheme.bodyMedium!.fontSize, greaterThanOrEqualTo(15));
      });

      test('snackbar nunca es un bloque claro en temas oscuros', () {
        final Color bg = theme.snackBarTheme.backgroundColor!;
        if (variant.isDark) {
          expect(bg.computeLuminance(), lessThan(0.1));
        }
        expect(
          contrastRatio(theme.snackBarTheme.contentTextStyle!.color!, bg),
          greaterThanOrEqualTo(CieloContrast.text),
        );
      });
    });
  }

  test('lerp entre variantes conserva tokens válidos', () {
    final CieloColors mid = CieloColors.night.lerp(CieloColors.day, 0.5);
    expect(mid.variant, CieloThemeVariant.day);
    expect(CieloColors.night.lerp(CieloColors.day, 0).background, CieloColors.night.background);
    expect(CieloColors.night.lerp(null, 0.5), same(CieloColors.night));
  });

  test('copyWith reemplaza solo lo indicado', () {
    final CieloColors c = CieloColors.night.copyWith(accent: const Color(0xFF123456));
    expect(c.accent, const Color(0xFF123456));
    expect(c.primary, CieloColors.night.primary);
  });

  testWidgets('CieloMotion.resolve respeta movimiento reducido', (WidgetTester tester) async {
    late Duration normal;
    late Duration reduced;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(builder: (BuildContext context) {
          normal = CieloMotion.resolve(context, CieloMotion.normal);
          return MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(builder: (BuildContext context) {
              reduced = CieloMotion.resolve(context, CieloMotion.normal);
              return const SizedBox();
            }),
          );
        }),
      ),
    );
    expect(normal, CieloMotion.normal);
    expect(reduced, Duration.zero);
  });
}
