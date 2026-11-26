import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final project = Directory.current;
  final res = Directory(
    '${project.path}${Platform.pathSeparator}android${Platform.pathSeparator}'
    'app${Platform.pathSeparator}src${Platform.pathSeparator}main'
    '${Platform.pathSeparator}res',
  );

  test('Android launcher resources provide adaptive and legacy icons', () {
    final adaptive = File(
      '${res.path}${Platform.pathSeparator}mipmap-anydpi-v26'
      '${Platform.pathSeparator}ic_launcher.xml',
    );
    final round = File(
      '${res.path}${Platform.pathSeparator}mipmap-anydpi-v26'
      '${Platform.pathSeparator}ic_launcher_round.xml',
    );

    expect(adaptive.existsSync(), isTrue);
    expect(round.existsSync(), isTrue);
    for (final file in <File>[adaptive, round]) {
      final xml = file.readAsStringSync();
      expect(xml, contains('<adaptive-icon'));
      expect(xml, contains('@color/ic_launcher_background'));
      expect(xml, contains('@mipmap/ic_launcher_foreground'));
      expect(xml, contains('@drawable/ic_launcher_monochrome'));
    }

    const expectedLegacySizes = <String, int>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final entry in expectedLegacySizes.entries) {
      final bytes = File(
        '${res.path}${Platform.pathSeparator}mipmap-${entry.key}'
        '${Platform.pathSeparator}ic_launcher.png',
      ).readAsBytesSync();
      final icon = img.decodePng(bytes);
      expect(icon, isNotNull, reason: 'mipmap-${entry.key} must be PNG');
      expect(icon!.width, entry.value);
      expect(icon.height, entry.value);

      final foreground = img.decodePng(
        File(
          '${res.path}${Platform.pathSeparator}mipmap-${entry.key}'
          '${Platform.pathSeparator}ic_launcher_foreground.png',
        ).readAsBytesSync(),
      );
      expect(foreground, isNotNull);
      expect(foreground!.width, (entry.value * 2.25).round());
      expect(foreground.height, (entry.value * 2.25).round());
    }
  });

  test('Android launch resources provide branded pre-31 and 31+ splash', () {
    for (final directory in <String>['drawable', 'drawable-v21']) {
      final launch = File(
        '${res.path}${Platform.pathSeparator}$directory'
        '${Platform.pathSeparator}launch_background.xml',
      ).readAsStringSync();
      expect(launch, contains('@color/splash_background'));
      expect(launch, contains('@mipmap/ic_launcher_foreground'));
    }

    for (final directory in <String>['values-v31', 'values-night-v31']) {
      final styles = File(
        '${res.path}${Platform.pathSeparator}$directory'
        '${Platform.pathSeparator}styles.xml',
      ).readAsStringSync();
      expect(styles, contains('android:windowSplashScreenBackground'));
      expect(styles, contains('android:windowSplashScreenAnimatedIcon'));
      expect(styles, contains('@drawable/splash_mark'));
    }
  });

  test('packaged Android resources never contain a student id placeholder', () {
    final files = res
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.xml'));
    for (final file in files) {
      expect(file.readAsStringSync(), isNot(contains('{{MATRICULA}}')));
    }
  });

  test('final branding sources include CieloRD and the exact student id', () {
    final branding = Directory(
      '${project.path}${Platform.pathSeparator}assets'
      '${Platform.pathSeparator}branding',
    );
    for (final name in <String>[
      'icon_foreground_final.svg',
      'icon_legacy_final.svg',
    ]) {
      final source = File(
        '${branding.path}${Platform.pathSeparator}$name',
      );
      expect(source.existsSync(), isTrue, reason: name);
      final svg = source.readAsStringSync();
      expect(svg, contains('CieloRD'));
      expect(svg, contains('2024-0063'));
      expect(svg, isNot(contains('{{MATRICULA}}')));
      expect(svg.toLowerCase(), isNot(contains('provisional')));
    }
    for (final obsolete in <String>[
      'icon_foreground_template.svg',
      'icon_foreground_provisional.svg',
      'icon_legacy_provisional.svg',
    ]) {
      expect(
        File(
          '${branding.path}${Platform.pathSeparator}$obsolete',
        ).existsSync(),
        isFalse,
        reason: 'la fuente obsoleta no debe sobrevivir: $obsolete',
      );
    }
  });

  test('adaptive foreground keeps the student-id band compact', () {
    final foreground = img.decodePng(
      File(
        '${res.path}${Platform.pathSeparator}mipmap-xxxhdpi'
        '${Platform.pathSeparator}ic_launcher_foreground.png',
      ).readAsBytesSync(),
    );
    expect(foreground, isNotNull);

    // The band ends at y=320 in the 432 px source. Everything well below it
    // must remain transparent so Android can mask the adaptive foreground.
    expect(foreground!.getPixel(216, 360).a, 0);
  });

  test('product strings contain no identity placeholders', () {
    final lib = Directory(
      '${project.path}${Platform.pathSeparator}lib',
    );
    const forbidden = <String>[
      '{{MATRICULA}}',
      'Matrícula pendiente',
      'Nombre pendiente',
      'Frase motivadora pendiente',
      'Foto pendiente',
    ];
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final value in forbidden) {
        expect(source, isNot(contains(value)), reason: file.path);
      }
    }
  });
}
