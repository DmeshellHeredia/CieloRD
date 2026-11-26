import 'package:cielo_rd/app/app_identity.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la identidad académica conserva los valores definitivos', () {
    expect(AppIdentity.firstName, 'Michael Dmeshell');
    expect(AppIdentity.lastName, 'Sanchez Heredia');
    expect(AppIdentity.fullName, 'Michael Dmeshell Sanchez Heredia');
    expect(AppIdentity.studentId, '2024-0063');
    expect(AppIdentity.motto, '«¡Quiero vivir!» — Nico Robin');
    expect(
      AppIdentity.profilePhotoAsset,
      'assets/profile/michael_heredia.webp',
    );
    expect(
      AppIdentity.profilePhotoJpegAsset,
      'assets/profile/michael_heredia_seed.jpg',
    );
    expect(
      AppIdentity.profilePhotoThumbnailAsset,
      'assets/profile/michael_heredia_seed_thumb.jpg',
    );
  });

  test('la foto definitiva está empaquetada como WebP decodificable', () async {
    final ByteData data = await rootBundle.load(AppIdentity.profilePhotoAsset);
    final Uint8List bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
    final decoded = image.decodeWebP(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, greaterThan(500));
    expect(decoded.height, greaterThan(500));
  });

  test('los derivados de siembra son JPEG válidos y compactos', () async {
    final ByteData fullData = await rootBundle.load(
      AppIdentity.profilePhotoJpegAsset,
    );
    final full = image.decodeJpg(
      fullData.buffer.asUint8List(
        fullData.offsetInBytes,
        fullData.lengthInBytes,
      ),
    );
    final ByteData thumbData = await rootBundle.load(
      AppIdentity.profilePhotoThumbnailAsset,
    );
    final thumb = image.decodeJpg(
      thumbData.buffer.asUint8List(
        thumbData.offsetInBytes,
        thumbData.lengthInBytes,
      ),
    );

    expect(full, isNotNull);
    expect(full!.width, 1152);
    expect(full.height, 1416);
    expect(thumb, isNotNull);
    expect(thumb!.width, 480);
    expect(thumb.height, 590);
  });
}
