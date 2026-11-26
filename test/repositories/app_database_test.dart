import 'dart:io';

import 'package:cielo_rd/core/database/app_database.dart';
import 'package:cielo_rd/core/database/database_migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late AppDatabase store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cielord_c0_');
    store = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/test.db',
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });
  Map<String, Object?> observation(String id, {String status = 'draft'}) => {
    'id': id,
    'status': status,
    'title': '',
    'created_at': 1,
    'updated_at': 1,
    'revision': 1,
  };

  test(
    'v1 creates six tables and enables foreign keys on every open',
    () async {
      final db = await store.open();
      expect(await db.getVersion(), DatabaseMigrations.currentVersion);
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      expect(
        tables.map((r) => r['name']),
        containsAll([
          'observations',
          'media_files',
          'observation_media',
          'observer_profile',
          'app_settings',
          'pending_file_deletions',
        ]),
      );
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      await store.close();
      final reopened = await store.open();
      expect(
        (await reopened.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
    },
  );
  test(
    'concurrent opens share one connection and data survives reinstantiation',
    () async {
      final connections = await Future.wait([store.open(), store.open()]);
      expect(identical(connections[0], connections[1]), isTrue);
      await connections[0].insert('observations', observation('one'));
      await store.close();
      store = AppDatabase(
        factory: databaseFactoryFfi,
        path: '${directory.path}/test.db',
      );
      expect(
        (await (await store.open()).query('observations')).single['id'],
        'one',
      );
    },
  );
  test(
    'schema rejects invalid publication and negative optional duration',
    () async {
      final db = await store.open();
      await expectLater(
        db.insert('observations', observation('bad', status: 'published')),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.insert('observations', {
          ...observation('negative'),
          'duration_seconds': -1,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await db.insert('observations', {
        ...observation('good', status: 'published'),
        'title': 'Luna',
        'observed_at_utc_ms': 1000,
        'utc_offset_minutes': -240,
        'category_code': 'astronomy',
      });
      expect(
        (await db.query('observations')).single['duration_seconds'],
        isNull,
      );
    },
  );
  test(
    'foreign keys prevent orphans and cascade only observation links',
    () async {
      final db = await store.open();
      await db.insert('media_files', {
        'id': 'photo',
        'relative_path': 'media/photo.jpg',
        'mime_type': 'image/jpeg',
        'byte_size': 10,
        'created_at': 1,
      });
      await expectLater(
        db.insert('observation_media', {
          'observation_id': 'missing',
          'media_id': 'photo',
          'kind': 'photo',
          'sort_order': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await db.insert('observations', observation('one'));
      await db.insert('observation_media', {
        'observation_id': 'one',
        'media_id': 'photo',
        'kind': 'photo',
        'sort_order': 0,
      });
      await db.delete('observations', where: 'id = ?', whereArgs: ['one']);
      expect(await db.query('observation_media'), isEmpty);
      expect(await db.query('media_files'), hasLength(1));
    },
  );
  test('transaction failure rolls back earlier writes', () async {
    final db = await store.open();
    await expectLater(
      db.transaction((txn) async {
        await txn.insert('observations', observation('rolled-back'));
        await txn.insert(
          'observations',
          observation('invalid', status: 'other'),
        );
      }),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.query('observations'), isEmpty);
  });
  test('failed initial migration rolls back its earlier DDL', () async {
    final raw = await databaseFactoryFfi.openDatabase(
      '${directory.path}/test.db',
    );
    await raw.execute('CREATE TABLE media_files (legacy_value TEXT)');
    await raw.insert('media_files', {'legacy_value': 'preserve'});
    await raw.close();
    await expectLater(store.open(), throwsA(isA<DatabaseException>()));
    final inspection = await databaseFactoryFfi.openDatabase(
      '${directory.path}/test.db',
    );
    expect(await inspection.getVersion(), 0);
    expect(
      (await inspection.query('media_files')).single['legacy_value'],
      'preserve',
    );
    expect(
      await inspection.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'observations'",
      ),
      isEmpty,
    );
    await inspection.close();
  });
  test('future schema is refused without destroying data', () async {
    final db = await store.open();
    await db.insert('observations', observation('keep'));
    await db.setVersion(DatabaseMigrations.currentVersion + 1);
    await store.close();
    await expectLater(store.open(), throwsA(anything));
    final raw = await databaseFactoryFfi.openDatabase(
      '${directory.path}/test.db',
    );
    expect(await raw.getVersion(), DatabaseMigrations.currentVersion + 1);
    expect((await raw.query('observations')).single['id'], 'keep');
    await raw.close();
  });
}
