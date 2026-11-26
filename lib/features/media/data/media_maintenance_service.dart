// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/concurrency/write_gate.dart';
import '../../../core/database/app_database.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../domain/media_service.dart';

/// Reconciles only app-owned media directories. Lost picker data must be
/// recovered and attached before this service runs at startup.
final class MediaMaintenanceService implements MediaMaintenance {
  MediaMaintenanceService({
    required AppDatabase database,
    Future<Directory> Function()? supportDirectory,
    WriteGate? gate,
  }) : _gate = gate ?? WriteGate(),
       _database = database,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final AppDatabase _database;
  final Future<Directory> Function() _supportDirectory;
  final WriteGate _gate;

  @override
  Future<Result<MediaMaintenanceReport>> run() async {
    try {
      return await _gate.write(_run);
    } on WriteGateClosed {
      return Failure(AppFailure(FailureCode.busy));
    }
  }

  Future<Result<MediaMaintenanceReport>> _run() async {
    try {
      final db = await _database.open();
      final root = await _supportDirectory();
      var deletedPending = 0;
      var failedPending = 0;
      final pending = await db.query('pending_file_deletions');
      for (final row in pending) {
        final relative = row['relative_path']! as String;
        try {
          final file = _managedFile(root, relative);
          if (await file.exists()) await file.delete();
          await db.delete(
            'pending_file_deletions',
            where: 'relative_path = ?',
            whereArgs: [relative],
          );
          deletedPending++;
        } on Object catch (error) {
          failedPending++;
          await db.rawUpdate(
            'UPDATE pending_file_deletions SET attempts = attempts + 1, last_error = ? WHERE relative_path = ?',
            [error.toString(), relative],
          );
        }
      }

      final rows = await db.query(
        'media_files',
        columns: ['id', 'relative_path', 'mime_type'],
      );
      final keep = <String>{};
      for (final row in rows) {
        final relative = row['relative_path']! as String;
        keep.add(relative);
        if ((row['mime_type']! as String).startsWith('image/')) {
          keep.add('media/thumbnails/${row['id']}.jpg');
        }
      }

      var deletedOrphans = 0;
      for (final directory in const [
        'media/photos',
        'media/audio',
        'media/thumbnails',
      ]) {
        final folder = Directory(p.join(root.path, p.fromUri(directory)));
        if (!await folder.exists()) continue;
        await for (final entity in folder.list(followLinks: false)) {
          if (entity is! File) continue;
          final relative = p.posix.join(directory, p.basename(entity.path));
          if (relative.endsWith('.part') || !keep.contains(relative)) {
            await entity.delete();
            deletedOrphans++;
          }
        }
      }
      return Success(
        MediaMaintenanceReport(
          deletedPending: deletedPending,
          failedPending: failedPending,
          deletedOrphans: deletedOrphans,
        ),
      );
    } on Object catch (error) {
      return Failure(AppFailure(FailureCode.io, message: error.toString()));
    }
  }

  static File _managedFile(Directory root, String relative) {
    if (!_safeRelative(relative)) {
      throw const FormatException('Unsafe pending media path.');
    }
    final rootPath = p.normalize(p.absolute(root.path));
    final target = p.normalize(p.join(rootPath, p.fromUri(relative)));
    if (!p.isWithin(rootPath, target)) {
      throw const FormatException('Escaping pending media path.');
    }
    return File(target);
  }

  static bool _safeRelative(String value) =>
      value.startsWith('media/') &&
      !value.contains('\\') &&
      !value.contains(':') &&
      value
          .split('/')
          .every((part) => part.isNotEmpty && part != '.' && part != '..');
}
