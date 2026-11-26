import 'contracts.dart';

final class HitoBBootstrapReport {
  const HitoBBootstrapReport({
    required this.recoveredPhotos,
    this.maintenance,
    this.failure,
  });
  final int recoveredPhotos;
  final MediaMaintenanceReport? maintenance;
  final AppFailure? failure;
}

/// Executes the crash-safe startup order for lost picker data and orphan
/// cleanup. A recoverable failure never prevents the application from opening.
final class HitoBBootstrap {
  const HitoBBootstrap({
    required this.drafts,
    required this.media,
    required this.maintenance,
  });
  final DraftService drafts;
  final MediaService media;
  final MediaMaintenance maintenance;

  Future<HitoBBootstrapReport> run() async {
    var recoveredCount = 0;
    AppFailure? failure;
    final recovered = await media.recoverPhotos();
    switch (recovered) {
      case Failure<List<ObservationMedia>>(failure: final failureValue):
        failure = failureValue;
      case Success<List<ObservationMedia>>(:final List<ObservationMedia> value):
        recoveredCount = value.length;
        if (value.isNotEmpty) {
          final saved = await drafts.save(ObservationInput(media: value));
          switch (saved) {
            case Success<Observation>():
              final committed = await media.commitStaged(
                value.map((item) => item.id),
              );
              if (committed is Failure<Unit>) failure = committed.failure;
            case Failure<Observation>(failure: final failureValue):
              failure = failureValue;
              for (final item in value) {
                await media.discardStaged(item.id);
              }
          }
        }
    }
    final maintenanceResult = await maintenance.run();
    final MediaMaintenanceReport? maintenanceReport;
    switch (maintenanceResult) {
      case Success<MediaMaintenanceReport>(:final value):
        maintenanceReport = value;
      case Failure<MediaMaintenanceReport>(failure: final failureValue):
        maintenanceReport = null;
        failure ??= failureValue;
    }
    return HitoBBootstrapReport(
      recoveredPhotos: recoveredCount,
      maintenance: maintenanceReport,
      failure: failure,
    );
  }
}
