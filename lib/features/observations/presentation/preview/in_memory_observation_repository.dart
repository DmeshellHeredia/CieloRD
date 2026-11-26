import 'dart:async';
import 'dart:collection';

import '../../../../app/contracts.dart';
import '../../../../core/text/search_normalizer.dart';

/// Implementación en memoria de [ObservationRepository], [ObservationService]
/// y [DraftService] para la vista previa de la UI y las pruebas de widgets.
/// **No** es la persistencia real: la app usa `SqliteObservationStore`, cuyas
/// pruebas corren sobre SQLite real (test/repositories).
///
/// Escrituras: valida con [ObservationValidator] y aplica concurrencia por
/// revisión igual que SQLite (`notFound`, `conflict`).
///
/// Respeta la semántica publicada en `docs/C0_CONTRACTS.md`:
/// filtros AND; `from` inclusivo y `until` exclusivo; búsqueda en título,
/// descripción y lugar sin distinguir mayúsculas ni acentos; orden por
/// fecha DESC con nulos al final y luego id DESC; límite 1..100; cursor
/// opaco ligado al filtro; ID inexistente → `notFound`; `count` exacto.
class InMemoryObservationRepository
    implements ObservationRepository, ObservationService, DraftService {
  InMemoryObservationRepository({
    Iterable<Observation> observations = const <Observation>[],
    this.latency = Duration.zero,
    this.validator = const ObservationValidator(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    for (final Observation o in observations) {
      _byId[o.id] = o;
    }
  }

  final Map<String, Observation> _byId = <String, Observation>{};
  final ObservationValidator validator;
  final DateTime Function() _clock;
  int _sequence = 0;

  /// Retardo artificial para ver estados de carga en la vista previa.
  Duration latency;

  /// Fallos programados: cada llamada consume el primero si existe.
  final Queue<AppFailure> scheduledFailures = Queue<AppFailure>();

  /// Fallos dirigidos a lecturas de lista. Evitan que una prueba dependa del
  /// orden interno en que la UI ejecuta `list` y `count` en paralelo.
  final Queue<AppFailure> scheduledListFailures = Queue<AppFailure>();

  /// Fallos dirigidos a conteos.
  final Queue<AppFailure> scheduledCountFailures = Queue<AppFailure>();

  /// Filtros recibidos, en orden, para verificar la traducción de la UI.
  final List<ObservationFilter> receivedFilters = <ObservationFilter>[];

  int listCalls = 0;
  int countCalls = 0;

  void put(Observation observation) => _byId[observation.id] = observation;
  void remove(String id) => _byId.remove(id);
  int get length => _byId.length;

  @override
  Future<Result<ObservationPage>> list({
    required ObservationFilter filter,
    String? cursor,
    int limit = 30,
  }) async {
    listCalls++;
    receivedFilters.add(filter);
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (scheduledListFailures.isNotEmpty) {
      return Failure<ObservationPage>(scheduledListFailures.removeFirst());
    }
    if (scheduledFailures.isNotEmpty) {
      return Failure<ObservationPage>(scheduledFailures.removeFirst());
    }
    if (limit < 1 || limit > 100) {
      return Failure<ObservationPage>(
        AppFailure(FailureCode.validation, message: 'limit 1..100'),
      );
    }

    final List<Observation> matches =
        _byId.values.where((Observation o) => _matches(o, filter)).toList()
          ..sort(_compare);

    int start = 0;
    if (cursor != null) {
      final int? decoded = _decodeCursor(cursor, filter);
      if (decoded == null) {
        return Failure<ObservationPage>(
          AppFailure(FailureCode.validation, message: 'invalid cursor'),
        );
      }
      start = decoded;
    }
    final int end = (start + limit).clamp(0, matches.length);
    final List<Observation> page = start >= matches.length
        ? <Observation>[]
        : matches.sublist(start, end);
    final String? next = end < matches.length
        ? _encodeCursor(end, filter)
        : null;
    return Success<ObservationPage>(
      ObservationPage(items: page, nextCursor: next),
    );
  }

  @override
  Future<Result<int>> count({required ObservationFilter filter}) async {
    countCalls++;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (scheduledCountFailures.isNotEmpty) {
      return Failure<int>(scheduledCountFailures.removeFirst());
    }
    if (scheduledFailures.isNotEmpty) {
      return Failure<int>(scheduledFailures.removeFirst());
    }
    return Success<int>(
      _byId.values.where((Observation o) => _matches(o, filter)).length,
    );
  }

  @override
  Future<Result<Observation>> getById(String id) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (scheduledFailures.isNotEmpty) {
      return Failure<Observation>(scheduledFailures.removeFirst());
    }
    final Observation? found = _byId[id];
    return found == null
        ? Failure<Observation>(AppFailure(FailureCode.notFound))
        : Success<Observation>(found);
  }

  // ── Escritura (misma semántica que SqliteObservationStore) ─────────────

  @override
  Future<Result<Observation>> create(
    ObservationInput input, {
    required ObservationStatus status,
  }) async {
    final AppFailure? early = await _preflight(input, status);
    if (early != null) return Failure<Observation>(early);
    final DateTime now = _clock().toUtc();
    final Observation created = Observation(
      id: 'mem-${(++_sequence).toString().padLeft(4, '0')}-${now.microsecondsSinceEpoch}',
      status: status,
      input: _clean(input),
      createdAt: now,
      updatedAt: now,
      revision: 1,
    );
    _byId[created.id] = created;
    return Success<Observation>(created);
  }

  @override
  Future<Result<Observation>> update(
    String id,
    ObservationInput input, {
    required ObservationStatus status,
    required int expectedRevision,
  }) async {
    final AppFailure? early = await _preflight(input, status);
    if (early != null) return Failure<Observation>(early);
    final Observation? current = _byId[id];
    if (current == null) {
      return Failure<Observation>(AppFailure(FailureCode.notFound));
    }
    if (current.revision != expectedRevision) {
      return Failure<Observation>(AppFailure(FailureCode.conflict));
    }
    return Success<Observation>(
      _byId[id] = _bump(current, input: _clean(input), status: status),
    );
  }

  @override
  Future<Result<Unit>> delete(
    String id, {
    required int expectedRevision,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (scheduledFailures.isNotEmpty) {
      return Failure<Unit>(scheduledFailures.removeFirst());
    }
    final Observation? current = _byId[id];
    if (current == null) return Failure<Unit>(AppFailure(FailureCode.notFound));
    if (current.revision != expectedRevision) {
      return Failure<Unit>(AppFailure(FailureCode.conflict));
    }
    _byId.remove(id);
    return const Success<Unit>(Unit.value);
  }

  @override
  Future<Result<Observation>> save(
    ObservationInput input, {
    String? id,
    int? expectedRevision,
  }) async {
    if ((id == null) != (expectedRevision == null)) {
      return Failure<Observation>(
        AppFailure(
          FailureCode.validation,
          fieldErrors: const <String, String>{'id': 'pair_required'},
        ),
      );
    }
    if (id == null) return create(input, status: ObservationStatus.draft);
    final Observation? current = _byId[id];
    if (current != null && current.status != ObservationStatus.draft) {
      return Failure<Observation>(
        AppFailure(
          FailureCode.validation,
          fieldErrors: const <String, String>{'status': 'not_a_draft'},
        ),
      );
    }
    return update(
      id,
      input,
      status: ObservationStatus.draft,
      expectedRevision: expectedRevision!,
    );
  }

  @override
  Future<Result<Observation>> publish(
    String id, {
    required int expectedRevision,
  }) async {
    final Observation? current = _byId[id];
    if (current == null) {
      return Failure<Observation>(AppFailure(FailureCode.notFound));
    }
    if (current.revision != expectedRevision) {
      return Failure<Observation>(AppFailure(FailureCode.conflict));
    }
    if (current.status == ObservationStatus.published) {
      return Failure<Observation>(AppFailure(FailureCode.conflict));
    }
    final Result<ObservationInput> valid = validator.validate(
      current.input,
      status: ObservationStatus.published,
    );
    if (valid is Failure<ObservationInput>) {
      return Failure<Observation>(valid.failure);
    }
    return Success<Observation>(
      _byId[id] = _bump(
        current,
        input: current.input,
        status: ObservationStatus.published,
      ),
    );
  }

  Future<AppFailure?> _preflight(
    ObservationInput input,
    ObservationStatus status,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (scheduledFailures.isNotEmpty) return scheduledFailures.removeFirst();
    final Result<ObservationInput> valid = validator.validate(
      input,
      status: status,
    );
    return valid is Failure<ObservationInput> ? valid.failure : null;
  }

  Observation _bump(
    Observation current, {
    required ObservationInput input,
    required ObservationStatus status,
  }) {
    final DateTime now = _clock().toUtc();
    return Observation(
      id: current.id,
      status: status,
      input: input,
      createdAt: current.createdAt,
      updatedAt: now.isBefore(current.createdAt) ? current.createdAt : now,
      revision: current.revision + 1,
    );
  }

  /// Igual que SQLite: título recortado y textos vacíos como nulos.
  static ObservationInput _clean(ObservationInput i) {
    String? blank(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
    return i.copyWith(
      title: i.title.trim(),
      description: () => blank(i.description),
    );
  }

  // ── Semántica del filtro ────────────────────────────────────────────────

  static bool _matches(Observation o, ObservationFilter f) {
    if (f.status != null && o.status != f.status) return false;
    if (f.category != null && o.input.category != f.category) return false;
    final DateTime? at = o.input.observedAt;
    if (f.from != null && (at == null || at.isBefore(f.from!))) return false;
    if (f.until != null && (at == null || !at.isBefore(f.until!))) return false;
    final String place = fold(o.input.location?.placeName ?? '');
    if (f.place.trim().isNotEmpty && !place.contains(fold(f.place))) {
      return false;
    }
    final String haystack = SearchNormalizer.document(
      title: o.input.title,
      description: o.input.description,
      place: o.input.location?.placeName,
    );
    // Igual que SQLite: cada palabra de la búsqueda debe aparecer (AND).
    for (final String token in SearchNormalizer.tokens(f.query)) {
      if (!haystack.contains(token)) return false;
    }
    return true;
  }

  static int _compare(Observation a, Observation b) {
    final DateTime? x = a.input.observedAt;
    final DateTime? y = b.input.observedAt;
    if (x != null && y != null && x != y) return y.compareTo(x);
    if (x == null && y != null) return 1;
    if (x != null && y == null) return -1;
    return b.id.compareTo(a.id);
  }

  /// Minúsculas sin acentos ni diéresis (mismo criterio que SQLite).
  static String fold(String text) => SearchNormalizer.normalize(text);

  static String _signature(ObservationFilter f) => <Object?>[
    f.query, f.from?.millisecondsSinceEpoch, f.until?.millisecondsSinceEpoch, //
    f.category?.name, f.place, f.status?.name,
  ].join('|').hashCode.toRadixString(36);

  static String _encodeCursor(int offset, ObservationFilter f) =>
      '${_signature(f)}:$offset';

  static int? _decodeCursor(String cursor, ObservationFilter f) {
    final List<String> parts = cursor.split(':');
    if (parts.length != 2 || parts.first != _signature(f)) return null;
    return int.tryParse(parts.last);
  }
}
