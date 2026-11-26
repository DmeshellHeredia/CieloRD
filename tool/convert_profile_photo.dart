import 'dart:io';

import 'package:image/image.dart' as image;

Future<void> main() async {
  final source = File('assets/profile/foto.jpeg');
  final target = File('assets/profile/michael_heredia.webp');
  final jpegTarget = File('assets/profile/michael_heredia_seed.jpg');
  final thumbnailTarget = File('assets/profile/michael_heredia_seed_thumb.jpg');
  if (!await source.exists()) {
    stderr.writeln('No existe ${source.path}.');
    exitCode = 2;
    return;
  }
  final decoded = image.decodeImage(await source.readAsBytes());
  if (decoded == null) {
    stderr.writeln('La foto fuente no se pudo decodificar.');
    exitCode = 3;
    return;
  }
  final bytes = image.encodeWebP(
    decoded,
    lossless: false,
    quality: 88,
    method: 6,
  );
  await target.writeAsBytes(bytes, flush: true);
  final packaged = image.decodeWebP(bytes);
  if (packaged == null) {
    stderr.writeln('El WebP generado no se pudo verificar.');
    exitCode = 4;
    return;
  }
  final jpegBytes = image.encodeJpg(packaged, quality: 92);
  final thumbnail = image.copyResize(
    packaged,
    width: 480,
    interpolation: image.Interpolation.average,
  );
  final thumbnailBytes = image.encodeJpg(thumbnail, quality: 82);
  await jpegTarget.writeAsBytes(jpegBytes, flush: true);
  await thumbnailTarget.writeAsBytes(thumbnailBytes, flush: true);
  stdout.writeln(
    'WebP creado: ${target.path} (${decoded.width}x${decoded.height}, '
    '${bytes.length} bytes)',
  );
  stdout.writeln(
    'Derivados de siembra: ${jpegTarget.path} (${jpegBytes.length} bytes) '
    'y ${thumbnailTarget.path} (${thumbnail.width}x${thumbnail.height}, '
    '${thumbnailBytes.length} bytes)',
  );
}
