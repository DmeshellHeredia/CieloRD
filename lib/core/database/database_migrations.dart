import 'package:sqflite/sqflite.dart';

import '../text/search_normalizer.dart';
import 'schema_v1.dart';
import 'schema_v2.dart';
import 'schema_v3.dart';
import 'schema_v4.dart';

/// Called only from sqflite's already-transactional version callbacks.
final class DatabaseMigrations {
  const DatabaseMigrations();
  static const currentVersion = 4;

  Future<void> migrate(Database db, int from, int to) async {
    if (from < 0 || to > currentVersion || from > to) {
      throw StateError('Unsupported database migration $from -> $to.');
    }
    if (from < 1 && to >= 1) {
      final batch = db.batch();
      for (final statement in schemaV1Statements) {
        batch.execute(statement);
      }
      await batch.commit(noResult: true);
    }
    if (from < 2 && to >= 2) {
      for (final statement in schemaV2Statements) {
        await db.execute(statement);
      }
      await _backfillSearchText(db);
    }
    if (from < 3 && to >= 3) {
      for (final statement in schemaV3Statements) {
        await db.execute(statement);
      }
    }
    if (from < 4 && to >= 4) {
      for (final statement in schemaV4Statements) {
        await db.execute(statement);
      }
    }
  }

  /// v2: calcula `search_text` y `place_search` de las filas ya existentes.
  Future<void> _backfillSearchText(Database db) async {
    final rows = await db.query(
      'observations',
      columns: ['id', 'title', 'description', 'place_name'],
    );
    final batch = db.batch();
    for (final row in rows) {
      final place = row['place_name'] as String?;
      batch.update(
        'observations',
        {
          'search_text': SearchNormalizer.document(
            title: row['title'] as String? ?? '',
            description: row['description'] as String?,
            place: place,
          ),
          'place_search': place == null
              ? null
              : SearchNormalizer.normalize(place),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await batch.commit(noResult: true);
  }
}
