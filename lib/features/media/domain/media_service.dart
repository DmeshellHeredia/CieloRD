import '../../../core/domain/result.dart';
import '../../../core/domain/app_failure.dart';
import '../../observations/domain/observation_types.dart';

enum PhotoSource { camera, gallery }

enum RecorderPhase { idle, recording, stopping, completed, failed }

enum PlayerPhase { idle, loading, paused, playing, completed, failed }

final class RecordingState {
  const RecordingState({
    required this.phase,
    this.elapsed = Duration.zero,
    this.failure,
    this.media,
  });
  final RecorderPhase phase;
  final Duration elapsed;
  final AppFailure? failure;
  final ObservationMedia? media;
}

final class PlaybackState {
  const PlaybackState({
    required this.phase,
    this.position = Duration.zero,
    this.duration,
    this.failure,
    this.mediaId,
  });
  final PlayerPhase phase;
  final Duration position;
  final Duration? duration;
  final AppFailure? failure;

  /// Attachment whose playback produced this state.
  final String? mediaId;
}

abstract interface class MediaService {
  /// Success(null) means user cancellation. Returned files are staged privately.
  Future<Result<ObservationMedia?>> pickPhoto(PhotoSource source);
  Future<Result<List<ObservationMedia>>> recoverPhotos();

  /// Marks staged files as durably attached after the observation transaction.
  Future<Result<Unit>> commitStaged(Iterable<String> mediaIds);

  /// Releases only an uncommitted staged file, never an attached/original file.
  Future<Result<Unit>> discardStaged(String mediaId);
  Future<Result<String>> resolveLocalPath(String mediaId);
  Future<Result<String>> resolveThumbnailPath(String mediaId);
}

abstract interface class VoiceRecorder {
  Stream<RecordingState> get states;
  Future<Result<Unit>> start();

  /// Finalizes a staged attachment; enforces the 120-second product limit.
  Future<Result<ObservationMedia>> stop();
  Future<Result<Unit>> cancel();
  Future<void> dispose();
}

abstract interface class AudioPlayerService {
  Stream<PlaybackState> get states;
  Future<Result<Unit>> load(String mediaId);
  Future<Result<Unit>> play();
  Future<Result<Unit>> pause();
  Future<Result<Unit>> seek(Duration position);
  Future<Result<Unit>> stop();
  Future<void> dispose();
}

final class MediaMaintenanceReport {
  const MediaMaintenanceReport({
    required this.deletedPending,
    required this.failedPending,
    required this.deletedOrphans,
  });
  final int deletedPending;
  final int failedPending;
  final int deletedOrphans;
}

abstract interface class MediaMaintenance {
  Future<Result<MediaMaintenanceReport>> run();
}
