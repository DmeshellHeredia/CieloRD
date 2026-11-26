import 'package:cielo_rd/design/design.dart';
import 'package:cielo_rd/features/observations/presentation/diary/diary_screen.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:cielo_rd/features/observations/presentation/preview/sample_observations.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:cielo_rd/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';
import '../observations/diary_fixtures.dart';

Future<void> _expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// Diario completo, panel de filtros y detalle en cada tema y escala de
/// texto: guías de Flutter (48 dp, etiquetas, contraste) y sin desbordes.
void main() {
  for (final CieloThemeVariant variant in CieloThemeVariant.values) {
    for (final double scale in kTextScales) {
      final String tag = '[${variant.name} · texto ${(scale * 100).round()} %]';

      testWidgets('Diario accesible $tag', (WidgetTester tester) async {
        await pumpCielo(
          tester,
          DiaryScreen(
            observations: InMemoryObservationRepository(observations: sampleObservations(now: kNow)),
            clock: () => kNow,
            onCreateObservation: (_) async => false,
          ),
          variant: variant,
          textScale: scale,
          wrapInScaffold: false,
        );
        await tester.pump();
        await tester.pump();

        final ScrollableState list = tester.state<ScrollableState>(
          find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
        );
        int screens = 0;
        while (true) {
          screens++;
          expect(tester.takeException(), isNull, reason: 'pantalla $screens');
          await _expectGuidelines(tester);
          final ScrollPosition p = list.position;
          if (p.pixels >= p.maxScrollExtent || screens > 30) break;
          p.jumpTo((p.pixels + 500).clamp(0, p.maxScrollExtent));
          await tester.pump();
          await tester.pump();
        }
        expect(screens, greaterThan(2));
      });

      testWidgets('Panel de filtros accesible $tag', (WidgetTester tester) async {
        await pumpCielo(
          tester,
          DiaryScreen(observations: InMemoryObservationRepository(), clock: () => kNow),
          variant: variant,
          textScale: scale,
          wrapInScaffold: false,
        );
        await tester.pump();
        await tester.tap(find.byType(CieloFilterButton));
        await tester.pumpAndSettle();
        expect(find.text(CieloStrings.showResults), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _expectGuidelines(tester);
      });

      testWidgets('Detalle accesible $tag', (WidgetTester tester) async {
        await pumpCielo(
          tester,
          DiaryScreen(
            observations: InMemoryObservationRepository(observations: sampleObservations(now: kNow)),
            clock: () => kNow,
          ),
          variant: variant,
          textScale: scale,
          wrapInScaffold: false,
        );
        await tester.pump();
        await tester.pump();
        // Con texto al 200 % la primera tarjeta queda bajo el pliegue.
        final Finder firstCard = find.text('Estación Espacial cruzando hacia el noreste');
        await tester.scrollUntilVisible(
          firstCard,
          200,
          scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(firstCard);
        await tester.pumpAndSettle();
        expect(find.text(CieloStrings.detailTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _expectGuidelines(tester);
      });
    }
  }
}
