import 'dart:io';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/core/database/app_database.dart';
import 'package:cielo_rd/features/media/data/local_media_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temp;
  late Directory support;
  late AppDatabase database;
  late File original;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cielord_media_');
    support = Directory('${temp.path}/support');
    await support.create();
    original = File('${temp.path}/shared.png');
    await original.writeAsBytes(
      img.encodePng(img.Image(width: 16, height: 12)),
    );
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${temp.path}/media.db',
    );
  });

  tearDown(() async {
    await database.close();
    await temp.delete(recursive: true);
  });

  test(
    'imports a private JPEG and thumbnail without deleting original',
    () async {
      final service = LocalMediaService(
        database: database,
        supportDirectory: () async => support,
        pick: (_) async => XFile(original.path, mimeType: 'image/png'),
        recover: () async => const [],
        newId: () => 'photo-1',
      );
      final result = await service.pickPhoto(
        PhotoSource.gallery,
      ) as Success<ObservationMedia?>;
      final media = result.value!;
      expect(media.id, 'photo-1');
      expect(media.kind, MediaKind.photo);
      expect(media.relativePath, 'media/photos/photo-1.jpg');
      expect(media.mimeType, 'image/jpeg');
      expect(media.sha256, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(await original.exists(), isTrue);
      expect(
        await File(
          (await service.resolveLocalPath(media.id) as Success<String>).value,
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          (await service.resolveThumbnailPath(
            media.id,
          ) as Success<String>).value,
        ).exists(),
        isTrue,
      );
    },
  );

  test('discard only removes staged app-owned files', () async {
    final service = LocalMediaService(
      database: database,
      supportDirectory: () async => support,
      pick: (_) async => XFile(original.path),
      recover: () async => const [],
      newId: () => 'photo-2',
    );
    final media = (await service.pickPhoto(
      PhotoSource.camera,
    ) as Success<ObservationMedia?>).value!;
    expect(await service.discardStaged(media.id), isA<Success<Unit>>());
    expect(await service.resolveLocalPath(media.id), isA<Failure<String>>());
    expect(await original.exists(), isTrue);
    expect(await service.discardStaged(media.id), isA<Failure<Unit>>());
  });
}
