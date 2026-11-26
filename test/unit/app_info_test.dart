import 'dart:io';

import 'package:cielo_rd/app/app_info.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la versión visible coincide con pubspec.yaml', () {
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect('${AppInfo.version}+${AppInfo.build}', version);
  });

  test('los créditos del mapa coinciden con el archivo de atribución', () {
    final attribution = File('assets/maps/ATTRIBUTION.md').readAsStringSync();
    for (final fact in ['DOM-ADM1-93820187', 'Natural Earth', '2022']) {
      expect(attribution, contains(fact));
      expect(CieloStrings.aboutMapCredit, contains(fact));
    }
  });

  test('Android no respalda ni traspasa datos privados', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('@xml/data_extraction_rules'));
    expect(manifest, isNot(contains('android.permission.INTERNET')));
    expect(manifest, isNot(contains('EXTERNAL_STORAGE')));
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = rules.split('<$section>')[1].split('</$section>')[0];
      for (final domain in [
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
      ]) {
        expect(body, contains('<exclude domain="$domain" path="." />'));
      }
    }
  });
}
