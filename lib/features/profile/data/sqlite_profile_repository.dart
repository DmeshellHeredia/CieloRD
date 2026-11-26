import 'package:sqflite/sqflite.dart';

import '../../../core/concurrency/write_gate.dart';
import '../../../core/database/app_database.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../../observations/domain/observation_types.dart';
import '../domain/profile_repository.dart';

/// Perfil del observador en la fila única de `observer_profile`.
final class SqliteProfileRepository implements ProfileRepository {
  SqliteProfileRepository({
    required this.database,
    WriteGate? gate,
    DateTime Function()? clock,
  }) : _gate = gate ?? WriteGate(),
       _clock = clock ?? DateTime.now;

  final AppDatabase database;
  final WriteGate _gate;
  final DateTime Function() _clock;

  static final RegExp _control = RegExp(r'[\x00-\x1f\x7f]');

  @override
  Future<Result<ObserverProfile?>> get() async {
    try {
      final db = await database.open();
      final rows = await db.query('observer_profile', where: 'id = 1');
      if (rows.isEmpty) return const Success(null);
      final row = rows.single;
      return Success(
        ObserverProfile(
          firstName: row['first_name']! as String,
          lastName: row['last_name']! as String,
          studentId: row['student_id']! as String,
          motto: row['motto']! as String,
          photoMediaId: row['photo_media_id'] as String?,
        ),
      );
    } on Object catch (error) {
      return Failure(
        AppFailure(FailureCode.persistence, message: error.toString()),
      );
    }
  }

  @override
  Future<Result<ObserverProfile>> save(
    ObserverProfile profile, {
    ObservationMedia? newPhoto,
  }) async {
    final clean = normalize(profile);
    final errors = {
      ...validate(clean),
      if (newPhoto != null &&
          (newPhoto.kind != MediaKind.photo ||
              newPhoto.id != clean.photoMediaId))
        'photo': 'wrong_media_type',
    };
    if (errors.isNotEmpty) {
      return Failure(AppFailure(FailureCode.validation, fieldErrors: errors));
    }
    try {
      return await _gate.write(() async {
        final db = await database.open();
        return db.transaction((txn) async {
          final now = _clock().toUtc().millisecondsSinceEpoch;
          final previous = await txn.query(
            'observer_profile',
            columns: ['photo_media_id'],
            where: 'id = 1',
          );
          final previousPhoto = previous.isEmpty
              ? null
              : previous.single['photo_media_id'] as String?;
          if (newPhoto != null) {
            await txn.insert('media_files', {
              'id': newPhoto.id,
              'relative_path': newPhoto.relativePath,
              'mime_type': newPhoto.mimeType,
              'byte_size': newPhoto.byteSize,
              'sha256': newPhoto.sha256,
              'created_at': now,
            });
          }
          await txn.insert('observer_profile', {
            'id': 1,
            'first_name': clean.firstName,
            'last_name': clean.lastName,
            'student_id': clean.studentId,
            'motto': clean.motto,
            'photo_media_id': clean.photoMediaId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          if (previousPhoto != null && previousPhoto != clean.photoMediaId) {
            await _release(txn, previousPhoto, now);
          }
          return Success(clean);
        });
      });
    } on WriteGateClosed {
      return Failure(AppFailure(FailureCode.busy));
    } on DatabaseException catch (error) {
      final constraint = error.toString().toLowerCase().contains('constraint');
      return Failure(
        AppFailure(
          constraint ? FailureCode.validation : FailureCode.persistence,
          message: error.toString(),
        ),
      );
    } on Object catch (error) {
      return Failure(
        AppFailure(FailureCode.unexpected, message: error.toString()),
      );
    }
  }

  /// Encola el archivo de la foto anterior si ninguna observación la usa.
  Future<void> _release(Transaction txn, String id, int now) async {
    final used = await txn.query(
      'observation_media',
      columns: ['media_id'],
      where: 'media_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (used.isNotEmpty) return;
    final file = await txn.query(
      'media_files',
      columns: ['relative_path'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (file.isEmpty) return;
    await txn.delete('media_files', where: 'id = ?', whereArgs: [id]);
    await txn.insert('pending_file_deletions', {
      'relative_path': file.single['relative_path'],
      'created_at': now,
      'attempts': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static ObserverProfile normalize(ObserverProfile p) => ObserverProfile(
    firstName: p.firstName.trim(),
    lastName: p.lastName.trim(),
    studentId: p.studentId.trim(),
    motto: p.motto.trim(),
    photoMediaId: p.photoMediaId,
  );

  /// Errores por campo: `too_long` o `invalid_characters`.
  static Map<String, String> validate(ObserverProfile p) {
    final errors = <String, String>{};
    void check(String field, String value, int max) {
      if (value.length > max) {
        errors[field] = 'too_long';
      } else if (_control.hasMatch(value)) {
        errors[field] = 'invalid_characters';
      }
    }

    check('firstName', p.firstName, ObserverProfile.maxNameLength);
    check('lastName', p.lastName, ObserverProfile.maxNameLength);
    check('studentId', p.studentId, ObserverProfile.maxStudentIdLength);
    check('motto', p.motto, ObserverProfile.maxMottoLength);
    return errors;
  }
}
