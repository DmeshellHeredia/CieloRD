import 'dart:io';

import 'package:cielo_rd/design/design.dart';
import 'package:cielo_rd/features/observations/presentation/preview/diary_preview_app.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:cielo_rd/ui_kit/ui_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Capturas del Diario (U1) con fuentes reales, bajo demanda:
///
/// ```
/// flutter test test/widgets/screenshots --update-goldens --dart-define=CIELO_SCREENSHOTS=true
/// ```
const bool _enabled = bool.fromEnvironment('CIELO_SCREENSHOTS');

Future<ByteData> _read(String path) async => ByteData.view((await File(path).readAsBytes()).buffer);

Future<void> _loadFonts() async {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  final String material = root != null
      ? '$root/bin/cache/artifacts/material_fonts'
      : '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
  final Map<String, List<String>> families = <String, List<String>>{
    CieloFonts.body: <String>[
      'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
      'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
    ],
    CieloFonts.display: <String>['assets/fonts/SpaceGrotesk-Variable.ttf'],
    'MaterialIcons': <String>['$material/materialicons-regular.otf'],
    'Roboto': <String>['$material/roboto-regular.ttf', '$material/roboto-bold.ttf'],
  };
  for (final MapEntry<String, List<String>> family in families.entries) {
    final FontLoader loader = FontLoader(family.key);
    for (final String path in family.value) {
      if (File(path).existsSync()) loader.addFont(_read(path));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  final DateTime now = DateTime(2026, 11, 22, 21, 30);

  for (final CieloThemeVariant variant in CieloThemeVariant.values) {
    testWidgets('capturas del Diario [${variant.name}]', (WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(412 * 2, 915 * 2)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      Future<void> shot(String name) => expectLater(
            find.byType(DiaryPreviewApp),
            matchesGoldenFile('goldens/diary_${variant.name}_$name.png'),
          );

      await tester.pumpWidget(DiaryPreviewApp(initialVariant: variant, now: now, latency: Duration.zero));
      await tester.pump();
      await tester.pump();
      await shot('1_lista');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      await shot('2_desplazado');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CieloFilterButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CieloStrings.dateLast30));
      await tester.pumpAndSettle();
      await shot('3_filtros');

      await tester.tap(find.text(CieloStrings.showResults));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ObservationCard).first);
      await tester.pumpAndSettle();
      await shot('4_detalle');
    }, skip: !_enabled);
  }
}
