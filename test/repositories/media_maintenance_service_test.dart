import 'dart:io';

import 'package:cielo_rd/core/database/app_database.dart';
import 'package:cielo_rd/core/domain/result.dart';
import 'package:cielo_rd/features/media/data/media_maintenance_service.dart';
import 'package:cielo_rd/features/media/domain/media_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temp;
  late Directory support;
  late AppDatabase database;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cielord_maintenance_');
    support = Directory('${temp.path}/support');
    await support.create();
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${temp.path}/db.sqlite',
    );
  });
  tearDown(() async {
    await database.close();
    await temp.delete(recursive: true);
  });

  Future<File> managed(String relative) async {
    final file = File(
      '${support.path}/${relative.replaceAll('/', Platform.pathSeparator)}',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString('x');
    return file;
  }

  test('processes pending deletion and removes only managed orphans', () async {
    final kept = await managed('media/photos/kept.jpg');
    final keptThumb = await managed('media/thumbnails/kept.jpg');
    final pending = await managed('media/photos/pending.jpg');
    final orphan = await managed('media/audio/orphan.m4a');
    final partial = await managed('media/photos/interrupted.jpg.part');
    final outside = File('${temp.path}/shared.jpg');
    await outside.writeAsString('shared');
    final db = await database.open();
    await db.insert('media_files', {
      'id': 'kept',
      'relative_path': 'media/photos/kept.jpg',
      'mime_type': 'image/jpeg',
      'byte_size': 1,
      'created_at': 1,
    });
    await db.insert('pending_file_deletions', {
      'relative_path': 'media/photos/pending.jpg',
      'created_at': 1,
      'attempts': 0,
    });
    final service = MediaMaintenanceService(
      database: database,
      supportDirectory: () async => support,
    );
    final result = await service.run() as Success<MediaMaintenanceReport>;
    expect(result.value.deletedPending, 1);
    expect(result.value.deletedOrphans, 2);
    expect(await kept.exists(), isTrue);
    expect(await keptThumb.exists(), isTrue);
    expect(await pending.exists(), isFalse);
    expect(await orphan.exists(), isFalse);
    expect(await partial.exists(), isFalse);
    expect(await outside.exists(), isTrue);
    expect(await db.query('pending_file_deletions'), isEmpty);
  });
}
