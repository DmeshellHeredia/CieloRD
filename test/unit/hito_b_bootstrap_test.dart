import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/app/hito_b_bootstrap.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Media implements MediaService {
  _Media(this.events);
  final List<String> events;
  final recovered = const ObservationMedia(
    id: 'recovered',
    kind: MediaKind.photo,
    relativePath: 'media/photos/recovered.jpg',
    mimeType: 'image/jpeg',
    byteSize: 10,
  );
  @override
  Future<Result<List<ObservationMedia>>> recoverPhotos() async {
    events.add('recover');
    return Success([recovered]);
  }

  @override
  Future<Result<Unit>> commitStaged(Iterable<String> mediaIds) async {
    events.add('commit:${mediaIds.join(',')}');
    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit>> discardStaged(String mediaId) async {
    events.add('discard:$mediaId');
    return const Success(Unit.value);
  }

  @override
  Future<Result<ObservationMedia?>> pickPhoto(PhotoSource source) async =>
      const Success(null);
  @override
  Future<Result<String>> resolveLocalPath(String mediaId) async =>
      Failure(AppFailure(FailureCode.notFound));
  @override
  Future<Result<String>> resolveThumbnailPath(String mediaId) async =>
      Failure(AppFailure(FailureCode.notFound));
}

final class _Maintenance implements MediaMaintenance {
  _Maintenance(this.events);
  final List<String> events;
  @override
  Future<Result<MediaMaintenanceReport>> run() async {
    events.add('maintenance');
    return const Success(
      MediaMaintenanceReport(
        deletedPending: 0,
        failedPending: 0,
        deletedOrphans: 0,
      ),
    );
  }
}

void main() {
  test('recovers into draft, commits, then reconciles', () async {
    final events = <String>[];
    final store = InMemoryObservationRepository();
    final report = await HitoBBootstrap(
      drafts: store,
      media: _Media(events),
      maintenance: _Maintenance(events),
    ).run();
    expect(events, ['recover', 'commit:recovered', 'maintenance']);
    expect(report.recoveredPhotos, 1);
    expect(report.failure, isNull);
    expect(store.length, 1);
    final draft = (await store.list(
      filter: ObservationFilter(status: ObservationStatus.draft),
    ) as Success<ObservationPage>).value.items.single;
    expect(draft.input.media.single.id, 'recovered');
  });
}
