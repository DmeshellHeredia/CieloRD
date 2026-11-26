import 'package:flutter/material.dart';

import '../../../../app/contracts.dart';
import '../../../../design/design.dart';
import '../../../../l10n/cielo_format.dart';
import '../../../../l10n/cielo_strings.dart';
import '../../../../l10n/failure_messages.dart';
import '../../../../ui_kit/ui_kit.dart';
import '../detail/observation_detail_screen.dart';
import '../observation_display.dart';
import '../widgets/diary_observation_card.dart';
import '../widgets/observation_thumbnail.dart';
import 'diary_criteria.dart';
import 'diary_filter_sheet.dart';
import 'diary_view_model.dart';

/// Diario de observaciones: búsqueda, filtros, lista agrupada por mes y
/// estados de carga, vacío y error.
///
/// Recibe los colaboradores por constructor (C0 §Integración 2):
/// * [observations]: contrato de lectura `ObservationRepository`.
/// * [resolveMediaPath]: `MediaService.resolveLocalPath` para miniaturas.
/// * [onOpenObservation]: navegación al detalle. Si es nulo, se usa
///   `Navigator.push` con [ObservationDetailScreen] (sustituible por
///   go_router cuando Codex lo integre).
/// * [onCreateObservation]: abre el registro (U2) y devuelve `true` si se
///   guardó algo, para recargar. Si es nulo, no se muestra "Registrar".
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    super.key,
    required this.observations,
    this.resolveMediaPath,
    this.onOpenObservation,
    this.onCreateObservation,
    this.appBarActions = const <Widget>[],
    this.dataReset,
    this.clock,
    this.searchDebounce = const Duration(milliseconds: 300),
    this.pageSize = 30,
  });

  final ObservationRepository observations;
  final MediaPathResolver? resolveMediaPath;

  /// Devuelve `true` si hubo cambios y el Diario debe recargarse.
  final Future<bool?> Function(BuildContext context, Observation observation)? onOpenObservation;
  final Future<bool?> Function(BuildContext context)? onCreateObservation;
  final List<Widget> appBarActions;

  /// Avisa de que los datos cambiaron en bloque (importar, borrar todo): el
  /// Diario vuelve a sus filtros iniciales y recarga.
  final Listenable? dataReset;
  final DateTime Function()? clock;
  final Duration searchDebounce;
  final int pageSize;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late final DiaryViewModel _vm = DiaryViewModel(
    observations: widget.observations,
    clock: widget.clock,
    searchDebounce: widget.searchDebounce,
    pageSize: widget.pageSize,
  );

  @override
  void initState() {
    super.initState();
    widget.dataReset?.addListener(_onDataReset);
    _vm.load();
  }

  @override
  void didUpdateWidget(DiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataReset != widget.dataReset) {
      oldWidget.dataReset?.removeListener(_onDataReset);
      widget.dataReset?.addListener(_onDataReset);
    }
  }

  void _onDataReset() {
    _vm.clearFilters();
    _vm.load();
  }

  @override
  void dispose() {
    widget.dataReset?.removeListener(_onDataReset);
    _vm.dispose();
    super.dispose();
  }

  DateTime get _now => (widget.clock ?? DateTime.now)();

  Future<void> _open(Observation observation) async {
    final bool? changed = widget.onOpenObservation != null
        ? await widget.onOpenObservation!(context, observation)
        : await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (BuildContext context) => ObservationDetailScreen(
                observationId: observation.id,
                observations: widget.observations,
                initial: observation,
                resolveMediaPath: widget.resolveMediaPath,
              ),
            ),
          );
    if (changed ?? false) await _vm.refresh();
  }

  Future<void> _create() async {
    final bool? changed = await widget.onCreateObservation!(context);
    if (changed ?? false) await _vm.refresh();
  }

  Future<void> _openFilters() async {
    final DiaryCriteria? result = await showDiaryFilterSheet(context, _vm.criteria);
    if (result != null) _vm.updateCriteria(result);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 480) _vm.loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (BuildContext context, _) => Scaffold(
        floatingActionButton: widget.onCreateObservation == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _create,
                icon: const Icon(Icons.add_rounded),
                label: const Text(CieloStrings.register),
              ),
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: RefreshIndicator(
            onRefresh: _vm.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverAppBar(
                  floating: true,
                  snap: true,
                  title: const Text(CieloStrings.diaryTitle),
                  actions: widget.appBarActions,
                ),
                _pad(CieloSearchField(
                  value: _vm.criteria.query,
                  onChanged: _vm.setQuery,
                  onSubmitted: (_) => _vm.submitQuery(),
                )),
                SliverToBoxAdapter(child: _FilterRow(vm: _vm, onOpenFilters: _openFilters)),
                if (_activeChips().isNotEmpty)
                  _pad(Wrap(spacing: CieloSpace.sm, runSpacing: CieloSpace.sm, children: _activeChips()),
                      top: 0),
                ..._draftsBanner(),
                ..._content(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pad(Widget child, {double top = CieloSpace.sm}) => SliverPadding(
        padding: EdgeInsets.fromLTRB(CieloSpace.gutter, top, CieloSpace.gutter, CieloSpace.sm),
        sliver: SliverToBoxAdapter(child: child),
      );

  List<Widget> _activeChips() {
    final DiaryCriteria c = _vm.criteria;
    return <Widget>[
      if (c.statusView != DiaryStatusView.published)
        CieloRemovableChip(
          label: c.statusView.label,
          icon: Icons.edit_note_rounded,
          onRemove: () => _vm.updateCriteria(c.copyWith(statusView: DiaryStatusView.published)),
        ),
      if (c.dateRange != DiaryDateRange.any)
        CieloRemovableChip(
          label: c.dateRange.label,
          icon: Icons.event_rounded,
          onRemove: () => _vm.updateCriteria(c.copyWith(dateRange: DiaryDateRange.any)),
        ),
      if (c.place.trim().isNotEmpty)
        CieloRemovableChip(
          label: CieloStrings.placeFilter(c.place.trim()),
          icon: Icons.place_rounded,
          onRemove: () => _vm.updateCriteria(c.copyWith(place: '')),
        ),
    ];
  }

  List<Widget> _draftsBanner() {
    final int drafts = _vm.draftCount ?? 0;
    if (drafts == 0 ||
        _vm.criteria.statusView != DiaryStatusView.published ||
        _vm.phase != DiaryPhase.ready) {
      return const <Widget>[];
    }
    return <Widget>[
      _pad(CieloBanner(
        tone: CieloTone.warning,
        icon: Icons.edit_note_rounded,
        title: CieloStrings.draftsPending(drafts),
        message: CieloStrings.draftsBannerMessage,
        actionLabel: CieloStrings.viewDrafts,
        onAction: () => _vm.updateCriteria(_vm.criteria.copyWith(statusView: DiaryStatusView.drafts)),
      )),
    ];
  }

  List<Widget> _content(BuildContext context) {
    switch (_vm.phase) {
      case DiaryPhase.loading:
        return <Widget>[_pad(const CieloSkeletonList(count: 4))];
      case DiaryPhase.failure:
        return <Widget>[
          SliverToBoxAdapter(
            child: CieloErrorState(
              message: FailureMessages.of(_vm.failure!),
              onRetry: _vm.load,
            ),
          ),
        ];
      case DiaryPhase.ready:
        if (_vm.items.isEmpty) return <Widget>[SliverToBoxAdapter(child: _emptyState())];
        return <Widget>[
          _pad(_ResultsSummary(count: _vm.totalCount ?? _vm.items.length, hasMore: _vm.totalCount == null && _vm.hasMore), top: 0),
          _MonthGroupedList(
            items: _vm.items,
            now: _now,
            resolveMediaPath: widget.resolveMediaPath,
            onOpen: _open,
          ),
          SliverToBoxAdapter(child: _Footer(vm: _vm)),
        ];
    }
  }

  Widget _emptyState() {
    final DiaryCriteria c = _vm.criteria;
    if (!c.isRefined) {
      return CieloEmptyState(
        title: CieloStrings.emptyDiaryTitle,
        message: CieloStrings.emptyDiaryMessage,
        actionLabel: widget.onCreateObservation == null ? null : CieloStrings.emptyDiaryAction,
        onAction: widget.onCreateObservation == null ? null : _create,
      );
    }
    final bool onlyDrafts = c.statusView == DiaryStatusView.drafts &&
        c.copyWith(statusView: DiaryStatusView.published) == DiaryCriteria.initial;
    if (onlyDrafts) {
      return CieloEmptyState(
        icon: Icons.edit_note_rounded,
        title: CieloStrings.emptyDraftsViewTitle,
        message: CieloStrings.emptyDraftsViewMessage,
        secondaryActionLabel: CieloStrings.statusPublished,
        onSecondaryAction: _vm.clearFilters,
      );
    }
    return CieloEmptyState(
      icon: Icons.travel_explore_rounded,
      title: CieloStrings.noResultsTitle,
      message: CieloStrings.noResultsMessage(c.query.trim()),
      secondaryActionLabel: CieloStrings.clearFilters,
      onSecondaryAction: _vm.clearFilters,
    );
  }
}

/// Botón de filtros + categorías de acceso rápido (selección única, como el
/// contrato `ObservationFilter.category`). Desplazable en horizontal.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.vm, required this.onOpenFilters});

  final DiaryViewModel vm;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final ObservationCategory? selected = vm.criteria.category;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: CieloSpace.gutter, vertical: CieloSpace.xs),
      child: Row(
        children: <Widget>[
          CieloFilterButton(activeCount: vm.criteria.activeFilterCount, onPressed: onOpenFilters),
          for (final ObservationCategory category in ObservationCategory.values) ...<Widget>[
            const SizedBox(width: CieloSpace.sm),
            CategoryChip(
              category: CategoryVisual.fromCode(category.name),
              multiSelect: false,
              selected: selected == category,
              onSelected: (bool on) => vm.setCategory(on ? category : null),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({required this.count, required this.hasMore});

  final int count;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        hasMore ? CieloStrings.observationsCountMore(count) : CieloStrings.observationsCount(count),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
      ),
    );
  }
}

/// Lista con encabezados por mes (hora local de la observación). Los
/// registros sin fecha van al final, como en el orden del contrato.
class _MonthGroupedList extends StatelessWidget {
  const _MonthGroupedList({
    required this.items,
    required this.now,
    required this.resolveMediaPath,
    required this.onOpen,
  });

  final List<Observation> items;
  final DateTime now;
  final MediaPathResolver? resolveMediaPath;
  final ValueChanged<Observation> onOpen;

  List<Object> _entries() {
    final List<Object> entries = <Object>[];
    String? currentKey;
    for (final Observation o in items) {
      final DateTime? local = o.localObservedAt;
      final String key = local == null ? CieloStrings.noDate : CieloFormat.monthYear(local);
      if (key != currentKey) {
        entries.add(key);
        currentKey = key;
      }
      entries.add(o);
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final List<Object> entries = _entries();
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: CieloSpace.gutter),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (BuildContext context, int index) {
          final Object entry = entries[index];
          if (entry is String) {
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? CieloSpace.sm : CieloSpace.xl, bottom: CieloSpace.sm),
              child: Semantics(
                header: true,
                child: Text(entry, style: text.titleMedium?.copyWith(color: c.textSecondary)),
              ),
            );
          }
          final Observation o = entry as Observation;
          return Padding(
            padding: const EdgeInsets.only(bottom: CieloSpace.md),
            child: DiaryObservationCard(
              key: ValueKey<String>(o.id),
              observation: o,
              now: now,
              resolveMediaPath: resolveMediaPath,
              onTap: () => onOpen(o),
            ),
          );
        },
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.vm});

  final DiaryViewModel vm;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final Widget child;
    if (vm.isLoadingMore) {
      child = Semantics(
        label: CieloStrings.loadingMore,
        liveRegion: true,
        child: const Center(
          child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
        ),
      );
    } else if (vm.loadMoreFailure != null) {
      child = CieloBanner(
        tone: CieloTone.danger,
        message: CieloStrings.loadMoreError,
        actionLabel: CieloStrings.retry,
        onAction: vm.loadMore,
      );
    } else if (!vm.hasMore && vm.items.length > 4) {
      child = Text(
        CieloStrings.endOfDiary,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
      );
    } else {
      child = const SizedBox.shrink();
    }
    // Espacio inferior para que el botón flotante no tape la última tarjeta.
    return Padding(
      padding: const EdgeInsets.fromLTRB(CieloSpace.gutter, CieloSpace.sm, CieloSpace.gutter, 112),
      child: child,
    );
  }
}
