import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cielo_rd/features/backup/data/strict_zip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cielord_zip_');
  });
  tearDown(() => directory.delete(recursive: true));

  Future<File> build(Map<String, List<int>> entries) async {
    final file = File('${directory.path}/a.zip');
    final writer = await StreamingZipWriter.create(file, DateTime.utc(2026));
    for (final entry in entries.entries) {
      await writer.addBytes(entry.key, entry.value);
    }
    await writer.finish();
    return file;
  }

  /// Modifica el encabezado del directorio central de la única entrada.
  Future<File> patch(File file, int offset, int value) async {
    final bytes = await file.readAsBytes();
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 46 < bytes.length; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        data.setUint32(i + offset, value, Endian.little);
        break;
      }
    }
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<StrictZipReader> open(File file) =>
      StrictZipReader.open(file, maxEntries: 10, maxTotalBytes: 1 << 30);

  Matcher rejected(String reason) =>
      throwsA(isA<ZipRejected>().having((e) => e.reason, 'reason', reason));

  test('CRC-32 de referencia', () {
    expect((Crc32()..add(ascii.encode('123456789'))).value, 0xcbf43926);
  });

  test('una bomba nunca escribe más de lo declarado', () async {
    final file = await build({'a': Uint8List(32 * 1024 * 1024)});
    expect(await file.length(), lessThan(100 * 1024));
    final zip = await open(await patch(file, 24, 1000));
    final output = File('${directory.path}/out');
    await expectLater(
      zip.verify('a', output: output),
      rejected('size_mismatch'),
    );
    expect(await output.length(), lessThanOrEqualTo(1000));
  });

  test('menos contenido del declarado también se rechaza', () async {
    final zip = await open(await patch(await build({'a': [1, 2, 3]}), 24, 4));
    await expectLater(zip.verify('a'), rejected('size_mismatch'));
  });

  test('CRC incorrecto', () async {
    final zip = await open(await patch(await build({'a': [1, 2, 3]}), 16, 7));
    await expectLater(zip.verify('a'), rejected('hash_mismatch'));
  });

  test('escritura por flujo: tamaño y hash de lo realmente escrito', () async {
    final source = File('${directory.path}/src')
      ..writeAsBytesSync(List.generate(200000, (i) => i % 251));
    final file = File('${directory.path}/b.zip');
    final writer = await StreamingZipWriter.create(file, DateTime.utc(2026));
    final written = await writer.addFile('media/x', source);
    await writer.finish();
    final zip = await open(file);
    final output = File('${directory.path}/out');
    final digest = await zip.verify('media/x', output: output);
    expect(digest.sha256, written.sha256);
    expect(await output.readAsBytes(), await source.readAsBytes());
  });
}
