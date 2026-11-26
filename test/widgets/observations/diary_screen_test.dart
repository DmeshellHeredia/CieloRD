import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/observations/presentation/detail/observation_detail_screen.dart';
import 'package:cielo_rd/features/observations/presentation/diary/diary_screen.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:cielo_rd/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';
import 'diary_fixtures.dart';

List<Observation> _data() => <Observation>[
  obs(
    'a',
    title: 'Leónidas en Valle Nuevo',
    place: 'Constanza',
    observedAtUtc: DateTime.utc(2026, 11, 17, 6),
  ),
  obs(
    'b',
    title: 'Halo solar',
    category: ObservationCategory.atmospheric,
    place: 'Santiago',
    observedAtUtc: DateTime.utc(2026, 11, 10, 15),
  ),
  obs(
    'c',
    title: 'Garzas al atardecer',
    category: ObservationCategory.birds,
    place: 'Laguna de Oviedo',
    observedAtUtc: DateTime.utc(2026, 10, 1, 22),
  ),
  obs(
    'd',
    title: 'Bólido verde',
    status: ObservationStatus.draft,
    observedAtUtc: DateTime.utc(2026, 11, 21, 3),
  ),
];

Future<void> pumpDiary(
  WidgetTester tester,
  ObservationRepository repo, {
  Future<bool?> Function(BuildContext, Observation)? onOpen,
  Future<bool?> Function(BuildContext)? onCreate,
  int pageSize = 30,
  double textScale = 1.0,
  // Pantalla alta: estas pruebas verifican comportamiento, no el pliegue.
  // El diseño a 360 × 780 dp se cubre en las pruebas de desbordes y en
  // test/widgets/accessibility/diary_accessibility_test.dart.
  Size size = const Size(360, 1400),
}) async {
  await pumpCielo(
    tester,
    DiaryScreen(
      observations: repo,
      clock: () => kNow,
      onOpenObservation: onOpen,
      onCreateObservation: onCreate,
      pageSize: pageSize,
    ),
    wrapInScaffold: false,
    textScale: textScale,
    size: size,
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('muestra esqueleto mientras carga', (WidgetTester tester) async {
    final InMemoryObservationRepository repo = InMemoryObservationRepository(
      observations: _data(),
      latency: const Duration(milliseconds: 200),
    );
    await pumpCielo(
      tester,
      DiaryScreen(observations: repo, clock: () => kNow),
      wrapInScaffold: false,
    );
    expect(find.byType(CieloSkeletonList), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.byType(CieloSkeletonList), findsNothing);
    expect(find.text('Leónidas en Valle Nuevo'), findsOneWidget);
  });

  testWidgets('lista agrupada por mes con conteo; los borradores no aparecen', (
    WidgetTester tester,
  ) async {
    await pumpDiary(
      tester,
      InMemoryObservationRepository(observations: _data()),
    );
    expect(find.text('Noviembre de 2026'), findsOneWidget);
    expect(find.text('Octubre de 2026'), findsOneWidget);
    expect(find.text(CieloStrings.observationsCount(3)), findsOneWidget);
    expect(find.text('Bólido verde'), findsNothing);
    // Hora local con el desplazamiento original (UTC−4): 06:00 UTC → 2:00 a. m.
    expect(find.text('mar 17 nov, 2:00 a. m.'), findsOneWidget);
  });

  testWidgets('diario vacío invita a registrar', (WidgetTester tester) async {
    int created = 0;
    await pumpDiary(
      tester,
      InMemoryObservationRepository(),
      onCreate: (_) async {
        created++;
        return false;
      },
    );
    expect(find.text(CieloStrings.emptyDiaryTitle), findsOneWidget);
    await tester.tap(find.text(CieloStrings.emptyDiaryAction));
    await tester.tap(find.text(CieloStrings.register));
    expect(created, 2);
  });

  testWidgets('sin onCreateObservation no hay botón Registrar', (
    WidgetTester tester,
  ) async {
    await pumpDiary(tester, InMemoryObservationRepository());
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text(CieloStrings.emptyDiaryAction), findsNothing);
  });

  testWidgets('la búsqueda ignora acentos; sin resultados permite limpiar', (
    WidgetTester tester,
  ) async {
    await pumpDiary(
      tester,
      InMemoryObservationRepository(observations: _data()),
    );
    await tester.enterText(find.byType(TextField), 'leonidas');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Leónidas en Valle Nuevo'), findsOneWidget);
    expect(find.text('Halo solar'), findsNothing);

    await tester.enterText(find.byType(TextField), 'perseidas');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text(CieloStrings.noResultsTitle), findsOneWidget);
    expect(
      find.text(CieloStrings.noResultsMessage('perseidas')),
      findsOneWidget,
    );

    await tester.tap(find.text(CieloStrings.clearFilters));
    await tester.pump();
    await tester.pump();
    expect(find.text('Halo solar'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('chip de categoría filtra y se desmarca', (
    WidgetTester tester,
  ) async {
    await pumpDiary(
      tester,
      InMemoryObservationRepository(observations: _data()),
    );
    // La fila de categorías se desplaza en horizontal: se lleva "Aves" a la vista.
    await tester.ensureVisible(find.text(CieloStrings.categoryBirds));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CieloStrings.categoryBirds));
    await tester.pump();
    await tester.pump();
    expect(find.text('Garzas al atardecer'), findsOneWidget);
    expect(find.text('Halo solar'), findsNothing);
    expect(find.text(CieloStrings.filtersWithCount(1)), findsOneWidget);

    await tester.ensureVisible(find.text(CieloStrings.categoryBirds));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CieloStrings.categoryBirds));
    await tester.pump();
    await tester.pump();
    expect(find.text('Halo solar'), findsOneWidget);
  });

  testWidgets('panel de filtros: fecha y lugar con chips removibles', (
    WidgetTester tester,
  ) async {
    final InMemoryObservationRepository repo = InMemoryObservationRepository(
      observations: _data(),
    );
    await pumpDiary(tester, repo);
    await tester.tap(find.byType(CieloFilterButton));
    await tester.pumpAndSettle();
    expect(find.text(CieloStrings.showResults), findsOneWidget);

    await tester.tap(find.text(CieloStrings.dateThisMonth));
    await tester.enterText(
      find.widgetWithText(TextField, CieloStrings.placeHint),
      'constanza',
    );
    await tester.tap(find.text(CieloStrings.showResults));
    await tester.pumpAndSettle();

    expect(find.text('Leónidas en Valle Nuevo'), findsOneWidget);
    expect(find.text('Halo solar'), findsNothing);
    expect(
      find.bySemanticsLabel(
        CieloStrings.removeFilter(CieloStrings.dateThisMonth),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        CieloStrings.removeFilter(CieloStrings.placeFilter('constanza')),
      ),
      findsOneWidget,
    );
    expect(find.text(CieloStrings.filtersWithCount(2)), findsOneWidget);
    final ObservationFilter applied = repo.receivedFilters.lastWhere(
      (ObservationFilter f) => f.status == ObservationStatus.published,
    );
    expect(applied.from, DateTime(2026, 11).toUtc());
    expect(applied.place, 'constanza');

    await tester.tap(
      find.bySemanticsLabel(
        CieloStrings.removeFilter(CieloStrings.placeFilter('constanza')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Halo solar'), findsOneWidget);
    expect(find.text(CieloStrings.filtersWithCount(1)), findsOneWidget);
  });

  testWidgets('cerrar el panel sin aplicar no cambia nada', (
    WidgetTester tester,
  ) async {
    final InMemoryObservationRepository repo = InMemoryObservationRepository(
      observations: _data(),
    );
    await pumpDiary(tester, repo);
    final int calls = repo.listCalls;
    await tester.tap(find.byType(CieloFilterButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CieloStrings.dateToday));
    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();
    expect(repo.listCalls, calls);
    expect(find.text(CieloStrings.filters), findsOneWidget);
  });

  testWidgets('aviso de borradores lleva a la vista de borradores', (
    WidgetTester tester,
  ) async {
    await pumpDiary(
      tester,
      InMemoryObservationRepository(observations: _data()),
    );
    expect(find.text(CieloStrings.draftsPending(1)), findsOneWidget);
    await tester.tap(find.text(CieloStrings.viewDrafts));
    await tester.pump();
    await tester.pump();
    expect(find.text('Bólido verde'), findsOneWidget);
    expect(find.text('Halo solar'), findsNothing);
    expect(find.text(CieloStrings.draft), findsWidgets);
    expect(find.text(CieloStrings.viewDrafts), findsNothing);
  });

  testWidgets('error de carga con reintento', (WidgetTester tester) async {
    final InMemoryObservationRepository repo = InMemoryObservationRepository(
      observations: _data(),
    )..scheduledListFailures.add(AppFailure(FailureCode.persistence));
    await pumpDiary(tester, repo);
    expect(find.text(CieloStrings.failurePersistence), findsOneWidget);
    await tester.tap(find.text(CieloStrings.retry));
    await tester.pump();
    await tester.pump();
    expect(find.text('Halo solar'), findsOneWidget);
  });

  testWidgets('tocar una tarjeta usa onOpenObservation con la observación', (
    WidgetTester tester,
  ) async {
    Observation? opened;
    await pumpDiary(
      tester,
      InMemoryObservationRepository(observations: _data()),
      onOpen: (BuildContext context, Observation o) async {
        opened = o;
        return false;
      },
    );
    await tester.tap(find.text('Halo solar'));
    await tester.pump();
    expect(opened?.id, 'b');
  });

  testWidgets('sin callback navega al detalle con transición y vuelve', (
    WidgetTester tester,
  ) async {
    await pumpDiary(
      tester,
      InMemoryObservationRepository(observations: _data()),
    );
    await tester.tap(find.text('Halo solar'));
    await tester.pumpAndSettle();
    expect(find.byType(ObservationDetailScreen), findsOneWidget);
    expect(find.text(CieloStrings.detailTitle), findsOneWidget);
    expect(find.text('Santiago'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ObservationDetailScreen), findsNothing);
    expect(find.text(CieloStrings.diaryTitle), findsOneWidget);
  });

  testWidgets('carga más páginas al desplazarse', (WidgetTester tester) async {
    final InMemoryObservationRepository repo = InMemoryObservationRepository(
      observations: <Observation>[
        for (int i = 0; i < 12; i++)
          obs(
            'p${i.toString().padLeft(2, '0')}',
            title: 'Paso $i',
            observedAtUtc: DateTime.utc(
              2026,
              11,
              20,
            ).subtract(Duration(hours: i)),
          ),
      ],
    );
    await pumpDiary(tester, repo, pageSize: 5);
    expect(find.text(CieloStrings.observationsCount(12)), findsOneWidget);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -3000),
      3000,
    );
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -3000),
      3000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Paso 11'), findsOneWidget);
    expect(find.text(CieloStrings.endOfDiary), findsOneWidget);
  });

  forEachThemeAndScale('sin desbordes ni excepciones', (
    WidgetTester t,
    v,
    double s,
  ) async {
    await pumpCielo(
      t,
      DiaryScreen(
        observations: InMemoryObservationRepository(observations: _data()),
        clock: () => kNow,
        onCreateObservation: (_) async => false,
      ),
      wrapInScaffold: false,
      variant: v,
      textScale: s,
    );
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
