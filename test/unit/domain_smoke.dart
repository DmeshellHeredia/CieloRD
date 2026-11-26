// Standalone fallback while the shared Flutter SDK is occupied.
// Run with the installed Dart binary and --enable-asserts. No pub/build needed.
import 'dart:io';

import 'package:cielo_rd/core/domain/result.dart';
import 'package:cielo_rd/features/observations/domain/observation_input.dart';
import 'package:cielo_rd/features/observations/domain/observation_types.dart';
import 'package:cielo_rd/features/observations/domain/observation_validator.dart';
import 'package:cielo_rd/core/domain/app_failure.dart';
import 'package:cielo_rd/features/observations/domain/observation_filter.dart';
import 'package:cielo_rd/features/profile/domain/profile_repository.dart';
import 'package:cielo_rd/features/settings/domain/settings_repository.dart';

void main() {
  const validator = ObservationValidator();
  assert(
    validator.validate(ObservationInput(), status: ObservationStatus.draft)
        is Success<ObservationInput>,
  );
  assert(
    validator.validate(ObservationInput(), status: ObservationStatus.published)
        is Failure<ObservationInput>,
  );
  final minimal = ObservationInput(
    title: 'Luna',
    observedAt: DateTime.utc(2026),
    utcOffsetMinutes: -240,
    category: ObservationCategory.astronomy,
  );
  assert(
    validator.validate(minimal, status: ObservationStatus.published)
        is Success<ObservationInput>,
  );
  assert(
    validator.validate(
      minimal.copyWith(durationSeconds: () => -1),
      status: ObservationStatus.draft,
    ) is Failure<ObservationInput>,
  );
  assert(
    validator.validate(
      minimal.copyWith(durationSeconds: () => 0),
      status: ObservationStatus.published,
    ) is Success<ObservationInput>,
  );
  assert(minimal.copyWith(category: () => null).category == null);
  assert(minimal.category == ObservationCategory.astronomy);
  final invalid = <ObservationInput>[
    ObservationInput(observedAt: DateTime.utc(2026)),
    ObservationInput(utcOffsetMinutes: -240),
    ObservationInput(observedAt: DateTime.utc(2026), utcOffsetMinutes: 841),
    ObservationInput(elevationDegrees: double.nan),
    ObservationInput(elevationDegrees: -1),
    ObservationInput(elevationDegrees: 91),
    ObservationInput(
      location: const ObservationLocation(
        latitude: 18,
        source: LocationSource.manual,
      ),
    ),
    ObservationInput(
      location: const ObservationLocation(
        latitude: 91,
        longitude: -69,
        source: LocationSource.manual,
      ),
    ),
    ObservationInput(
      location: const ObservationLocation(
        latitude: 18,
        longitude: double.infinity,
        source: LocationSource.gps,
      ),
    ),
    ObservationInput(
      location: const ObservationLocation(latitude: 18, longitude: -69),
    ),
    ObservationInput(
      location: const ObservationLocation(
        placeName: 'Patio',
        source: LocationSource.gps,
      ),
    ),
    ObservationInput(
      location: const ObservationLocation(
        placeName: 'Patio',
        source: LocationSource.text,
        accuracyM: 5,
      ),
    ),
    ObservationInput(subtypeCode: 'Luna llena'),
  ];
  for (final input in invalid) {
    assert(
      validator.validate(input, status: ObservationStatus.draft)
          is Failure<ObservationInput>,
    );
  }
  final photos = List.generate(
    6,
    (i) => ObservationMedia(
      id: 'm$i',
      kind: MediaKind.photo,
      relativePath: 'media/m$i.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
    ),
  );
  final input = ObservationInput(media: photos);
  photos.clear();
  assert(input.media.length == 6);
  assert(
    validator.validate(input, status: ObservationStatus.draft)
        is Failure<ObservationInput>,
  );
  assert(
    validator.validate(
      ObservationInput(
        media: [
          const ObservationMedia(
            id: 'a',
            kind: MediaKind.audio,
            relativePath: 'media/a.m4a',
            mimeType: 'audio/mp4',
            byteSize: 1,
            durationMs: 120000,
          ),
        ],
      ),
      status: ObservationStatus.draft,
    ) is Success<ObservationInput>,
  );
  assert(
    validator.validate(
      ObservationInput(
        media: [
          const ObservationMedia(
            id: 'a',
            kind: MediaKind.audio,
            relativePath: '../a.m4a',
            mimeType: 'audio/mp4',
            byteSize: 1,
            durationMs: 120001,
          ),
        ],
      ),
      status: ObservationStatus.draft,
    ) is Failure<ObservationInput>,
  );
  final fields = {'title': 'required'};
  final failure = AppFailure(FailureCode.validation, fieldErrors: fields);
  fields.clear();
  assert(failure.fieldErrors['title'] == 'required');
  assert(
    const Success(7).fold(success: (value) => value * 2, failure: (_) => -1) ==
        14,
  );
  assert(
    Failure<int>(failure).fold(
      success: (_) => false,
      failure: (error) => error.code == FailureCode.validation,
    ),
  );
  assert(ObservationFilter().status == ObservationStatus.published);
  assert(const ObserverProfile(studentId: '00123').studentId == '00123');
  assert(AppSettings().theme == AppTheme.night);
  stdout.writeln(
    '30 standalone domain assertions passed. Flutter suite still required.',
  );
}
