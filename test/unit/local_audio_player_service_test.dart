import 'dart:async';
import 'dart:io';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/core/database/app_database.dart';
import 'package:cielo_rd/features/media/data/local_audio_player_service.dart';
import 'package:cielo_rd/features/media/data/local_media_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final class FakeAudioBackend implements AudioPlaybackBackend {
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration?>.broadcast();
  final phases = StreamController<AudioBackendPhase>.broadcast();
  String? loaded;
  Duration? sought;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;
  @override
  Stream<AudioBackendPhase> get phaseStream => phases.stream;
  @override
  Future<Duration?> load(String path) async {
    loaded = path;
    return const Duration(seconds: 8);
  }

  @override
  Future<void> play() async => phases.add(AudioBackendPhase.playing);
  @override
  Future<void> pause() async => phases.add(AudioBackendPhase.paused);
  @override
  Future<void> seek(Duration value) async {
    sought = value;
  }

  @override
  Future<void> stop() async => phases.add(AudioBackendPhase.paused);
  @override
  Future<void> dispose() async {
    await positions.close();
    await durations.close();
    await phases.close();
  }
}

void main() {
  sqfliteFfiInit();
  late Directory temp;
  late AppDatabase database;
  late LocalMediaService media;
  late FakeAudioBackend backend;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cielord_player_');
    final file = File('${temp.path}/media/audio/a1.m4a');
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 3]);
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${temp.path}/db.sqlite',
    );
    final db = await database.open();
    await db.insert('media_files', {
      'id': 'a1',
      'relative_path': 'media/audio/a1.m4a',
      'mime_type': 'audio/mp4',
      'byte_size': 3,
      'duration_ms': 8000,
      'created_at': 1,
    });
    media = LocalMediaService(
      database: database,
      supportDirectory: () async => temp,
      recover: () async => const [],
    );
    backend = FakeAudioBackend();
  });
  tearDown(() async {
    await database.close();
    await temp.delete(recursive: true);
  });

  test(
    'loads by media id and exposes playback controls and completion',
    () async {
      final player = LocalAudioPlayerService(media: media, backend: backend);
      addTearDown(player.dispose);
      final states = <PlaybackState>[];
      final subscription = player.states.listen(states.add);
      addTearDown(subscription.cancel);
      expect(await player.load('a1'), isA<Success<Unit>>());
      expect(backend.loaded, endsWith('a1.m4a'));
      expect(states.last.phase, PlayerPhase.paused);
      expect(states.last.duration, const Duration(seconds: 8));
      expect(await player.play(), isA<Success<Unit>>());
      await Future<void>.delayed(Duration.zero);
      expect(states.last.phase, PlayerPhase.playing);
      expect(
        await player.seek(const Duration(seconds: 3)),
        isA<Success<Unit>>(),
      );
      expect(backend.sought, const Duration(seconds: 3));
      backend.phases.add(AudioBackendPhase.completed);
      await Future<void>.delayed(Duration.zero);
      expect(states.last.phase, PlayerPhase.completed);
    },
  );
}
