import 'package:cielo_rd/app/contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = ObservationValidator();
  ObservationInput published({
    int? durationSeconds,
    ObservationLocation? location,
  }) => ObservationInput(
    title: ' Luna ',
    observedAt: DateTime.utc(2026, 11, 22, 23),
    utcOffsetMinutes: -240,
    category: ObservationCategory.astronomy,
    durationSeconds: durationSeconds,
    location: location,
  );

  test('a draft may be empty but publication requires three fields', () {
    expect(
      validator.validate(ObservationInput(), status: ObservationStatus.draft),
      isA<Success<ObservationInput>>(),
    );
    final result = validator.validate(
      ObservationInput(title: '  '),
      status: ObservationStatus.published,
    ) as Failure<ObservationInput>;
    expect(
      result.failure.fieldErrors.keys,
      containsAll(['title', 'observedAt', 'category']),
    );
  });
  test('publication allows absent duration location description and sky', () {
    final result = validator.validate(
      published(),
      status: ObservationStatus.published,
    ) as Success<ObservationInput>;
    expect(result.value.durationSeconds, isNull);
    expect(result.value.location, isNull);
    expect(result.value.description, isNull);
  });
  test('duration accepts zero but rejects negative values even in drafts', () {
    expect(
      validator.validate(
        published(durationSeconds: 0),
        status: ObservationStatus.published,
      ),
      isA<Success<ObservationInput>>(),
    );
    expect(
      validator.validate(
        ObservationInput(durationSeconds: -1),
        status: ObservationStatus.draft,
      ),
      isA<Failure<ObservationInput>>(),
    );
  });
  test('coordinates require a pair and finite geographic ranges', () {
    for (final location in [
      const ObservationLocation(latitude: 18, source: LocationSource.manual),
      const ObservationLocation(
        latitude: 91,
        longitude: -69,
        source: LocationSource.manual,
      ),
      const ObservationLocation(
        latitude: 18,
        longitude: double.nan,
        source: LocationSource.gps,
      ),
      const ObservationLocation(latitude: 18, longitude: -69),
      const ObservationLocation(placeName: 'Patio', source: LocationSource.gps),
    ]) {
      expect(
        validator.validate(
          published(location: location),
          status: ObservationStatus.published,
        ),
        isA<Failure<ObservationInput>>(),
      );
    }
    expect(
      validator.validate(
        published(
          location: const ObservationLocation(
            placeName: 'Patio',
            source: LocationSource.text,
          ),
        ),
        status: ObservationStatus.published,
      ),
      isA<Success<ObservationInput>>(),
    );
  });
  test('GPS capture time is UTC and only applies to GPS coordinates', () {
    final capturedAt = DateTime.utc(2026, 11, 22, 18, 30);
    expect(
      validator.validate(
        published(
          location: ObservationLocation(
            latitude: 18.4861,
            longitude: -69.9312,
            source: LocationSource.gps,
            capturedAt: capturedAt,
          ),
        ),
        status: ObservationStatus.published,
      ),
      isA<Success<ObservationInput>>(),
    );
    for (final location in [
      ObservationLocation(
        latitude: 18.4861,
        longitude: -69.9312,
        source: LocationSource.manual,
        capturedAt: capturedAt,
      ),
      ObservationLocation(
        latitude: 18.4861,
        longitude: -69.9312,
        source: LocationSource.gps,
        capturedAt: DateTime(2026, 11, 22, 18, 30),
      ),
      ObservationLocation(
        placeName: 'Santo Domingo',
        source: LocationSource.gps,
        capturedAt: capturedAt,
      ),
    ]) {
      final result = validator.validate(
        published(location: location),
        status: ObservationStatus.published,
      ) as Failure<ObservationInput>;
      expect(result.failure.fieldErrors, contains('location.capturedAt'));
    }
  });
  test('time and original offset are paired and elevation is bounded', () {
    for (final input in [
      ObservationInput(observedAt: DateTime.utc(2026)),
      ObservationInput(utcOffsetMinutes: -240),
      ObservationInput(observedAt: DateTime.utc(2026), utcOffsetMinutes: 841),
      ObservationInput(elevationDegrees: 91),
      ObservationInput(elevationDegrees: double.infinity),
    ]) {
      expect(
        validator.validate(input, status: ObservationStatus.draft),
        isA<Failure<ObservationInput>>(),
      );
    }
  });
  test('media limits and audio duration are enforced', () {
    ObservationMedia media(int i, MediaKind kind, {int? duration}) =>
        ObservationMedia(
          id: 'm$i',
          kind: kind,
          relativePath: 'media/m$i',
          mimeType: kind == MediaKind.photo ? 'image/jpeg' : 'audio/mp4',
          byteSize: 10,
          durationMs: duration,
        );
    for (final items in [
      List.generate(6, (i) => media(i, MediaKind.photo)),
      List.generate(4, (i) => media(i, MediaKind.audio, duration: 1000)),
      [media(1, MediaKind.audio, duration: 120001)],
      [media(1, MediaKind.audio)],
      [media(1, MediaKind.photo), media(1, MediaKind.photo)],
    ]) {
      expect(
        validator.validate(
          ObservationInput(media: items),
          status: ObservationStatus.draft,
        ),
        isA<Failure<ObservationInput>>(),
      );
    }
    expect(
      validator.validate(
        ObservationInput(media: [media(1, MediaKind.audio, duration: 120000)]),
        status: ObservationStatus.draft,
      ),
      isA<Success<ObservationInput>>(),
    );
  });
  test(
    'input collections are defensive and nullable fields can be cleared',
    () {
      final media = <ObservationMedia>[];
      final input = ObservationInput(durationSeconds: 10, media: media);
      media.add(
        const ObservationMedia(
          id: 'm',
          kind: MediaKind.photo,
          relativePath: 'media/m',
          mimeType: 'image/jpeg',
          byteSize: 2,
        ),
      );
      expect(input.media, isEmpty);
      expect(() => input.media.clear(), throwsUnsupportedError);
      expect(
        input.copyWith(durationSeconds: () => null).durationSeconds,
        isNull,
      );
      expect(input.durationSeconds, 10);
    },
  );
  test('filters reject inverted intervals and expose exclusive end', () {
    expect(
      () => ObservationFilter(
        from: DateTime.utc(2026, 2),
        until: DateTime.utc(2026, 1),
      ),
      throwsArgumentError,
    );
    final filter = ObservationFilter(
      from: DateTime.utc(2026, 1),
      until: DateTime.utc(2026, 2),
    );
    expect(filter.until, DateTime.utc(2026, 2));
    expect(filter.status, ObservationStatus.published);
  });
  test(
    'profile preserves leading zeroes and settings reject invalid scale',
    () {
      const profile = ObserverProfile(
        firstName: 'Ana',
        lastName: 'Díaz',
        studentId: '00123',
        motto: 'Mirar',
      );
      expect(profile.studentId, '00123');
      expect(() => AppSettings(textScale: double.nan), throwsArgumentError);
      expect(AppSettings().theme, AppTheme.night);
    },
  );
}
