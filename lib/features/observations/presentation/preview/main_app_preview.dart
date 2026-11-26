import 'package:flutter/widgets.dart';

import '../../../../app/cielo_app.dart';
import 'in_memory_observation_repository.dart';
import 'sample_observations.dart';

/// App completa con datos en memoria (sin SQLite): útil en escritorio o web.
///
/// `flutter run -t lib/features/observations/presentation/preview/main_app_preview.dart`
void main() {
  final InMemoryObservationRepository store =
      InMemoryObservationRepository(observations: sampleObservations(now: DateTime.now()));
  runApp(CieloApp(observations: store, observationService: store, drafts: store));
}
