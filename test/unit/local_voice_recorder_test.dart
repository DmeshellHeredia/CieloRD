import 'dart:async';
import 'dart:io';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/core/database/app_database.dart';
import 'package:cielo_rd/features/media/data/local_media_service.dart';
import 'package:cielo_rd/features/media/data/local_voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final class FakeRecordingBackend implements RecordingBackend {
  final controller = StreamController<RecordingStopEvent>.broadcast();
  String? path;
  bool permitted = true;
  @override
  Stream<RecordingStopEvent> get stops => controller.stream;
  @override
  Future<bool> hasPermission() async => permitted;
  @override
  Future<void> start(String path) async {
    this.path = path;
    await File(path).writeAsBytes([1, 2, 3]);
  }

  @override
  Future<String?> stop() async => path;
  @override
  Future<void> cancel() async {
    final file = path == null ? null : File(path!);
    if (file != null && await file.exists()) await file.delete();
  }

  @override
  Future<void> dispose() async => controller.close();
}

void main() {
  sqfliteFfiInit();
  late Directory temp;
  late AppDatabase database;
  late LocalMediaService media;
  late FakeRecordingBackend backend;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cielord_voice_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${temp.path}/db.sqlite',
    );
    media = LocalMediaService(
      database: database,
      supportDirectory: () async => temp,
      recover: () async => const [],
      newId: () => 'audio-1',
    );
    backend = FakeRecordingBackend();
  });
  tearDown(() async {
    await database.close();
    await temp.delete(recursive: true);
  });

  test(
    'stops automatically at configured limit and emits staged M4A',
    () async {
      final recorder = LocalVoiceRecorder(
        media: media,
        backend: backend,
        maximumDuration: const Duration(milliseconds: 40),
        tick: const Duration(milliseconds: 10),
      );
      addTearDown(recorder.dispose);
      final completed = recorder.states.firstWhere(
        (state) => state.phase == RecorderPhase.completed,
      );
      expect(await recorder.start(), isA<Success<Unit>>());
      final state = await completed.timeout(const Duration(seconds: 2));
      expect(state.media, isNotNull);
      expect(state.media!.mimeType, 'audio/mp4');
      expect(state.media!.relativePath, 'media/audio/audio-1.m4a');
      expect(state.media!.durationMs, 40);
      expect(await media.resolveLocalPath('audio-1'), isA<Success<String>>());
    },
  );

  test(
    'denied microphone and cancellation do not leave an attachment',
    () async {
      final recorder = LocalVoiceRecorder(media: media, backend: backend);
      addTearDown(recorder.dispose);
      backend.permitted = false;
      expect(
        (await recorder.start() as Failure<Unit>).failure.code,
        FailureCode.permissionDenied,
      );
      backend.permitted = true;
      expect(await recorder.start(), isA<Success<Unit>>());
      expect(await recorder.cancel(), isA<Success<Unit>>());
      expect(await media.resolveLocalPath('audio-1'), isA<Failure<String>>());
    },
  );
}
