import 'package:cielo_rd/design/design.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:cielo_rd/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';

void main() {
  group('CieloEmptyState', () {
    testWidgets('muestra título, mensaje y acción', (WidgetTester tester) async {
      int taps = 0;
      await pumpCielo(
        tester,
        CieloEmptyState(
          title: CieloStrings.emptyDiaryTitle,
          message: CieloStrings.emptyDiaryMessage,
          actionLabel: CieloStrings.emptyDiaryAction,
          onAction: () => taps++,
        ),
        scrollable: false,
      );
      expect(find.text(CieloStrings.emptyDiaryTitle), findsOneWidget);
      expect(find.text(CieloStrings.emptyDiaryMessage), findsOneWidget);
      await tester.tap(find.text(CieloStrings.emptyDiaryAction));
      expect(taps, 1);
    });

    testWidgets('el título es encabezado para TalkBack', (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      await pumpCielo(
        tester,
        const CieloEmptyState(title: CieloStrings.noDraftsTitle, message: CieloStrings.noDraftsMessage),
        scrollable: false,
      );
      expect(
        tester.getSemantics(find.text(CieloStrings.noDraftsTitle)),
        isSemantics(isHeader: true),
      );
      handle.dispose();
    });

    forEachThemeAndScale('cabe sin desbordar en un área limitada', (WidgetTester t, CieloThemeVariant v, double s) async {
      await pumpCielo(
        t,
        SizedBox(
          height: 360,
          child: CieloEmptyState(
            title: CieloStrings.emptyDiaryTitle,
            message: CieloStrings.emptyDiaryMessage,
            actionLabel: CieloStrings.emptyDiaryAction,
            onAction: () {},
          ),
        ),
        variant: v,
        textScale: s,
        scrollable: false,
      );
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('CieloErrorState ofrece reintentar y se anuncia', (WidgetTester tester) async {
    int retries = 0;
    final handle = tester.ensureSemantics();
    await pumpCielo(
      tester,
      CieloErrorState(message: CieloStrings.errorLoadObservations, onRetry: () => retries++),
      scrollable: false,
    );
    expect(find.text(CieloStrings.errorTitle), findsOneWidget);
    await tester.tap(find.text(CieloStrings.retry));
    expect(retries, 1);
    expect(
      find.byWidgetPredicate((Widget w) => w is Semantics && (w.properties.liveRegion ?? false)),
      findsWidgets,
    );
    handle.dispose();
  });

  group('CieloBanner', () {
    testWidgets('acciones y cierre', (WidgetTester tester) async {
      final List<String> calls = <String>[];
      await pumpCielo(
        tester,
        CieloBanner(
          tone: CieloTone.warning,
          message: CieloStrings.errorLocationDenied,
          actionLabel: CieloStrings.writePlace,
          onAction: () => calls.add('write'),
          secondaryActionLabel: CieloStrings.openSettings,
          onSecondaryAction: () => calls.add('settings'),
          onDismiss: () => calls.add('dismiss'),
        ),
      );
      await tester.tap(find.text(CieloStrings.writePlace));
      await tester.tap(find.text(CieloStrings.openSettings));
      await tester.tap(find.byTooltip(CieloStrings.close));
      expect(calls, <String>['write', 'settings', 'dismiss']);
    });

    testWidgets('es región viva para TalkBack', (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      await pumpCielo(tester, const CieloBanner(message: CieloStrings.errorGpsOff));
      expect(
        tester.getSemantics(find.byType(CieloBanner)),
        isSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });

    test('cada tono tiene contraste de texto suficiente en los tres temas', () {
      for (final CieloThemeVariant v in CieloThemeVariant.values) {
        for (final CieloTone tone in CieloTone.values) {
          final CieloToneColors colors = CieloToneColors.of(tone, CieloColors.forVariant(v));
          expect(
            contrastRatio(colors.foreground, colors.background),
            greaterThanOrEqualTo(CieloContrast.text),
            reason: '${v.name}/${tone.name}',
          );
        }
      }
    });
  });

  testWidgets('CieloBadge muestra icono y texto', (WidgetTester tester) async {
    await pumpCielo(
      tester,
      const CieloBadge(label: CieloStrings.draft, tone: CieloTone.warning, icon: Icons.edit_note_rounded),
    );
    expect(find.text(CieloStrings.draft), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
  });

  group('CieloSkeletonList', () {
    testWidgets('anima con movimiento normal', (WidgetTester tester) async {
      await pumpCielo(tester, const CieloSkeletonList());
      expect(tester.hasRunningAnimations, isTrue);
      expect(find.bySemanticsLabel(CieloStrings.loadingObservations), findsOneWidget);
    });

    testWidgets('queda estática con movimiento reducido', (WidgetTester tester) async {
      await pumpCielo(tester, const CieloSkeletonList(), disableAnimations: true);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('los glifos se pintan en todos los tamaños sin errores', (WidgetTester tester) async {
    await pumpCielo(
      tester,
      Wrap(
        children: <Widget>[
          for (final CieloGlyph g in CieloGlyph.values)
            for (final double size in <double>[16, 24, 48, 192]) CieloGlyphIcon(g, size: size),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(CieloGlyphIcon), findsNWidgets(CieloGlyph.values.length * 4));
  });

  testWidgets('CieloBrandLockup usa la matrícula académica por defecto', (WidgetTester tester) async {
    await pumpCielo(tester, const CieloBrandLockup());
    expect(find.text(CieloStrings.appName), findsOneWidget);
    expect(find.text('2024-0063'), findsOneWidget);
    // Valor ficticio de prueba, claramente no es una matrícula real.
    await pumpCielo(tester, const CieloBrandLockup(studentId: 'PRUEBA-0000'));
    expect(find.text('PRUEBA-0000'), findsOneWidget);
    expect(find.text('2024-0063'), findsNothing);
  });
}
