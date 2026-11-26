import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'diary_fixtures.dart';

/// El fake debe respetar la semántica publicada en docs/C0_CONTRACTS.md, o
/// las pruebas de la UI darían una falsa seguridad.
void main() {
  final List<Observation> data = <Observation>[
    obs('a', title: 'Leónidas en Valle Nuevo', place: 'Constanza', observedAtUtc: DateTime.utc(2026, 11, 17, 6)),
    obs('b', title: 'Halo solar', category: ObservationCategory.atmospheric, place: 'Santiago',
        observedAtUtc: DateTime.utc(2026, 11, 10, 15)),
    obs('c', title: 'Garzas', category: ObservationCategory.birds, description: 'Cerca de la laguna',
        observedAtUtc: DateTime.utc(2026, 10, 1, 22)),
    obs('d', title: 'Borrador', status: ObservationStatus.draft, noDate: true),
    obs('e', title: 'Mismo instante', observedAtUtc: DateTime.utc(2026, 11, 17, 6)),
  ];

  Future<List<String>> ids(ObservationFilter filter, {int limit = 30}) async {
    final Result<ObservationPage> r = await InMemoryObservationRepository(observations: data).list(
      filter: filter,
      limit: limit,
    );
    return (r as Success<ObservationPage>).value.items.map((Observation o) => o.id).toList();
  }

  test('por defecto solo publicadas, fecha DESC y luego id DESC', () async {
    expect(await ids(ObservationFilter()), <String>['e', 'a', 'b', 'c']);
  });

  test('status null incluye ambos; sin fecha al final', () async {
    expect(await ids(ObservationFilter(status: null)), <String>['e', 'a', 'b', 'c', 'd']);
  });

  test('búsqueda sin mayúsculas ni acentos en título, descripción y lugar', () async {
    expect(await ids(ObservationFilter(query: 'LEONIDAS')), <String>['a']);
    expect(await ids(ObservationFilter(query: 'laguna')), <String>['c']);
    expect(await ids(ObservationFilter(query: 'santiago')), <String>['b']);
  });

  test('rango: from inclusivo, until exclusivo', () async {
    final DateTime t = DateTime.utc(2026, 11, 17, 6);
    expect(await ids(ObservationFilter(from: t)), <String>['e', 'a']);
    expect(await ids(ObservationFilter(until: t)), <String>['b', 'c']);
  });

  test('categoría y lugar se combinan con AND', () async {
    expect(await ids(ObservationFilter(category: ObservationCategory.atmospheric, place: 'santi')), <String>['b']);
    expect(await ids(ObservationFilter(category: ObservationCategory.birds, place: 'santi')), isEmpty);
  });

  test('paginación con cursor ligado al filtro', () async {
    final InMemoryObservationRepository repo = InMemoryObservationRepository(observations: data);
    final ObservationFilter f = ObservationFilter();
    final ObservationPage first = (await repo.list(filter: f, limit: 3) as Success<ObservationPage>).value;
    expect(first.items.map((Observation o) => o.id), <String>['e', 'a', 'b']);
    expect(first.nextCursor, isNotNull);
    final ObservationPage second =
        (await repo.list(filter: f, cursor: first.nextCursor, limit: 3) as Success<ObservationPage>).value;
    expect(second.items.map((Observation o) => o.id), <String>['c']);
    expect(second.nextCursor, isNull);

    final Result<ObservationPage> wrong =
        await repo.list(filter: ObservationFilter(query: 'x'), cursor: first.nextCursor);
    expect((wrong as Failure<ObservationPage>).failure.code, FailureCode.validation);
  });

  test('límite fuera de 1..100 y getById inexistente', () async {
    final InMemoryObservationRepository repo = InMemoryObservationRepository(observations: data);
    expect(await repo.list(filter: ObservationFilter(), limit: 0), isA<Failure<ObservationPage>>());
    final Result<Observation> missing = await repo.getById('zzz');
    expect((missing as Failure<Observation>).failure.code, FailureCode.notFound);
    expect(await repo.getById('a'), isA<Success<Observation>>());
  });
}
