import 'dart:io';

import 'package:cielo_rd/design/design.dart';
import 'package:cielo_rd/features/design_gallery/presentation/design_gallery_app.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Capturas de la galería con las fuentes reales, para revisión visual.
///
/// Solo se ejecuta bajo demanda, porque el render de texto varía entre
/// sistemas y no debe romper la suite normal:
///
/// ```
/// flutter test test/widgets/screenshots --update-goldens --dart-define=CIELO_SCREENSHOTS=true
/// ```
///
/// Las imágenes quedan en `test/widgets/screenshots/goldens/`.
const bool _enabled = bool.fromEnvironment('CIELO_SCREENSHOTS');

Future<ByteData> _read(String path) async {
  final Uint8List bytes = await File(path).readAsBytes();
  return ByteData.view(bytes.buffer);
}

String _materialFontsDir() {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) return '$root/bin/cache/artifacts/material_fonts';
  // flutter_tester vive en bin/cache/artifacts/engine/<plataforma>/.
  return '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
}

Future<void> _loadFonts() async {
  final String material = _materialFontsDir();
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

  for (final CieloThemeVariant variant in CieloThemeVariant.values) {
    testWidgets('capturas de la galería [${variant.name}]', (WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(412 * 2, 915 * 2)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(DesignGalleryApp(initialVariant: variant));
      await tester.pump();

      final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      int index = 1;
      while (true) {
        await expectLater(
          find.byType(DesignGalleryApp),
          matchesGoldenFile('goldens/${variant.name}_${index.toString().padLeft(2, '0')}.png'),
        );
        final ScrollPosition position = scrollable.position;
        if (position.pixels >= position.maxScrollExtent || index >= 12) break;
        position.jumpTo((position.pixels + 760).clamp(0, position.maxScrollExtent));
        await tester.pump();
        index++;
      }
    }, skip: !_enabled);
  }
}
