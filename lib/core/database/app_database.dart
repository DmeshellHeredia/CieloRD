import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_migrations.dart';

/// Infrastructure only. Keep one owner per database path in the composition root.
/// Widgets consume domain repositories and must never receive this handle.
final class AppDatabase {
  AppDatabase({required this.factory, required this.path});
  final DatabaseFactory factory;
  final String path;
  Future<Database>? _opening;
  Future<void>? _closing;

  static Future<AppDatabase> android() async => AppDatabase(
    factory: databaseFactory,
    path: p.join(await getDatabasesPath(), 'cielo_rd.db'),
  );

  Future<Database> open() {
    final closing = _closing;
    if (closing != null) return closing.then((_) => open());
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      const migrations = DatabaseMigrations();
      return await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) => migrations.migrate(db, 0, version),
          onUpgrade: migrations.migrate,
          onDowngrade: (db, oldVersion, newVersion) async {
            throw StateError(
              'Database $oldVersion is newer than supported $newVersion. No data was deleted.',
            );
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    final pending = _opening;
    if (pending == null) return Future.value();
    return _closing = _close(pending);
  }

  /// Cierra y elimina la base completa, con sus archivos auxiliares. Las
  /// aperturas concurrentes esperan y reciben una base nueva y vacía.
  /// Idempotente: si no hay archivo, no hace nada.
  Future<void> destroy() {
    final previous = _closing;
    return _closing = _destroy(previous);
  }

  Future<void> _destroy(Future<void>? previous) async {
    try {
      if (previous != null) {
        try {
          await previous;
        } on Object {
          // Un cierre fallido no impide eliminar el archivo.
        }
      }
      final pending = _opening;
      if (pending != null) {
        try {
          await (await pending).close();
        } on Object {
          // Base ilegible o ya cerrada: igualmente se elimina.
        }
      }
      await factory.deleteDatabase(path);
      for (final file in files) {
        if (await file.exists()) await file.delete();
      }
    } finally {
      _opening = null;
      _closing = null;
    }
  }

  /// Archivo principal y auxiliares que SQLite puede dejar en disco.
  List<File> get files => [
    for (final suffix in const ['', '-journal', '-wal', '-shm'])
      File('$path$suffix'),
  ];

  Future<void> _close(Future<Database> pending) async {
    try {
      final db = await pending;
      await db.close();
    } finally {
      _opening = null;
      _closing = null;
    }
  }
}
