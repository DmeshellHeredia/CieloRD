import 'package:cielo_rd/design/design.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:cielo_rd/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';

ObservationCard _card({
  bool isDraft = false,
  VoidCallback? onTap,
  Widget? thumbnail,
  String title = 'Lluvia de Leónidas sobre Valle Nuevo',
}) =>
    ObservationCard(
      title: title,
      category: CategoryVisual.astronomy,
      whenLabel: 'mar 17 nov, 2:40 a. m.',
      placeLabel: 'Valle Nuevo, Constanza',
      isDraft: isDraft,
      photoCount: 3,
      audioCount: 1,
      location: ObservationCardLocation.gps,
      thumbnail: thumbnail,
      onTap: onTap,
    );

void main() {
  testWidgets('muestra título, fecha, lugar e insignias', (WidgetTester tester) async {
    await pumpCielo(tester, _card());
    expect(find.text('Lluvia de Leónidas sobre Valle Nuevo'), findsOneWidget);
    expect(find.text('mar 17 nov, 2:40 a. m.'), findsOneWidget);
    expect(find.text('Valle Nuevo, Constanza'), findsOneWidget);
    expect(find.text(CieloStrings.gpsLocation), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text(CieloStrings.draft), findsNothing);
  });

  testWidgets('borrador: insignia y borde ámbar', (WidgetTester tester) async {
    await pumpCielo(tester, _card(isDraft: true));
    expect(find.text(CieloStrings.draft), findsOneWidget);
    final Material material = tester.widget<Material>(
      find.descendant(of: find.byType(ObservationCard), matching: find.byType(Material)).first,
    );
    final RoundedRectangleBorder shape = material.shape! as RoundedRectangleBorder;
    expect(shape.side.color, CieloColors.night.accent);
  });

  testWidgets('TalkBack lee un resumen completo y puede activarla', (WidgetTester tester) async {
    int taps = 0;
    final handle = tester.ensureSemantics();
    await pumpCielo(tester, _card(isDraft: true, onTap: () => taps++));
    const String summary = 'Borrador. Lluvia de Leónidas sobre Valle Nuevo. Astronomía. '
        'mar 17 nov, 2:40 a. m. Valle Nuevo, Constanza. 3 fotos. 1 nota de voz';
    final Finder card = find.bySemanticsLabel(summary);
    expect(card, findsOneWidget);
    expect(tester.getSemantics(card), isSemantics(isButton: true, hasTapAction: true));
    await tester.tap(find.byType(ObservationCard));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('en modo astrónomo la miniatura pasa por el filtro rojo', (WidgetTester tester) async {
    await pumpCielo(
      tester,
      _card(thumbnail: const ColoredBox(color: Colors.blue)),
      variant: CieloThemeVariant.astro,
    );
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('en Noche la miniatura se muestra sin filtro', (WidgetTester tester) async {
    await pumpCielo(tester, _card(thumbnail: const ColoredBox(color: Colors.blue)));
    expect(find.byType(ColorFiltered), findsNothing);
  });

  forEachThemeAndScale('sin desbordes con títulos largos', (WidgetTester tester, CieloThemeVariant v, double s) async {
    await pumpCielo(
      tester,
      _card(
        isDraft: true,
        title: 'Paso de la Estación Espacial Internacional sobre la bahía de Samaná con cielo parcialmente nublado',
      ),
      variant: v,
      textScale: s,
    );
    expect(tester.takeException(), isNull);
  });
}
