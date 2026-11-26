import 'package:cielo_rd/design/design.dart';
import 'package:cielo_rd/features/observations/presentation/form/observation_form_screen.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';
import '../observations/diary_fixtures.dart';

void main() {
  for (final CieloThemeVariant variant in CieloThemeVariant.values) {
    testWidgets('formulario accesible [${variant.name} · texto 200 %]', (
      WidgetTester tester,
    ) async {
      final InMemoryObservationRepository store =
          InMemoryObservationRepository();

      await pumpCielo(
        tester,
        ObservationFormScreen(service: store, drafts: store, clock: () => kNow),
        variant: variant,
        textScale: 2,
        wrapInScaffold: false,
      );

      final Finder dateButton = find.widgetWithIcon(
        OutlinedButton,
        Icons.event_rounded,
      );
      await tester.scrollUntilVisible(
        dateButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }

  testWidgets('errores de publicación se anuncian y conservan el foco útil', (
    WidgetTester tester,
  ) async {
    final InMemoryObservationRepository store = InMemoryObservationRepository();

    await pumpCielo(
      tester,
      ObservationFormScreen(service: store, drafts: store, clock: () => kNow),
      wrapInScaffold: false,
    );
    await tester.tap(find.text(CieloStrings.publish));
    await tester.pumpAndSettle();

    expect(find.text(CieloStrings.fixErrors), findsOneWidget);
    expect(find.text(CieloStrings.fieldRequired), findsWidgets);
    expect(store.length, 0);
    expect(tester.takeException(), isNull);
  });
}
