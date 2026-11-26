import 'dart:async';
import 'dart:io';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/maintenance/data/local_erase_all_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/hito_c_env.dart';

final class _Recorder implements VoiceRecorder {
  _Recorder(this.events, this.gateClosed);
  final List<String> events;
  final bool Function() gateClosed;

  @override
  Stream<RecordingState> get states => const Stream.empty();
  @override
  Future<Result<Unit>> start() async => const Success(Unit.value);
  @override
  Future<Result<ObservationMedia>> stop() async =>
      Failure(AppFailure(FailureCode.conflict));
  @override
  Future<Result<Unit>> cancel() async {
    events.add('recorder:${gateClosed() ? 'cerrada' : 'abierta'}');
    return const Success(Unit.value);
  }

  @override
  Future<void> dispose() async {}
}

final class _Player implements AudioPlayerService {
  _Player(this.events);
  final List<String> events;

  @override
  Stream<PlaybackState> get states => const Stream.empty();
  @override
  Future<Result<Unit>> load(String mediaId) async => const Success(Unit.value);
  @override
  Future<Result<Unit>> play() async => const Success(Unit.value);
  @override
  Future<Result<Unit>> pause() async => const Success(Unit.value);
  @override
  Future<Result<Unit>> seek(Duration position) async =>
      const Success(Unit.value);
  @override
  Future<Result<Unit>> stop() async {
    events.add('player');
    throw StateError('el plugin falló al detenerse');
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  const empty = {
    'observations': 0,
    'media_files': 0,
    'observation_media': 0,
    'observer_profile': 0,
    'app_settings': 0,
    'pending_file_deletions': 0,
  };

  test('base vacía: termina completa y sin marcador', () async {
    final env = await HitoCEnv.create();
    final report = ok(await env.eraser().eraseAll());
    expect(report.isComplete, isTrue);
    expect(await env.eraser().hasPendingErase(), isFalse);
    expect(await env.rowCounts(), empty);
    expect(env.privateFiles(), isEmpty);
  });

  test('conteos previos reales', () async {
    final env = await HitoCEnv.create();
    await env.seed();
    ok(await env.settings.save(AppSettings(theme: AppTheme.day)));
    File('${env.cache.path}/picker.jpg').writeAsStringSync('x');
    env.file('media/audio/interrumpida.m4a.part').writeAsStringSync('x');
    final preview = ok(await env.eraser().preview());
    expect(preview.published, 1);
    expect(preview.drafts, 1);
    expect(preview.photos, 2);
    expect(preview.audios, 1);
    expect(preview.hasProfile, isTrue);
    expect(preview.hasProfilePhoto, isTrue);
    expect(preview.hasSettings, isTrue);
    expect(preview.temporaryFiles, 2);
    expect(preview.isEmpty, isFalse);
  });

  test(
    'elimina datos, medios, staging, temporales, cola y preferencias',
    () async {
      final env = await HitoCEnv.create();
      final seeded = await env.seed();
      ok(
        await env.settings.save(
          AppSettings(theme: AppTheme.astronomer, authenticationEnabled: true),
        ),
      );
      // Cola pendiente: se borra una observación sin ejecutar la limpieza.
      ok(
        await env.store.delete(
          seeded.full.id,
          expectedRevision: seeded.full.revision,
        ),
      );
      expect((await env.rowCounts())['pending_file_deletions'], 3);
      final staged = await env.stagePhoto();
      env.file('staging/import-x/backup.zip')
        ..createSync(recursive: true)
        ..writeAsStringSync('zip');
      Directory('${env.cache.path}/just_audio').createSync();
      File('${env.cache.path}/just_audio/a.bin').writeAsStringSync('x');

      // Fuera del espacio privado administrado.
      final exported = File('${env.outside.path}/CieloRD-copia.zip')
        ..writeAsStringSync('copia');
      final foreign = env.file('profileInstalled')
        ..writeAsStringSync('sistema');
      final gallery = env.outside.listSync().whereType<File>().length;
      final asset = File('assets/maps/dominican_republic_adm1.geojson');
      final assetBefore = asset.readAsBytesSync();

      var preferences = 0;
      final events = <String>[];
      final report = ok(
        await env
            .eraser(
              recorder: _Recorder(events, () => env.gate.isClosed),
              player: _Player(events),
              clearPreferences: () async => preferences++,
            )
            .eraseAll(),
      );
      expect(report.isComplete, isTrue);
      expect(
        events,
        ['recorder:abierta', 'player'],
        reason:
            'se detiene el audio antes de cerrar la puerta, y un fallo del '
            'plugin no impide borrar',
      );
      expect(preferences, 1);
      expect(await env.rowCounts(), empty);
      expect(env.privateFiles(), ['support/profileInstalled']);
      expect(foreign.existsSync(), isTrue);
      expect(exported.readAsStringSync(), 'copia');
      expect(env.outside.listSync().whereType<File>().length, gallery);
      expect(asset.readAsBytesSync(), assetBefore);
      expect(
        failed(await env.media.commitStaged([staged.id])).code,
        FailureCode.notFound,
        reason: 'los adjuntos sin confirmar se olvidan',
      );
      final after = ok(await env.settings.get());
      expect(after.theme, AppTheme.night);
      expect(after.authenticationEnabled, isFalse);
      expect(ok(await env.profile.get()), isNull);
    },
  );

  test('tras reiniciar sigue vacío y la app vuelve a funcionar', () async {
    final env = await HitoCEnv.create();
    await env.seed();
    ok(await env.eraser().eraseAll());
    await env.restart();
    expect(await env.rowCounts(), empty);
    ok(await env.maintenance.run());
    final fresh = await env.add(env.input(media: [await env.stagePhoto()]));
    await env.restart();
    expect(ok(await env.store.getById(fresh.id)).input.media, hasLength(1));
  });

  test('ejecutarlo varias veces es inocuo', () async {
    final env = await HitoCEnv.create();
    await env.seed();
    for (var i = 0; i < 3; i++) {
      expect(ok(await env.eraser().eraseAll()).isComplete, isTrue);
    }
    expect(env.privateFiles(), isEmpty);
  });

  test(
    'fallo parcial: no anuncia éxito, conserva marcador y se reintenta',
    () async {
      final env = await HitoCEnv.create();
      final seeded = await env.seed();
      final stuck = seeded.full.input.media.first.relativePath;
      final partial = ok(
        await env
            .eraser(
              deleteEntity: (entity) async {
                if (entity.path.replaceAll('\\', '/').endsWith(stuck)) {
                  throw const FileSystemException('bloqueado');
                }
                await entity.delete();
              },
            )
            .eraseAll(),
      );
      expect(partial.isComplete, isFalse);
      expect(partial.pendingFiles, 1);
      expect(partial.residual.single, stuck);
      expect(partial.databaseCleared, isTrue);
      expect(await env.eraser().hasPendingErase(), isTrue);
      expect(env.file(stuck).existsSync(), isTrue);

      final retry = ok(await env.eraser().eraseAll());
      expect(retry.isComplete, isTrue);
      expect(await env.eraser().hasPendingErase(), isFalse);
      expect(env.privateFiles(), isEmpty);
    },
  );

  test('preferencias sin limpiar cuentan como borrado incompleto', () async {
    final env = await HitoCEnv.create();
    final report = ok(
      await env
          .eraser(clearPreferences: () async => throw StateError('canal'))
          .eraseAll(),
    );
    expect(report.isComplete, isFalse);
    expect(report.preferencesCleared, isFalse);
    expect(await env.eraser().hasPendingErase(), isTrue);
  });

  test(
    'recuperación: muerte del proceso a mitad y arranque posterior',
    () async {
      final env = await HitoCEnv.create();
      await env.seed();
      // Estado que deja un proceso muerto tras escribir el marcador.
      env.file(LocalEraseAllService.markerName).writeAsStringSync('erase-all');
      await env.database.destroy();
      expect(env.privateFiles().where((f) => f.contains('media/')), isNotEmpty);
      await env.restart();
      final eraser = env.eraser();
      expect(await eraser.hasPendingErase(), isTrue);
      expect(ok(await eraser.eraseAll()).isComplete, isTrue);
      expect(await eraser.hasPendingErase(), isFalse);
      expect(env.privateFiles(), isEmpty);
      expect(await env.rowCounts(), empty);
    },
  );

  test('una base ilegible también se elimina', () async {
    final env = await HitoCEnv.create();
    await env.database.close();
    File('${env.root.path}/cielo_rd.db').writeAsStringSync('esto no es SQLite');
    expect(await env.eraser().preview(), isA<Failure<EraseAllPreview>>());
    expect(ok(await env.eraser().eraseAll()).isComplete, isTrue);
    expect(await env.rowCounts(), empty);
  });

  test(
    'bloquea escrituras durante el borrado y espera las que ya corrían',
    () async {
      final env = await HitoCEnv.create();
      await env.seed();
      final results = <Result<Object?>>[];
      final report = ok(
        await env
            .eraser(
              clearPreferences: () async {
                results
                  ..add(
                    await env.store.create(
                      env.input(),
                      status: ObservationStatus.published,
                    ),
                  )
                  ..add(await env.profile.save(const ObserverProfile()))
                  ..add(await env.settings.save(AppSettings()))
                  ..add(await env.media.pickPhoto(PhotoSource.gallery))
                  ..add(await env.maintenance.run())
                  ..add(await env.eraser().eraseAll());
              },
            )
            .eraseAll(),
      );
      expect(report.isComplete, isTrue);
      expect(results, hasLength(6));
      for (final result in results) {
        expect(failed(result).code, FailureCode.busy);
      }
      expect(await env.rowCounts(), empty);

      // Una escritura ya iniciada termina antes y también se borra.
      final hold = Completer<void>();
      final writing = env.gate.write(() async {
        await hold.future;
        final db = await env.database.open();
        await db.insert('observations', {
          'id': 'tardia',
          'status': 'draft',
          'title': '',
          'created_at': 1,
          'updated_at': 1,
        });
      });
      final erasing = env.eraser().eraseAll();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      hold.complete();
      await writing;
      expect(ok(await erasing).isComplete, isTrue);
      expect(await env.rowCounts(), empty);
    },
  );

  test('no sigue enlaces simbólicos hacia fuera', () async {
    final env = await HitoCEnv.create();
    final victim = File('${env.outside.path}/ajeno.txt')
      ..writeAsStringSync('ajeno');
    Directory('${env.support.path}/media/photos').createSync(recursive: true);
    try {
      Link('${env.support.path}/media/photos/enlace')
          .createSync(env.outside.path);
    } on FileSystemException {
      markTestSkipped('Este Windows no permite crear enlaces simbólicos.');
      return;
    }
    expect(ok(await env.eraser().eraseAll()).isComplete, isTrue);
    expect(victim.readAsStringSync(), 'ajeno');
  });
}
