import 'package:cielo_rd/app/cielo_app.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sustituye la prueba del contador de la plantilla: `main.dart` ya no es la
/// app de ejemplo sino CieloRD. Comprueba que la app arranca en el Diario.
void main() {
  testWidgets('CieloRD arranca en el Diario vacío', (WidgetTester tester) async {
    final InMemoryObservationRepository store = InMemoryObservationRepository();
    await tester.pumpWidget(CieloApp(observations: store, observationService: store, drafts: store));
    await tester.pump();
    await tester.pump();
    expect(find.text(CieloStrings.diaryTitle), findsOneWidget);
    expect(find.text(CieloStrings.emptyDiaryTitle), findsOneWidget);
    expect(find.text(CieloStrings.register), findsOneWidget);
  });
}
