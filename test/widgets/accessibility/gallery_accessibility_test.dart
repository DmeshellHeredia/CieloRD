import 'package:cielo_rd/design/design.dart';
import 'package:cielo_rd/features/design_gallery/presentation/design_gallery_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';

/// Recorre la galería completa (todos los componentes) en cada tema y escala
/// de texto, comprobando en cada pantalla:
/// * guías de Flutter: área táctil Android (48 dp), etiquetas y contraste;
/// * ausencia de desbordes o excepciones de diseño.
void main() {
  for (final CieloThemeVariant variant in CieloThemeVariant.values) {
    for (final double scale in kTextScales) {
      testWidgets('galería accesible [${variant.name} · texto ${(scale * 100).round()} %]',
          (WidgetTester tester) async {
        final handle = tester.ensureSemantics();
        tester.view
          ..physicalSize = kPhoneSize * 3
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(DesignGalleryApp(initialVariant: variant, initialTextScale: scale));
        await tester.pump();

        final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
        int screens = 0;
        while (true) {
          screens++;
          expect(tester.takeException(), isNull, reason: 'pantalla $screens');
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));

          final ScrollPosition position = scrollable.position;
          if (position.pixels >= position.maxScrollExtent) break;
          position.jumpTo((position.pixels + 480).clamp(0, position.maxScrollExtent));
          await tester.pump();
        }
        expect(screens, greaterThan(5));
        handle.dispose();
      });
    }
  }
}
