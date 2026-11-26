import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/observations/presentation/detail/observation_detail_screen.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';
import 'diary_fixtures.dart';

Observation _full() => Observation(
      id: 'full',
      status: ObservationStatus.published,
      revision: 2,
      createdAt: DateTime.utc(2026, 11, 17, 6),
      updatedAt: DateTime.utc(2026, 11, 17, 7),
      input: ObservationInput(
        title: 'Leónidas en Valle Nuevo',
        observedAt: DateTime.utc(2026, 11, 17, 6),
        utcOffsetMinutes: -240,
        category: ObservationCategory.astronomy,
        skyCondition: SkyCondition.saharanDust,
        description: 'Cuarenta meteoros por hora.',
        durationSeconds: 90,
        direction: CardinalDirection.northEast,
        elevationDegrees: 45,
        location: const ObservationLocation(
          placeName: 'Constanza',
          latitude: 18.7928,
          longitude: -70.6036,
          source: LocationSource.gps,
          accuracyM: 12,
        ),
      ),
    );

Future<void> pumpDetail(WidgetTester tester, ObservationRepository repo, String id, {Observation? initial}) async {
  await pumpCielo(
    tester,
    ObservationDetailScreen(observationId: id, observations: repo, initial: initial),
    wrapInScaffold: false,
    // Pantalla alta: la lista es perezosa y así se construyen todos los datos.
    size: const Size(360, 2000),
  );
  await tester.pump();
}

void main() {
  testWidgets('muestra todos los datos registrados', (WidgetTester tester) async {
    await pumpDetail(tester, InMemoryObservationRepository(observations: <Observation>[_full()]), 'full');
    expect(find.text('Leónidas en Valle Nuevo'), findsOneWidget);
    expect(find.text(CieloStrings.categoryAstronomy), findsOneWidget);
    expect(find.text('martes, 17 de noviembre de 2026, 2:00 a. m.'), findsOneWidget);
    expect(find.text(CieloStrings.skySaharanDust), findsOneWidget);
    expect(find.text('1 min 30 s'), findsOneWidget);
    expect(find.text(CieloStrings.directionNE), findsOneWidget);
    expect(find.text(CieloStrings.elevation(45)), findsOneWidget);
    expect(find.text('Constanza'), findsOneWidget);
    expect(find.textContaining('18.7928°'), findsOneWidget);
    expect(find.text('Cuarenta meteoros por hora.'), findsOneWidget);
    expect(find.text(CieloStrings.noMedia), findsOneWidget);
  });

  testWidgets('TalkBack lee cada dato con su etiqueta', (WidgetTester tester) async {
    await pumpDetail(tester, InMemoryObservationRepository(observations: <Observation>[_full()]), 'full');
    expect(find.bySemanticsLabel('${CieloStrings.durationLabel}: 1 minuto y 30 segundos'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Leónidas en Valle Nuevo')),
      isSemantics(isHeader: true),
    );
  });

  testWidgets('si ya no existe, lo explica y ofrece volver', (WidgetTester tester) async {
    await pumpDetail(tester, InMemoryObservationRepository(), 'x', initial: obs('x', title: 'Borrada'));
    await tester.pump();
    expect(find.text(CieloStrings.errorNotFound), findsOneWidget);
    expect(find.text(CieloStrings.back), findsOneWidget);
    expect(find.text(CieloStrings.retry), findsNothing);
  });

  testWidgets('un fallo al refrescar conserva los datos y avisa', (WidgetTester tester) async {
    final InMemoryObservationRepository repo = InMemoryObservationRepository(observations: <Observation>[_full()])
      ..scheduledFailures.add(AppFailure(FailureCode.persistence));
    await pumpDetail(tester, repo, 'full', initial: _full());
    await tester.pump();
    expect(find.text('Leónidas en Valle Nuevo'), findsOneWidget);
    expect(find.text(CieloStrings.failurePersistence), findsOneWidget);
    await tester.tap(find.text(CieloStrings.retry));
    await tester.pump();
    await tester.pump();
    expect(find.text(CieloStrings.failurePersistence), findsNothing);
  });

  testWidgets('borrador sin título ni fecha', (WidgetTester tester) async {
    final Observation draft = obs('d', title: '  ', status: ObservationStatus.draft, noDate: true);
    await pumpDetail(tester, InMemoryObservationRepository(observations: <Observation>[draft]), 'd');
    expect(find.text(CieloStrings.untitled), findsOneWidget);
    expect(find.text(CieloStrings.draft), findsOneWidget);
    expect(find.text(CieloStrings.noDate), findsOneWidget);
    expect(find.text(CieloStrings.noLocation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin desbordes con texto al 200 %', (WidgetTester tester) async {
    await pumpCielo(
      tester,
      ObservationDetailScreen(
        observationId: 'full',
        observations: InMemoryObservationRepository(observations: <Observation>[_full()]),
      ),
      wrapInScaffold: false,
      textScale: 2.0,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
  });
}
