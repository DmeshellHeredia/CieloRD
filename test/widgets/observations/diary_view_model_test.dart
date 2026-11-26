import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/observations/presentation/diary/diary_criteria.dart';
import 'package:cielo_rd/features/observations/presentation/diary/diary_view_model.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'diary_fixtures.dart';

void main() {
  List<Observation> many(int n) => <Observation>[
    for (int i = 0; i < n; i++)
      obs(
        'o${i.toString().padLeft(2, '0')}',
        // La búsqueda cubre título, descripción y lugar (no el id).
        title: 'Paso o${i.toString().padLeft(2, '0')}',
        observedAtUtc: DateTime.utc(2026, 11, 20).subtract(Duration(hours: i)),
      ),
  ];

  DiaryViewModel vmFor(ObservationRepository repo, {int pageSize = 30}) =>
      DiaryViewModel(observations: repo, clock: () => kNow, pageSize: pageSize);

  testWidgets('carga inicial: publicadas, fase ready y conteo de borradores', (
    WidgetTester tester,
  ) async {
    final InMemoryObservationRepository repo = InMemoryObservationRepository(
      observations: <Observation>[
        ...many(3),
        obs('d1', status: ObservationStatus.draft),
      ],
    );
    final DiaryViewModel vm = vmFor(repo);
    addTearDown(vm.dispose);
    expect(vm.phase, DiaryPhase.loading);
    await vm.load();
    expect(vm.phase, DiaryPhase.ready);
    expect(vm.items, hasLength(3));
    expect(vm.draftCount, 1);
    final ObservationFilter main = repo.receivedFilters.firstWhere(
      (ObservationFilter f) => f.status != ObservationStatus.draft,
    );
    expect(main.status, ObservationStatus.published);
    expect(main.query, isEmpty);
  });

  testWidgets('la búsqueda espera el retardo y reinicia el cursor', (
    WidgetTester tester,
  ) async {
    final InMemoryObservationRepository repo = InMemoryObservationRepository(
      observations: many(5),
    );
    final DiaryViewModel vm = vmFor(repo);
    addTearDown(vm.dispose);
    await vm.load();
    final int before = repo.listCalls;
    final int countsBefore = repo.countCalls;

    vm.setQuery('o0');
    vm.setQuery('o01');
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.listCalls, before, reason: 'aún dentro del retardo');
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      repo.listCalls,
      before + 1,
      reason: 'una consulta paginada principal',
    );
    expect(
      repo.countCalls,
      countsBefore + 2,
      reason: 'conteos exactos de resultados y borradores',
    );
    final ObservationFilter main = repo.receivedFilters.lastWhere(
      (ObservationFilter f) => f.status == ObservationStatus.published,
    );
    expect(main.query, 'o01');
    expect(vm.items.map((Observation o) => o.id), <String>['o01']);
  });

  testWidgets(
    'rango de fechas se convierte a instantes locales [inicio, fin)',
    (WidgetTester tester) async {
      final InMemoryObservationRepository repo =
          InMemoryObservationRepository();
      final DiaryViewModel vm = vmFor(repo);
      addTearDown(vm.dispose);
      vm.updateCriteria(
        const DiaryCriteria(
          dateRange: DiaryDateRange.last7Days,
          category: ObservationCategory.birds,
          place: ' Samaná ',
        ),
      );
      await tester.pump();
      final ObservationFilter f = repo.receivedFilters.lastWhere(
        (ObservationFilter f) => f.status == ObservationStatus.published,
      );
      expect(f.from, DateTime(2026, 11, 16).toUtc());
      expect(f.until, DateTime(2026, 11, 23).toUtc());
      expect(f.category, ObservationCategory.birds);
      expect(f.place, 'Samaná');
    },
  );

  test('cada rango rápido es válido para ObservationFilter', () {
    for (final DiaryDateRange r in DiaryDateRange.values) {
      expect(
        () =>
            DiaryCriteria(dateRange: r)
                .toFilter(DateTime(2026, 12, 31, 23, 59)),
        returnsNormally,
      );
    }
    expect(DiaryDateRange.thisMonth.resolve(kNow), (
      DateTime(2026, 11),
      DateTime(2026, 12),
    ));
    expect(DiaryDateRange.today.resolve(kNow), (
      DateTime(2026, 11, 22),
      DateTime(2026, 11, 23),
    ));
  });

  testWidgets('pagina con loadMore hasta agotar el cursor', (
    WidgetTester tester,
  ) async {
    final DiaryViewModel vm = vmFor(
      InMemoryObservationRepository(observations: many(5)),
      pageSize: 2,
    );
    addTearDown(vm.dispose);
    await vm.load();
    expect(vm.items, hasLength(2));
    expect(vm.hasMore, isTrue);
    await vm.loadMore();
    await vm.loadMore();
    expect(vm.items.map((Observation o) => o.id), <String>[
      'o00',
      'o01',
      'o02',
      'o03',
      'o04',
    ]);
    expect(vm.hasMore, isFalse);
  });

  testWidgets('descarta respuestas que llegan fuera de orden', (
    WidgetTester tester,
  ) async {
    final ControlledRepository repo = ControlledRepository();
    final DiaryViewModel vm = vmFor(repo);
    addTearDown(vm.dispose);
    vm.load();
    vm.setCategory(ObservationCategory.birds);
    await tester.pump();
    repo.respondDrafts();
    // Llega primero la respuesta nueva (aves) y después la vieja (todas).
    repo.respond(
      (ObservationFilter f) => f.category == ObservationCategory.birds,
      page(<Observation>[obs('ave')]),
    );
    await tester.pump();
    repo.respond(
      (ObservationFilter f) => f.category == null,
      page(<Observation>[obs('vieja')]),
    );
    await tester.pump();
    expect(vm.items.map((Observation o) => o.id), <String>['ave']);
  });

  testWidgets('un fallo deja la fase failure y reintentar recupera', (
    WidgetTester tester,
  ) async {
    final InMemoryObservationRepository repo = InMemoryObservationRepository(
      observations: many(2),
    )..scheduledListFailures.add(AppFailure(FailureCode.persistence));
    final DiaryViewModel vm = vmFor(repo);
    addTearDown(vm.dispose);
    await vm.load();
    expect(vm.phase, DiaryPhase.failure);
    expect(vm.failure!.code, FailureCode.persistence);
    await vm.load();
    expect(vm.phase, DiaryPhase.ready);
    expect(vm.items, hasLength(2));
  });

  test('contador de filtros activos y criterios refinados', () {
    expect(DiaryCriteria.initial.activeFilterCount, 0);
    expect(DiaryCriteria.initial.isRefined, isFalse);
    expect(const DiaryCriteria(query: 'x').isRefined, isTrue);
    expect(
      const DiaryCriteria(
        dateRange: DiaryDateRange.today,
        category: ObservationCategory.other,
        place: 'Baní',
        statusView: DiaryStatusView.drafts,
      ).activeFilterCount,
      4,
    );
  });
}
