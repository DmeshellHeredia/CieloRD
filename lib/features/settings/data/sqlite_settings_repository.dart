import 'package:sqflite/sqflite.dart';

import '../../../core/concurrency/write_gate.dart';
import '../../../core/database/app_database.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../domain/settings_repository.dart';

/// Preferencias en la fila única de `app_settings`.
final class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository({required this.database, WriteGate? gate})
    : _gate = gate ?? WriteGate();

  final AppDatabase database;
  final WriteGate _gate;

  @override
  Future<Result<AppSettings>> get() async {
    try {
      final db = await database.open();
      final rows = await db.query('app_settings', where: 'id = 1');
      if (rows.isEmpty) return Success(AppSettings());
      final row = rows.single;
      return Success(
        AppSettings(
          theme: AppTheme.values.byName(row['theme']! as String),
          textScale: (row['text_scale'] as num?)?.toDouble(),
          reducedMotion: row['reduced_motion'] == 1,
          authenticationEnabled: row['authentication_enabled'] == 1,
        ),
      );
    } on Object catch (error) {
      return Failure(
        AppFailure(FailureCode.persistence, message: error.toString()),
      );
    }
  }

  @override
  Future<Result<AppSettings>> save(AppSettings settings) async {
    try {
      await _gate.write(() async {
        final db = await database.open();
        await db.insert('app_settings', {
          'id': 1,
          'theme': settings.theme.name,
          'text_scale': settings.textScale,
          'reduced_motion': settings.reducedMotion ? 1 : 0,
          'authentication_enabled': settings.authenticationEnabled ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
      return Success(settings);
    } on WriteGateClosed {
      return Failure(AppFailure(FailureCode.busy));
    } on Object catch (error) {
      return Failure(
        AppFailure(FailureCode.persistence, message: error.toString()),
      );
    }
  }
}
