import 'dart:async';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/observations/presentation/form/observation_form_screen.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';
import 'diary_fixtures.dart';

final class FakeLocation implements LocationService {
  FakeLocation({this.failure});
  final AppFailure? failure;
  @override
  Future<Result<LocationPermission>> permission() async =>
      const Success(LocationPermission.precise);
  @override
  Future<Result<LocationFix>> current({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (failure != null) return Failure(failure!);
    final captured = DateTime.utc(2026, 11, 23, 2);
    final location = ObservationLocation(
      latitude: 18.4861,
      longitude: -69.9312,
      source: LocationSource.gps,
      accuracyM: 7,
      capturedAt: captured,
    );
    return Success(LocationFix(location: location, capturedAt: captured));
  }
}

final class FakeMedia implements MediaService {
  final committed = <String>[];
  final discarded = <String>[];
  var next = 0;
  @override
  Future<Result<ObservationMedia?>> pickPhoto(PhotoSource source) async {
    next++;
    return Success(
      ObservationMedia(
        id: 'photo-$next',
        kind: MediaKind.photo,
        relativePath: 'media/photos/photo-$next.jpg',
        mimeType: 'image/jpeg',
        byteSize: 20,
      ),
    );
  }

  @override
  Future<Result<List<ObservationMedia>>> recoverPhotos() async =>
      const Success([]);
  @override
  Future<Result<Unit>> commitStaged(Iterable<String> mediaIds) async {
    committed.addAll(mediaIds);
    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit>> discardStaged(String mediaId) async {
    discarded.add(mediaId);
    return const Success(Unit.value);
  }

  @override
  Future<Result<String>> resolveLocalPath(String mediaId) async =>
      Failure(AppFailure(FailureCode.notFound));
  @override
  Future<Result<String>> resolveThumbnailPath(String mediaId) async =>
      Failure(AppFailure(FailureCode.notFound));
}

final class FakeRecorder implements VoiceRecorder {
  final controller = StreamController<RecordingState>.broadcast(sync: true);
  @override
  Stream<RecordingState> get states => controller.stream;
  @override
  Future<Result<Unit>> start() async {
    controller.add(
      const RecordingState(
        phase: RecorderPhase.completed,
        elapsed: Duration(seconds: 2),
        media: ObservationMedia(
          id: 'audio-1',
          kind: MediaKind.audio,
          relativePath: 'media/audio/audio-1.m4a',
          mimeType: 'audio/mp4',
          byteSize: 12,
          durationMs: 2000,
        ),
      ),
    );
    return const Success(Unit.value);
  }

  @override
  Future<Result<ObservationMedia>> stop() async =>
      Failure(AppFailure(FailureCode.conflict));
  @override
  Future<Result<Unit>> cancel() async => const Success(Unit.value);
  @override
  Future<void> dispose() async => controller.close();
}

final class FakeMaintenance implements MediaMaintenance {
  var runs = 0;
  @override
  Future<Result<MediaMaintenanceReport>> run() async {
    runs++;
    return const Success(
      MediaMaintenanceReport(
        deletedPending: 0,
        failedPending: 0,
        deletedOrphans: 0,
      ),
    );
  }
}

final class _Launcher {
  Object? result;
}

Future<_Launcher> _pump(
  WidgetTester tester, {
  required InMemoryObservationRepository store,
  required LocationService location,
  required FakeMedia media,
  required FakeRecorder recorder,
  required FakeMaintenance maintenance,
}) async {
  final launcher = _Launcher();
  await pumpCielo(
    tester,
    Builder(
      builder: (context) => FilledButton(
        onPressed: () async {
          launcher.result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ObservationFormScreen(
                service: store,
                drafts: store,
                clock: () => kNow,
                locationService: location,
                mediaService: media,
                recorder: recorder,
                maintenance: maintenance,
              ),
            ),
          );
        },
        child: const Text('abrir'),
      ),
    ),
    size: const Size(420, 2800),
    wrapInScaffold: false,
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return launcher;
}

void main() {
  testWidgets('GPS, photo and auto-completed audio persist and commit', (
    tester,
  ) async {
    final store = InMemoryObservationRepository();
    final media = FakeMedia();
    final recorder = FakeRecorder();
    final maintenance = FakeMaintenance();
    final launcher = await _pump(
      tester,
      store: store,
      location: FakeLocation(),
      media: media,
      recorder: recorder,
      maintenance: maintenance,
    );
    await tester.tap(find.text('Usar GPS'));
    await tester.pump();
    expect(find.text('GPS · ±7 m'), findsOneWidget);
    await tester.tap(find.text('Galería'));
    await tester.pump();
    await tester.tap(find.text('Grabar voz'));
    await tester.pump();
    expect(find.text('2 s'), findsOneWidget);
    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();
    final saved = launcher.result! as Observation;
    expect(saved.input.location!.source, LocationSource.gps);
    expect(saved.input.location!.capturedAt, DateTime.utc(2026, 11, 23, 2));
    expect(saved.input.media.map((item) => item.id), ['photo-1', 'audio-1']);
    expect(media.committed, containsAll(['photo-1', 'audio-1']));
    expect(maintenance.runs, 1);
  });

  testWidgets(
    'denied GPS does not prevent saving and removing staged photo discards it',
    (tester) async {
      final store = InMemoryObservationRepository();
      final media = FakeMedia();
      final recorder = FakeRecorder();
      final maintenance = FakeMaintenance();
      final launcher = await _pump(
        tester,
        store: store,
        location: FakeLocation(
          failure: AppFailure(FailureCode.permissionDenied),
        ),
        media: media,
        recorder: recorder,
        maintenance: maintenance,
      );
      await tester.tap(find.text('Usar GPS'));
      await tester.pump();
      expect(find.textContaining('permiso'), findsOneWidget);
      await tester.tap(find.text('Galería'));
      await tester.pump();
      await tester.tap(find.byTooltip('Quitar adjunto'));
      await tester.pump();
      expect(media.discarded, ['photo-1']);
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      final saved = launcher.result! as Observation;
      expect(saved.input.location, isNull);
      expect(saved.input.media, isEmpty);
    },
  );
}
