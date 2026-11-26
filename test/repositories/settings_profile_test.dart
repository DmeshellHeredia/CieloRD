import 'dart:io';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/core/database/app_database.dart';
import 'package:cielo_rd/core/database/database_migrations.dart';
import 'package:cielo_rd/features/settings/application/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/hito_c_env.dart';

final class _FailingSettings implements SettingsRepository {
  bool failGet = false;
  bool failSave = true;
  AppSettings stored = AppSettings(theme: AppTheme.day);

  @override
  Future<Result<AppSettings>> get() async =>
      failGet ? Failure(AppFailure(FailureCode.persistence)) : Success(stored);

  @override
  Future<Result<AppSettings>> save(AppSettings settings) async {
    if (failSave) return Failure(AppFailure(FailureCode.storageFull));
    stored = settings;
    return Success(settings);
  }
}

void main() {
  sqfliteFfiInit();

  group('SQLite v4', () {
    test(
      'migra 3→4 conservando preferencias y el resto de los datos',
      () async {
        final directory = await Directory.systemTemp.createTemp('cielord_v4_');
        addTearDown(() => directory.delete(recursive: true));
        final path = '${directory.path}/v3.db';
        final raw = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 3,
            onCreate: (db, _) => const DatabaseMigrations().migrate(db, 0, 3),
          ),
        );
        await raw.insert('app_settings', {
          'id': 1,
          'theme': 'astronomer',
          'text_scale': 1.5,
          'reduced_motion': 1,
          'authentication_enabled': 1,
        });
        await raw.insert('observations', {
          'id': 'keep',
          'status': 'draft',
          'title': 'Antes de v4',
          'created_at': 1,
          'updated_at': 1,
          'revision': 1,
        });
        await expectLater(
          raw.update('app_settings', {'theme': 'system'}),
          throwsA(isA<DatabaseException>()),
        );
        await raw.close();

        final database = AppDatabase(factory: databaseFactoryFfi, path: path);
        addTearDown(database.close);
        final db = await database.open();
        expect(await db.getVersion(), 4);
        final row = (await db.query('app_settings')).single;
        expect(row['theme'], 'astronomer');
        expect(row['text_scale'], 1.5);
        expect(row['reduced_motion'], 1);
        expect(row['authentication_enabled'], 1);
        expect((await db.query('observations')).single['title'], 'Antes de v4');
        await db.update('app_settings', {'theme': 'system'});
        await expectLater(
          db.update('app_settings', {'theme': 'otro'}),
          throwsA(isA<DatabaseException>()),
        );
      },
    );
  });

  group('Preferencias', () {
    test('valores por defecto, guardado y reapertura', () async {
      final env = await HitoCEnv.create();
      final defaults = ok(await env.settings.get());
      expect(defaults.theme, AppTheme.night);
      expect(defaults.authenticationEnabled, isFalse);
      for (final theme in AppTheme.values) {
        ok(
          await env.settings.save(
            AppSettings(theme: theme, reducedMotion: true, textScale: 1.3),
          ),
        );
        await env.restart();
        final read = ok(await env.settings.get());
        expect(read.theme, theme);
        expect(read.reducedMotion, isTrue);
        expect(read.textScale, 1.3);
      }
    });

    test('el controlador revierte si no se pudo guardar', () async {
      final repository = _FailingSettings();
      final controller = SettingsController(repository: repository);
      await controller.load();
      final seen = <AppTheme>[];
      controller.addListener(() => seen.add(controller.settings.theme));
      final failure = await controller.update(
        (s) => s.copyWith(theme: AppTheme.astronomer),
      );
      expect(failure?.code, FailureCode.storageFull);
      expect(seen, [AppTheme.astronomer, AppTheme.day]);
      expect(controller.settings.theme, AppTheme.day);
    });

    test('cambios seguidos se guardan en orden', () async {
      final env = await HitoCEnv.create();
      final controller = SettingsController(repository: env.settings);
      await Future.wait([
        controller.update((s) => s.copyWith(theme: AppTheme.day)),
        controller.update((s) => s.copyWith(reducedMotion: true)),
        controller.update((s) => s.copyWith(theme: AppTheme.system)),
      ]);
      final read = ok(await env.settings.get());
      expect(read.theme, AppTheme.system);
      expect(read.reducedMotion, isTrue);
    });

    test('un fallo de lectura se expone y se recupera al reintentar', () async {
      final repository = _FailingSettings()..failGet = true;
      final controller = SettingsController(repository: repository);
      await controller.load();
      expect(controller.loadFailure, isNotNull);
      repository.failGet = false;
      await controller.load();
      expect(controller.loadFailure, isNull);
      expect(controller.settings.theme, AppTheme.day);
    });
  });

  group('Perfil', () {
    test(
      'ausente hasta guardar; crea, edita y persiste tras reabrir',
      () async {
        final env = await HitoCEnv.create();
        expect(ok(await env.profile.get()), isNull);
        ok(
          await env.profile.save(
            const ObserverProfile(
              firstName: '  Persona ',
              lastName: 'De Prueba',
              studentId: '007-PRUEBA',
              motto: 'Mirar arriba',
            ),
          ),
        );
        await env.restart();
        final created = ok(await env.profile.get())!;
        expect(created.fullName, 'Persona De Prueba');
        expect(created.studentId, '007-PRUEBA');
        ok(
          await env.profile.save(
            ObserverProfile(
              firstName: created.firstName,
              lastName: 'Editada',
              studentId: created.studentId,
            ),
          ),
        );
        await env.restart();
        final edited = ok(await env.profile.get())!;
        expect(edited.lastName, 'Editada');
        expect(edited.motto, isEmpty);
        expect((await env.rowCounts())['observer_profile'], 1);
      },
    );

    test(
      'cambiar la foto limpia la anterior y no toca los originales',
      () async {
        final env = await HitoCEnv.create();
        final original = env.galleryPhoto('original.png');
        env.nextPick = XFile(original.path);
        final first = ok(await env.media.pickPhoto(PhotoSource.gallery))!;
        ok(
          await env.profile.save(
            ObserverProfile(photoMediaId: first.id),
            newPhoto: first,
          ),
        );
        ok(await env.media.commitStaged([first.id]));
        ok(await env.maintenance.run());
        expect(env.file(first.relativePath).existsSync(), isTrue);

        final second = await env.stagePhoto();
        ok(
          await env.profile.save(
            ObserverProfile(photoMediaId: second.id),
            newPhoto: second,
          ),
        );
        ok(await env.media.commitStaged([second.id]));
        ok(await env.maintenance.run());
        expect(env.file(first.relativePath).existsSync(), isFalse);
        expect(
          env.file('media/thumbnails/${first.id}.jpg').existsSync(),
          isFalse,
        );
        expect(env.file(second.relativePath).existsSync(), isTrue);
        expect(original.existsSync(), isTrue);

        await env.restart();
        expect(ok(await env.profile.get())!.photoMediaId, second.id);
        ok(await env.media.resolveLocalPath(second.id));

        ok(
          await env.profile.save(const ObserverProfile(firstName: 'Sin foto')),
        );
        ok(await env.maintenance.run());
        expect(env.file(second.relativePath).existsSync(), isFalse);
        expect((await env.rowCounts())['media_files'], 0);
        expect((await env.rowCounts())['pending_file_deletions'], 0);
      },
    );

    test('guardar sin cambiar la foto la conserva', () async {
      final env = await HitoCEnv.create();
      final photo = await env.stagePhoto();
      ok(
        await env.profile.save(
          ObserverProfile(photoMediaId: photo.id),
          newPhoto: photo,
        ),
      );
      ok(await env.media.commitStaged([photo.id]));
      ok(
        await env.profile.save(
          ObserverProfile(firstName: 'Nombre', photoMediaId: photo.id),
        ),
      );
      ok(await env.maintenance.run());
      expect(env.file(photo.relativePath).existsSync(), isTrue);
    });

    test('rechaza textos largos, controles y fotos inexistentes', () async {
      final env = await HitoCEnv.create();
      final failure = failed(
        await env.profile.save(
          ObserverProfile(
            firstName: 'x' * 61,
            lastName: 'a\nb',
            motto: 'm' * 201,
          ),
        ),
      );
      expect(failure.fieldErrors, {
        'firstName': 'too_long',
        'lastName': 'invalid_characters',
        'motto': 'too_long',
      });
      expect(
        failed(
          await env.profile.save(const ObserverProfile(photoMediaId: 'nada')),
        ).code,
        FailureCode.validation,
      );
      final audio = await env.stageAudio();
      expect(
        failed(
          await env.profile.save(
            ObserverProfile(photoMediaId: audio.id),
            newPhoto: audio,
          ),
        ).fieldErrors,
        contains('photo'),
      );
      expect(ok(await env.profile.get()), isNull);
    });
  });
}
