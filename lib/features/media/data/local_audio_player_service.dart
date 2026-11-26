// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../domain/media_service.dart';

enum AudioBackendPhase { paused, playing, completed }

abstract interface class AudioPlaybackBackend {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<AudioBackendPhase> get phaseStream;
  Future<Duration?> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration value);
  Future<void> stop();
  Future<void> dispose();
}

final class JustAudioBackend implements AudioPlaybackBackend {
  JustAudioBackend({AudioPlayer? player}) : _player = player ?? AudioPlayer();
  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Stream<AudioBackendPhase> get phaseStream => _player.playerStateStream
      .map(
        (state) => state.processingState == ProcessingState.completed
            ? AudioBackendPhase.completed
            : state.playing
            ? AudioBackendPhase.playing
            : AudioBackendPhase.paused,
      )
      .distinct();
  @override
  Future<Duration?> load(String path) => _player.setFilePath(path);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration value) => _player.seek(value);
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

final class LocalAudioPlayerService implements AudioPlayerService {
  LocalAudioPlayerService({
    required MediaService media,
    AudioPlaybackBackend? backend,
  }) : _media = media,
       _backend = backend ?? JustAudioBackend() {
    _subscriptions.add(
      _backend.positionStream.listen((value) {
        _position = value;
        _emit();
      }),
    );
    _subscriptions.add(
      _backend.durationStream.listen((value) {
        _duration = value;
        _emit();
      }),
    );
    _subscriptions.add(
      _backend.phaseStream.listen((value) {
        _phase = switch (value) {
          AudioBackendPhase.paused => PlayerPhase.paused,
          AudioBackendPhase.playing => PlayerPhase.playing,
          AudioBackendPhase.completed => PlayerPhase.completed,
        };
        _emit();
      }),
    );
  }

  final MediaService _media;
  final AudioPlaybackBackend _backend;
  final _states = StreamController<PlaybackState>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions = [];
  PlayerPhase _phase = PlayerPhase.idle;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _loaded = false;
  String? _mediaId;

  @override
  Stream<PlaybackState> get states => _states.stream;

  @override
  Future<Result<Unit>> load(String mediaId) async {
    final previous = _mediaId;
    if (previous != null && previous != mediaId && !_states.isClosed) {
      _states.add(PlaybackState(phase: PlayerPhase.idle, mediaId: previous));
    }
    _mediaId = mediaId;
    _phase = PlayerPhase.loading;
    _position = Duration.zero;
    _emit();
    final path = await _media.resolveLocalPath(mediaId);
    if (path is Failure<String>) {
      _failed(path.failure);
      return Failure(path.failure);
    }
    try {
      _duration = await _backend.load((path as Success<String>).value);
      _loaded = true;
      _phase = PlayerPhase.paused;
      _emit();
      return const Success(Unit.value);
    } on Object catch (error) {
      final failure = AppFailure(
        FailureCode.unavailable,
        message: error.toString(),
      );
      _failed(failure);
      return Failure(failure);
    }
  }

  @override
  Future<Result<Unit>> play() => _command(_backend.play);
  @override
  Future<Result<Unit>> pause() => _command(_backend.pause);
  @override
  Future<Result<Unit>> seek(Duration position) =>
      _command(() => _backend.seek(position));
  @override
  Future<Result<Unit>> stop() => _command(_backend.stop);

  Future<Result<Unit>> _command(Future<void> Function() action) async {
    if (!_loaded) return Failure(AppFailure(FailureCode.conflict));
    try {
      await action();
      return const Success(Unit.value);
    } on Object catch (error) {
      final failure = AppFailure(
        FailureCode.unavailable,
        message: error.toString(),
      );
      _failed(failure);
      return Failure(failure);
    }
  }

  void _emit() {
    if (!_states.isClosed) {
      _states.add(
        PlaybackState(
          phase: _phase,
          position: _position,
          duration: _duration,
          mediaId: _mediaId,
        ),
      );
    }
  }

  void _failed(AppFailure failure) {
    _phase = PlayerPhase.failed;
    if (!_states.isClosed) {
      _states.add(
        PlaybackState(
          phase: PlayerPhase.failed,
          position: _position,
          duration: _duration,
          failure: failure,
          mediaId: _mediaId,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _backend.dispose();
    await _states.close();
  }
}
