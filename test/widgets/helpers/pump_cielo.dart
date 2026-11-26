import 'package:cielo_rd/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tamaño lógico de un teléfono Android de referencia (360 × 780 dp).
const Size kPhoneSize = Size(360, 780);

/// Escalas de texto verificadas: normal, grande y máxima de accesibilidad.
const List<double> kTextScales = <double>[1.0, 1.3, 2.0];

/// Monta [child] con el tema de CieloRD, escala de texto y tamaño de
/// teléfono indicados. Envuelve en `Scaffold` + scroll por defecto.
Future<void> pumpCielo(
  WidgetTester tester,
  Widget child, {
  CieloThemeVariant variant = CieloThemeVariant.night,
  double textScale = 1.0,
  bool disableAnimations = false,
  Size size = kPhoneSize,
  bool scrollable = true,
  bool wrapInScaffold = true,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  Widget body = child;
  if (wrapInScaffold) {
    body = Scaffold(
      body: SafeArea(
        child: scrollable
            ? SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)
            : Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: CieloTheme.build(variant),
      themeAnimationDuration: Duration.zero,
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: body,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Ejecuta [body] para cada combinación tema × escala de texto.
void forEachThemeAndScale(
  String description,
  Future<void> Function(WidgetTester tester, CieloThemeVariant variant, double scale) body, {
  List<double> scales = kTextScales,
}) {
  for (final CieloThemeVariant variant in CieloThemeVariant.values) {
    for (final double scale in scales) {
      testWidgets('$description [${variant.name} · texto ${(scale * 100).round()} %]',
          (WidgetTester tester) => body(tester, variant, scale));
    }
  }
}
