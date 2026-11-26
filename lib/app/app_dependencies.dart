import 'contracts.dart';

/// Construct with fakes for UI work; concrete adapters arrive after C0 review.
/// No global singleton or service locator; pass required collaborators onward.
final class AppDependencies {
  const AppDependencies({
    required this.observations,
    required this.observationService,
    required this.drafts,
    required this.location,
    required this.media,
    required this.recorder,
    required this.player,
    required this.profile,
    required this.settings,
    required this.stats,
    required this.backup,
    required this.eraseAll,
    this.mediaMaintenance,
    this.validator = const ObservationValidator(),
  });
  final ObservationRepository observations;
  final ObservationService observationService;
  final DraftService drafts;
  final LocationService location;
  final MediaService media;
  final VoiceRecorder recorder;
  final AudioPlayerService player;
  final ProfileRepository profile;
  final SettingsRepository settings;
  final StatsService stats;
  final BackupService backup;
  final EraseAllService eraseAll;
  final MediaMaintenance? mediaMaintenance;
  final ObservationValidator validator;
}
