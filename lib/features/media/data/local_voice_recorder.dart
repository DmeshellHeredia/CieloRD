// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:record/record.dart';

import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../../observations/domain/observation_types.dart';
import '../domain/media_service.dart';
import 'local_media_service.dart';

enum RecordingStopKind { app, interruption, routeChange, error }

final class RecordingStopEvent {
  const RecordingStopEvent(this.kind, {this.path, this.error});
  final RecordingStopKind kind;
  final String? path;
  final String? error;
}

abstract interface class RecordingBackend {
  Stream<RecordingStopEvent> get stops;
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

final class RecordPackageBackend implements RecordingBackend {
  RecordPackageBackend({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();
  final AudioRecorder _recorder;

  @override
  Stream<RecordingStopEvent> get stops => _recorder.onStopped().map(
    (event) => RecordingStopEvent(
      switch (event.reason) {
        RecordStopReason.stop => RecordingStopKind.app,
        RecordStopReason.interruption => RecordingStopKind.interruption,
        RecordStopReason.routeChange => RecordingStopKind.routeChange,
        RecordStopReason.error => RecordingStopKind.error,
      },
      path: event.path,
      error: event.error,
    ),
  );

  @override
  Future<bool> hasPermission() => _recorder.hasPermission(request: true);

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 96000,
      sampleRate: 44100,
      numChannels: 1,
      audioRouteChange: AudioRouteChangeMode.stop,
    ),
    path: path,
  );

  @override
  Future<String?> stop() => _recorder.stop();
  @override
  Future<void> cancel() => _recorder.cancel();
  @override
  Future<void> dispose() => _recorder.dispose();
}

final class LocalVoiceRecorder implements VoiceRecorder {
  LocalVoiceRecorder({
    required LocalMediaService media,
    RecordingBackend? backend,
    this.maximumDuration = const Duration(minutes: 2),
    this.tick = const Duration(seconds: 1),
  }) : _media = media,
       _backend = backend ?? RecordPackageBackend() {
    _stopSubscription = _backend.stops.listen(_onPlatformStop);
  }

  final LocalMediaService _media;
  final RecordingBackend _backend;
  final Duration maximumDuration;
  final Duration tick;
  final _states = StreamController<RecordingState>.broadcast();
  late final StreamSubscription<RecordingStopEvent> _stopSubscription;
  Timer? _timer;
  LocalAudioDraft? _draft;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _finishing = false;

  @override
  Stream<RecordingState> get states => _states.stream;

  @override
  Future<Result<Unit>> start() async {
    if (_recording || _finishing) {
      return Failure(AppFailure(FailureCode.conflict));
    }
    try {
      if (!await _backend.hasPermission()) {
        return Failure(AppFailure(FailureCode.permissionDenied));
      }
      _draft = await _media.allocateAudioDraft();
      await _backend.start(_draft!.partPath);
      _elapsed = Duration.zero;
      _recording = true;
      _emit(const RecordingState(phase: RecorderPhase.recording));
      _timer = Timer.periodic(tick, (_) {
        _elapsed += tick;
        if (_elapsed >= maximumDuration) {
          _elapsed = maximumDuration;
          unawaited(stop());
        } else {
          _emit(
            RecordingState(phase: RecorderPhase.recording, elapsed: _elapsed),
          );
        }
      });
      return const Success(Unit.value);
    } on Object catch (error) {
      await _media.discardAudioDraft(_draft);
      _reset();
      final failure = AppFailure(
        FailureCode.unavailable,
        message: error.toString(),
      );
      _emit(RecordingState(phase: RecorderPhase.failed, failure: failure));
      return Failure(failure);
    }
  }

  @override
  Future<Result<ObservationMedia>> stop() async {
    if (!_recording || _draft == null || _finishing) {
      return Failure(AppFailure(FailureCode.conflict));
    }
    _finishing = true;
    _timer?.cancel();
    _emit(RecordingState(phase: RecorderPhase.stopping, elapsed: _elapsed));
    try {
      final path = await _backend.stop();
      if (path == null) {
        throw const FormatException('Recorder returned no file.');
      }
      final media = await _media.finalizeAudioDraft(_draft!, _elapsed);
      final elapsed = Duration(milliseconds: media.durationMs!);
      _reset();
      _emit(
        RecordingState(
          phase: RecorderPhase.completed,
          elapsed: elapsed,
          media: media,
        ),
      );
      return Success(media);
    } on Object catch (error) {
      await _media.discardAudioDraft(_draft);
      _reset();
      final failure = AppFailure(FailureCode.io, message: error.toString());
      _emit(RecordingState(phase: RecorderPhase.failed, failure: failure));
      return Failure(failure);
    }
  }

  @override
  Future<Result<Unit>> cancel() async {
    if (!_recording || _finishing) {
      return Failure(AppFailure(FailureCode.conflict));
    }
    _finishing = true;
    _timer?.cancel();
    try {
      await _backend.cancel();
      await _media.discardAudioDraft(_draft);
      _reset();
      _emit(const RecordingState(phase: RecorderPhase.idle));
      return const Success(Unit.value);
    } on Object catch (error) {
      _reset();
      return Failure(AppFailure(FailureCode.io, message: error.toString()));
    }
  }

  void _onPlatformStop(RecordingStopEvent event) {
    if (!_recording || _finishing) return;
    if (event.kind == RecordingStopKind.app) return;
    _timer?.cancel();
    _finishing = true;
    unawaited(_completeInterrupted(event));
  }

  Future<void> _completeInterrupted(RecordingStopEvent event) async {
    try {
      if (event.kind == RecordingStopKind.error || event.path == null) {
        throw StateError(
          event.error ?? 'Recording interrupted without a file.',
        );
      }
      final media = await _media.finalizeAudioDraft(_draft!, _elapsed);
      _reset();
      _emit(
        RecordingState(
          phase: RecorderPhase.completed,
          elapsed: Duration(milliseconds: media.durationMs!),
          media: media,
        ),
      );
    } on Object catch (error) {
      await _media.discardAudioDraft(_draft);
      _reset();
      _emit(
        RecordingState(
          phase: RecorderPhase.failed,
          failure: AppFailure(FailureCode.io, message: error.toString()),
        ),
      );
    }
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _draft = null;
    _recording = false;
    _finishing = false;
    _elapsed = Duration.zero;
  }

  void _emit(RecordingState state) {
    if (!_states.isClosed) _states.add(state);
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    if (_recording) {
      await _backend.cancel();
      await _media.discardAudioDraft(_draft);
    }
    await _stopSubscription.cancel();
    await _backend.dispose();
    await _states.close();
  }
}
