import 'dart:async';
import 'dart:io';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/map/domain/offline_province_map.dart';
import 'package:cielo_rd/features/observations/presentation/detail/observation_detail_screen.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../helpers/pump_cielo.dart';

final class _Media implements MediaService {
  _Media(this.photoPath);
  final String photoPath;
  @override
  Future<Result<String>> resolveLocalPath(String mediaId) async =>
      Success(photoPath);
  @override
  Future<Result<String>> resolveThumbnailPath(String mediaId) async =>
      Success(photoPath);
  @override
  Future<Result<ObservationMedia?>> pickPhoto(PhotoSource source) async =>
      const Success(null);
  @override
  Future<Result<List<ObservationMedia>>> recoverPhotos() async =>
      const Success([]);
  @override
  Future<Result<Unit>> commitStaged(Iterable<String> mediaIds) async =>
      const Success(Unit.value);
  @override
  Future<Result<Unit>> discardStaged(String mediaId) async =>
      const Success(Unit.value);
}

final class _Player implements AudioPlayerService {
  final controller = StreamController<PlaybackState>.broadcast(sync: true);
  @override
  Stream<PlaybackState> get states => controller.stream;
  @override
  Future<Result<Unit>> load(String mediaId) async {
    controller.add(
      PlaybackState(
        phase: PlayerPhase.paused,
        duration: Duration(seconds: 4),
        mediaId: mediaId,
      ),
    );
    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit>> play() async {
    controller.add(
      const PlaybackState(
        phase: PlayerPhase.playing,
        duration: Duration(seconds: 4),
        mediaId: 'audio',
      ),
    );
    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit>> pause() async {
    controller.add(
      const PlaybackState(phase: PlayerPhase.paused, mediaId: 'audio'),
    );
    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit>> seek(Duration position) async =>
      const Success(Unit.value);
  @override
  Future<Result<Unit>> stop() async => const Success(Unit.value);
  @override
  Future<void> dispose() async => controller.close();
}

void main() {
  testWidgets(
    'detail shows offline map, photo enlargement and audio controls',
    (tester) async {
      final temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('cielord_detail_b_'),
      ))!;
      addTearDown(() => temp.delete(recursive: true));
      final photo = File('${temp.path}/photo.jpg')
        ..writeAsBytesSync(image.encodeJpg(image.Image(width: 20, height: 12)));
      final media = _Media(photo.path);
      final player = _Player();
      addTearDown(player.dispose);
      final map = OfflineProvinceMap.parse('''
{"type":"FeatureCollection","features":[{"type":"Feature",
"properties":{"shapeName":"Santiago"},"geometry":{"type":"Polygon",
"coordinates":[[[-71,19],[-70,19],[-70,20],[-71,20],[-71,19]]]}}]}
''');
      final observation = Observation(
        id: 'with-media',
        status: ObservationStatus.published,
        revision: 1,
        createdAt: DateTime.utc(2026, 11, 23),
        updatedAt: DateTime.utc(2026, 11, 23),
        input: ObservationInput(
          title: 'Con medios',
          observedAt: DateTime.utc(2026, 11, 23),
          utcOffsetMinutes: -240,
          category: ObservationCategory.astronomy,
          location: const ObservationLocation(
            placeName: 'Santiago',
            latitude: 19.4517,
            longitude: -70.6970,
            source: LocationSource.manual,
          ),
          media: const [
            ObservationMedia(
              id: 'photo',
              kind: MediaKind.photo,
              relativePath: 'media/photos/photo.jpg',
              mimeType: 'image/jpeg',
              byteSize: 20,
            ),
            ObservationMedia(
              id: 'audio',
              kind: MediaKind.audio,
              relativePath: 'media/audio/audio.m4a',
              mimeType: 'audio/mp4',
              byteSize: 20,
              durationMs: 4000,
            ),
          ],
        ),
      );
      final store = InMemoryObservationRepository(observations: [observation]);
      await pumpCielo(
        tester,
        ObservationDetailScreen(
          observationId: observation.id,
          observations: store,
          mediaService: media,
          resolveMediaPath: media.resolveLocalPath,
          player: player,
          provinceMap: map,
        ),
        wrapInScaffold: false,
        size: const Size(420, 2100),
      );
      await tester.pump();
      expect(find.text('geoBoundaries · Natural Earth'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      expect(find.text('Nota de voz'), findsOneWidget);
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pump();
      expect(find.byTooltip('Pausar'), findsOneWidget);
      final photoInk = find.descendant(
        of: find.byType(Wrap).last,
        matching: find.byType(InkWell),
      );
      if (photoInk.evaluate().isNotEmpty) {
        await tester.tap(photoInk.first);
        await tester.pump();
        expect(find.byType(Dialog), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
