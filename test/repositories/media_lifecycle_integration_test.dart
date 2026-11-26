import 'dart:io';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/core/database/app_database.dart';
import 'package:cielo_rd/features/media/data/local_media_service.dart';
import 'package:cielo_rd/features/media/data/media_maintenance_service.dart';
import 'package:cielo_rd/features/observations/data/sqlite_observation_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('photo survives restart and observation deletion removes only managed copies', () async {
    final temp = await Directory.systemTemp.createTemp(
      'cielord_media_restart_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final support = Directory('${temp.path}/support')..createSync();
    final original = File('${temp.path}/gallery_original.png')
      ..writeAsBytesSync(image.encodePng(image.Image(width: 20, height: 12)));
    final external = File('${temp.path}/external_keep.txt')
      ..writeAsStringSync('keep');
    final path = '${temp.path}/cielo.db';
    var database = AppDatabase(factory: databaseFactoryFfi, path: path);
    var store = SqliteObservationStore(
      database: database,
      newId: () => 'observation-1',
    );
    var media = LocalMediaService(
      database: database,
      supportDirectory: () async => support,
      pick: (_) async => XFile(original.path),
      recover: () async => const [],
      newId: () => 'photo-1',
    );
    final attachment = (await media.pickPhoto(
      PhotoSource.gallery,
    ) as Success<ObservationMedia?>).value!;
    final created = (await store.create(
      ObservationInput(
        title: 'Persistente',
        observedAt: DateTime.utc(2026, 11, 23),
        utcOffsetMinutes: -240,
        category: ObservationCategory.astronomy,
        media: [attachment],
      ),
      status: ObservationStatus.published,
    ) as Success<Observation>).value;
    expect(await media.commitStaged([attachment.id]), isA<Success<Unit>>());
    final managedPath =
        (await media.resolveLocalPath(attachment.id) as Success<String>).value;
    expect(await File(managedPath).exists(), isTrue);
    await database.close();

    database = AppDatabase(factory: databaseFactoryFfi, path: path);
    store = SqliteObservationStore(database: database);
    media = LocalMediaService(
      database: database,
      supportDirectory: () async => support,
      recover: () async => const [],
    );
    addTearDown(database.close);
    expect(await media.resolveLocalPath(attachment.id), isA<Success<String>>());
    expect(
      await store.delete(created.id, expectedRevision: created.revision),
      isA<Success<Unit>>(),
    );
    final maintenance = MediaMaintenanceService(
      database: database,
      supportDirectory: () async => support,
    );
    expect(await maintenance.run(), isA<Success<MediaMaintenanceReport>>());
    expect(await File(managedPath).exists(), isFalse);
    expect(await original.exists(), isTrue);
    expect(await external.exists(), isTrue);
  });
}
