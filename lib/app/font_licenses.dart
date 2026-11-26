import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registra las licencias OFL de las fuentes empaquetadas para que aparezcan
/// en la página de licencias de la app (requisito de la SIL OFL 1.1).
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    const Map<String, String> fonts = <String, String>{
      'Atkinson Hyperlegible': 'assets/fonts/OFL-AtkinsonHyperlegible.txt',
      'Space Grotesk': 'assets/fonts/OFL-SpaceGrotesk.txt',
    };
    for (final MapEntry<String, String> font in fonts.entries) {
      yield LicenseEntryWithLineBreaks(<String>[
        font.key,
      ], await rootBundle.loadString(font.value));
    }
    yield LicenseEntryWithLineBreaks(
      const <String>['geoBoundaries / Natural Earth (mapa provincial)'],
      await rootBundle.loadString('assets/maps/ATTRIBUTION.md'),
    );
  });
}
