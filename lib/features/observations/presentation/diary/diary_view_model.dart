import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../app/contracts.dart';
import 'diary_criteria.dart';

enum DiaryPhase { loading, ready, failure }

/// Estado de presentación del Diario sobre el contrato [ObservationRepository].
///
/// Vive en `presentation/` porque solo coordina lo que la pantalla muestra
/// (criterios, páginas cargadas, fases). No persiste ni muta datos. Si Codex
/// publica en C1 un controlador de listado, esta clase puede delegar en él sin
/// cambiar la pantalla.
///
/// * Cambiar criterios reinicia el cursor (exigido por el contrato).
/// * Las respuestas fuera de orden se descartan.
/// * La búsqueda de texto espera [searchDebounce] antes de consultar.
class DiaryViewModel extends ChangeNotifier {
  DiaryViewModel({
    required this.observations,
    DateTime Function()? clock,
    this.searchDebounce = const Duration(milliseconds: 300),
    this.pageSize = 30,
    DiaryCriteria initialCriteria = DiaryCriteria.initial,
  })  : _clock = clock ?? DateTime.now,
        _criteria = initialCriteria,
        assert(pageSize >= 1 && pageSize <= 100);

  final ObservationRepository observations;
  final DateTime Function() _clock;
  final Duration searchDebounce;
  final int pageSize;

  DiaryCriteria _criteria;
  DiaryPhase _phase = DiaryPhase.loading;
  List<Observation> _items = const <Observation>[];
  String? _nextCursor;
  AppFailure? _failure;
  bool _loadingMore = false;
  AppFailure? _loadMoreFailure;
  int? _draftCount;
  int? _totalCount;

  int _generation = 0;
  Timer? _debounce;
  bool _disposed = false;

  DiaryCriteria get criteria => _criteria;
  DiaryPhase get phase => _phase;
  List<Observation> get items => _items;
  bool get hasMore => _nextCursor != null;
  AppFailure? get failure => _failure;
  bool get isLoadingMore => _loadingMore;
  AppFailure? get loadMoreFailure => _loadMoreFailure;

  /// Borradores pendientes (conteo exacto). `null` si no se pudo contar.
  int? get draftCount => _draftCount;

  /// Total exacto de resultados con los criterios actuales; `null` si el
  /// conteo falló (la lista sigue siendo válida).
  int? get totalCount => _totalCount;

  /// Lista vacía con los criterios actuales.
  bool get isEmpty => _phase == DiaryPhase.ready && _items.isEmpty;

  /// Primera carga. Idempotente respecto a criterios.
  Future<void> load() => _reload(showLoading: true);

  /// Recarga conservando la lista visible (deslizar para actualizar).
  Future<void> refresh() => _reload(showLoading: _items.isEmpty);

  /// Escribe la búsqueda; consulta tras [searchDebounce].
  void setQuery(String query) {
    if (query == _criteria.query) return;
    _criteria = _criteria.copyWith(query: query);
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () => _reload(showLoading: true));
  }

  /// Aplica la búsqueda de inmediato (tecla "buscar" del teclado).
  void submitQuery() {
    _debounce?.cancel();
    _reload(showLoading: true);
  }

  void updateCriteria(DiaryCriteria criteria) {
    if (criteria == _criteria) return;
    _debounce?.cancel();
    _criteria = criteria;
    _reload(showLoading: true);
  }

  void setCategory(ObservationCategory? category) =>
      updateCriteria(_criteria.copyWith(category: () => category));

  void clearFilters() => updateCriteria(DiaryCriteria.initial);

  Future<void> loadMore() async {
    final String? cursor = _nextCursor;
    if (cursor == null || _loadingMore || _phase != DiaryPhase.ready) return;
    final int generation = _generation;
    _loadingMore = true;
    _loadMoreFailure = null;
    notifyListeners();

    final Result<ObservationPage> result = await observations.list(
      filter: _criteria.toFilter(_clock()),
      cursor: cursor,
      limit: pageSize,
    );
    if (_disposed || generation != _generation) return;
    _loadingMore = false;
    switch (result) {
      case Success<ObservationPage>(:final ObservationPage value):
        _items = List<Observation>.unmodifiable(<Observation>[..._items, ...value.items]);
        _nextCursor = value.nextCursor;
      case Failure<ObservationPage>(:final AppFailure failure):
        _loadMoreFailure = failure;
    }
    notifyListeners();
  }

  Future<void> _reload({required bool showLoading}) async {
    final int generation = ++_generation;
    _loadingMore = false;
    _loadMoreFailure = null;
    if (showLoading) {
      _phase = DiaryPhase.loading;
      _failure = null;
      notifyListeners();
    }

    final ObservationFilter filter = _criteria.toFilter(_clock());
    final Future<Result<int>> drafts =
        observations.count(filter: ObservationFilter(status: ObservationStatus.draft));
    final Future<Result<int>> total = observations.count(filter: filter);
    final Result<ObservationPage> result = await observations.list(filter: filter, limit: pageSize);
    final Result<int> draftResult = await drafts;
    final Result<int> totalResult = await total;
    if (_disposed || generation != _generation) return;
    _draftCount = draftResult is Success<int> ? draftResult.value : null;
    _totalCount = totalResult is Success<int> ? totalResult.value : null;

    switch (result) {
      case Success<ObservationPage>(:final ObservationPage value):
        _items = value.items;
        _nextCursor = value.nextCursor;
        _phase = DiaryPhase.ready;
        _failure = null;
      case Failure<ObservationPage>(:final AppFailure failure):
        _phase = DiaryPhase.failure;
        _failure = failure;
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
