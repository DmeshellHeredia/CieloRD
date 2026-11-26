import 'dart:async';

import 'package:cielo_rd/app/contracts.dart';

/// Referencia fija para todas las pruebas del Diario (hora local).
final DateTime kNow = DateTime(2026, 11, 22, 21, 30);

/// Observación de prueba con valores mínimos válidos del contrato.
Observation obs(
  String id, {
  String title = 'Observación',
  ObservationCategory category = ObservationCategory.astronomy,
  DateTime? observedAtUtc,
  bool noDate = false,
  ObservationStatus status = ObservationStatus.published,
  String? place,
  String? description,
  int offset = -240,
}) {
  final DateTime at = observedAtUtc ?? DateTime.utc(2026, 11, 20, 1, 0);
  return Observation(
    id: id,
    status: status,
    revision: 1,
    createdAt: at,
    updatedAt: at,
    input: ObservationInput(
      title: title,
      observedAt: noDate ? null : at,
      utcOffsetMinutes: noDate ? null : offset,
      category: category,
      description: description,
      location: place == null ? null : ObservationLocation(placeName: place, source: LocationSource.text),
    ),
  );
}

/// Repositorio cuyas respuestas se liberan a mano, para probar respuestas
/// fuera de orden y estados intermedios.
class ControlledRepository implements ObservationRepository {
  final List<(ObservationFilter, Completer<Result<ObservationPage>>)> pending =
      <(ObservationFilter, Completer<Result<ObservationPage>>)>[];

  @override
  Future<Result<ObservationPage>> list({required ObservationFilter filter, String? cursor, int limit = 30}) {
    final Completer<Result<ObservationPage>> completer = Completer<Result<ObservationPage>>();
    pending.add((filter, completer));
    return completer.future;
  }

  @override
  Future<Result<Observation>> getById(String id) async => Failure<Observation>(AppFailure(FailureCode.notFound));

  /// Los conteos responden de inmediato: estas pruebas controlan el orden
  /// de las páginas, no el de los conteos.
  @override
  Future<Result<int>> count({required ObservationFilter filter}) async => const Success<int>(0);

  /// Responde a la primera consulta pendiente que cumpla [where].
  void respond(bool Function(ObservationFilter f) where, Result<ObservationPage> result) {
    final int index = pending.indexWhere(((ObservationFilter, Completer<Result<ObservationPage>>) p) => where(p.$1));
    final (ObservationFilter, Completer<Result<ObservationPage>>) entry = pending.removeAt(index);
    entry.$2.complete(result);
  }

  /// Responde todas las consultas de borradores con una lista vacía.
  void respondDrafts() {
    for (final (ObservationFilter, Completer<Result<ObservationPage>>) p in List.of(pending)) {
      if (p.$1.status == ObservationStatus.draft) {
        pending.remove(p);
        p.$2.complete(Success<ObservationPage>(ObservationPage(items: const <Observation>[])));
      }
    }
  }
}

Success<ObservationPage> page(List<Observation> items, {String? next}) =>
    Success<ObservationPage>(ObservationPage(items: items, nextCursor: next));
