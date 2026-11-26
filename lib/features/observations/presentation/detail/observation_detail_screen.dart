import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/contracts.dart';
import '../../../../design/design.dart';
import '../../../../l10n/cielo_format.dart';
import '../../../../l10n/cielo_strings.dart';
import '../../../../l10n/failure_messages.dart';
import '../../../../ui_kit/ui_kit.dart';
import '../../../map/domain/offline_province_map.dart';
import '../../../map/presentation/province_map_view.dart';
import '../observation_display.dart';
import '../widgets/observation_thumbnail.dart';

/// Detalle de una observación (destino visual del Diario).
///
/// Muestra [initial] de inmediato (sin parpadeo y con transición Hero) y
/// confirma con `ObservationRepository.getById`. Si ya no existe, lo explica.
/// Con [onEdit] ofrece editar (o completar un borrador) y con [service],
/// eliminar con confirmación y control de revisión.
/// Al salir devuelve `true` si la observación cambió o se eliminó, para que
/// el Diario recargue. El mapa y la reproducción de audio llegan en el Hito B.
class ObservationDetailScreen extends StatefulWidget {
  const ObservationDetailScreen({
    super.key,
    required this.observationId,
    required this.observations,
    this.initial,
    this.resolveMediaPath,
    this.service,
    this.onEdit,
    this.mediaService,
    this.player,
    this.provinceMap,
    this.maintenance,
  });

  final String observationId;
  final ObservationRepository observations;
  final Observation? initial;
  final MediaPathResolver? resolveMediaPath;
  final MediaService? mediaService;
  final AudioPlayerService? player;
  final OfflineProvinceMap? provinceMap;
  final MediaMaintenance? maintenance;

  /// Habilita "Eliminar".
  final ObservationService? service;

  /// Abre el formulario de edición; devuelve la observación guardada o `null`.
  final Future<Observation?> Function(
    BuildContext context,
    Observation observation,
  )?
  onEdit;

  @override
  State<ObservationDetailScreen> createState() =>
      _ObservationDetailScreenState();
}

class _ObservationDetailScreenState extends State<ObservationDetailScreen> {
  late Observation? _observation = widget.initial;
  AppFailure? _failure;
  bool _loading = true;
  bool _changed = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    final Result<Observation> result = await widget.observations.getById(
      widget.observationId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case Success<Observation>(:final Observation value):
          _observation = value;
        case Failure<Observation>(:final AppFailure failure):
          _failure = failure;
          if (failure.code == FailureCode.notFound) _observation = null;
      }
    });
  }

  Future<void> _edit(Observation o) async {
    final Observation? saved = await widget.onEdit!(context, o);
    if (saved == null || !mounted) return;
    setState(() {
      _observation = saved;
      _changed = true;
    });
  }

  Future<void> _delete(Observation o) async {
    final bool confirmed = await showCieloConfirmDialog(
      context,
      title: CieloStrings.deleteObservationTitle,
      message: CieloStrings.deleteObservationMessage,
      confirmLabel: CieloStrings.delete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    final Result<Unit> result = await widget.service!.delete(
      o.id,
      expectedRevision: o.revision,
    );
    if (!mounted) return;
    switch (result) {
      case Success<Unit>():
        await widget.maintenance?.run();
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text(CieloStrings.observationDeleted)),
        );
        Navigator.of(context).pop(true);
      case Failure<Unit>(:final AppFailure failure):
        setState(() {
          _deleting = false;
          _failure = failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Observation? o = _observation;
    final Widget body;
    if (o != null) {
      body = _DetailBody(
        observation: o,
        resolveMediaPath: widget.resolveMediaPath,
        failure: _failure,
        onRetry: _load,
        mediaService: widget.mediaService,
        player: widget.player,
        provinceMap: widget.provinceMap,
      );
    } else if (_failure != null) {
      body = CieloErrorState(
        message: FailureMessages.of(_failure!),
        onRetry: _failure!.code == FailureCode.notFound ? null : _load,
        secondaryActionLabel: CieloStrings.back,
        onSecondaryAction: () => Navigator.of(context).maybePop(),
      );
    } else {
      body = _loading
          ? const Padding(
              padding: EdgeInsets.all(CieloSpace.gutter),
              child: CieloSkeletonList(count: 1),
            )
          : const SizedBox.shrink();
    }
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(CieloStrings.detailTitle),
          actions: <Widget>[
            if (o != null && widget.onEdit != null)
              IconButton(
                tooltip: o.isDraft ? CieloStrings.complete : CieloStrings.edit,
                onPressed: _deleting ? null : () => _edit(o),
                icon: const Icon(Icons.edit_rounded),
              ),
            if (o != null && widget.service != null)
              IconButton(
                tooltip: CieloStrings.delete,
                onPressed: _deleting ? null : () => _delete(o),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: body,
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.observation,
    required this.resolveMediaPath,
    required this.failure,
    required this.onRetry,
    required this.mediaService,
    required this.player,
    required this.provinceMap,
  });

  final Observation observation;
  final MediaPathResolver? resolveMediaPath;

  /// Fallo al refrescar con datos ya visibles: aviso, no pantalla de error.
  final AppFailure? failure;
  final VoidCallback onRetry;
  final MediaService? mediaService;
  final AudioPlayerService? player;
  final OfflineProvinceMap? provinceMap;

  @override
  Widget build(BuildContext context) {
    final Observation o = observation;
    final ObservationInput input = o.input;
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final CategoryVisual category = o.categoryVisual;
    final ObservationMedia? photo = o.firstPhoto;
    final MediaPathResolver? resolve = resolveMediaPath;
    final DateTime? local = o.localObservedAt;
    final ObservationLocation? location = input.location;
    final String? description = input.description?.trim();

    final Widget leading = Hero(
      tag: o.heroTag,
      child: ClipRRect(
        borderRadius: CieloRadius.tileAll,
        child: SizedBox.square(
          dimension: 88,
          child: photo != null && resolve != null
              ? _filtered(
                  c,
                  ObservationThumbnail(
                    mediaId: photo.id,
                    category: category,
                    resolve: resolve,
                    cacheWidth: 264,
                  ),
                )
              : CategoryTile(category: category, glyphSize: 44),
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CieloSpace.gutter,
        CieloSpace.sm,
        CieloSpace.gutter,
        CieloSpace.xxxl,
      ),
      children: <Widget>[
        if (failure != null) ...<Widget>[
          CieloBanner(
            tone: CieloTone.danger,
            message: FailureMessages.of(failure!),
            actionLabel: CieloStrings.retry,
            onAction: onRetry,
          ),
          const SizedBox(height: CieloSpace.lg),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            leading,
            const SizedBox(width: CieloSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    category.label,
                    style: text.labelLarge?.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: CieloSpace.xs),
                  Semantics(
                    header: true,
                    child: Text(o.displayTitle, style: text.headlineMedium),
                  ),
                  if (o.isDraft) ...<Widget>[
                    const SizedBox(height: CieloSpace.sm),
                    const CieloBadge(
                      label: CieloStrings.draft,
                      tone: CieloTone.warning,
                      icon: Icons.edit_note_rounded,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: CieloSpace.xl),
        _Fact(
          icon: Icons.schedule_rounded,
          label: CieloStrings.observedAtLabel,
          value: local == null
              ? CieloStrings.noDate
              : '${CieloFormat.dateLong(local)}, ${CieloFormat.time(local)}',
        ),
        if (input.skyCondition != null)
          _Fact(
            icon: SkyConditionVisual.fromCode(input.skyCondition!.code).icon,
            label: CieloStrings.skyConditionLabel,
            value: SkyConditionVisual.fromCode(input.skyCondition!.code).label,
          ),
        if (input.durationSeconds != null)
          _Fact(
            icon: Icons.timer_outlined,
            label: CieloStrings.durationLabel,
            value: CieloFormat.duration(
              Duration(seconds: input.durationSeconds!),
            ),
            spokenValue: CieloFormat.durationSpoken(
              Duration(seconds: input.durationSeconds!),
            ),
          ),
        if (input.direction != null)
          _Fact(
            icon: Icons.explore_rounded,
            label: CieloStrings.directionLabel,
            value:
                DirectionVisual.fromCode(input.direction!.code)?.label ??
                CieloStrings.unknownValue,
          ),
        if (input.elevationDegrees != null)
          _Fact(
            icon: Icons.height_rounded,
            label: CieloStrings.elevationLabel,
            value: CieloStrings.elevation(input.elevationDegrees!),
          ),
        _Fact(
          icon: Icons.place_rounded,
          label: CieloStrings.placeLabel,
          value: location?.placeName?.trim().isNotEmpty ?? false
              ? location!.placeName!.trim()
              : CieloStrings.noLocation,
        ),
        if (location != null && location.hasCoordinates)
          _Fact(
            icon: location.source == LocationSource.gps
                ? Icons.gps_fixed_rounded
                : Icons.edit_location_alt_rounded,
            label: CieloStrings.coordinatesLabel,
            value: <String>[
              CieloFormat.coordinates(location.latitude!, location.longitude!),
              if (location.accuracyM != null)
                CieloFormat.accuracy(location.accuracyM!),
            ].join('  '),
            tabular: true,
          ),
        if (location != null &&
            location.hasCoordinates &&
            provinceMap != null) ...[
          const SizedBox(height: CieloSpace.md),
          ProvinceMapView(
            map: provinceMap!,
            height: 280,
            selected: GeoCoordinate(location.latitude!, location.longitude!),
            markers: [
              OfflineMapMarker(
                id: o.id,
                coordinate: GeoCoordinate(
                  location.latitude!,
                  location.longitude!,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: CieloSpace.sm),
        CieloSectionHeader(title: CieloStrings.descriptionLabel),
        Text(
          description == null || description.isEmpty
              ? CieloStrings.noDescription
              : description,
          style: text.bodyLarge?.copyWith(
            color: description == null || description.isEmpty
                ? c.textSecondary
                : c.textPrimary,
          ),
        ),
        CieloSectionHeader(title: CieloStrings.mediaLabel),
        if (o.photoCount == 0 && o.audioCount == 0)
          Text(
            CieloStrings.noMedia,
            style: text.bodyLarge?.copyWith(color: c.textSecondary),
          )
        else ...[
          if (resolve != null)
            Wrap(
              spacing: CieloSpace.sm,
              runSpacing: CieloSpace.sm,
              children: [
                for (final item in input.media.where(
                  (item) => item.kind == MediaKind.photo,
                ))
                  InkWell(
                    onTap: () async {
                      final path = await resolve(item.id);
                      if (!context.mounted || path is! Success<String>) return;
                      await showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.file(
                              File(path.value),
                              errorBuilder: (_, _, _) => const Padding(
                                padding: EdgeInsets.all(32),
                                child: Icon(Icons.broken_image_rounded),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: SizedBox.square(
                      dimension: 104,
                      child: ObservationThumbnail(
                        mediaId: item.id,
                        category: category,
                        resolve: resolve,
                        cacheWidth: 312,
                      ),
                    ),
                  ),
              ],
            ),
          for (final item in input.media.where(
            (item) => item.kind == MediaKind.audio,
          ))
            if (player != null) _AudioAttachment(media: item, player: player!),
        ],
      ],
    );
  }

  static Widget _filtered(CieloColors c, Widget child) {
    final ColorFilter? filter = c.mediaFilter;
    return filter == null
        ? child
        : ColorFiltered(colorFilter: filter, child: child);
  }
}

class _AudioAttachment extends StatefulWidget {
  const _AudioAttachment({required this.media, required this.player});
  final ObservationMedia media;
  final AudioPlayerService player;
  @override
  State<_AudioAttachment> createState() => _AudioAttachmentState();
}

class _AudioAttachmentState extends State<_AudioAttachment> {
  PlaybackState _state = const PlaybackState(phase: PlayerPhase.idle);
  StreamSubscription<PlaybackState>? _subscription;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.player.states.listen((state) {
      if (mounted && state.mediaId == widget.media.id) {
        setState(() => _state = state);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_loaded) {
      final result = await widget.player.load(widget.media.id);
      if (result is Failure<Unit>) return;
      _loaded = true;
    }
    if (_state.phase == PlayerPhase.playing) {
      await widget.player.pause();
    } else {
      await widget.player.play();
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: IconButton.filledTonal(
      tooltip: _state.phase == PlayerPhase.playing ? 'Pausar' : 'Reproducir',
      onPressed: _toggle,
      icon: Icon(
        _state.phase == PlayerPhase.playing
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
      ),
    ),
    title: const Text('Nota de voz'),
    subtitle: Text(
      CieloFormat.duration(
        Duration(milliseconds: widget.media.durationMs ?? 0),
      ),
    ),
  );
}

/// Dato del detalle: icono, etiqueta y valor; TalkBack lo lee como una unidad.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.spokenValue,
    this.tabular = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? spokenValue;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle valueStyle = text.bodyLarge ?? const TextStyle();
    return Semantics(
      label: '$label: ${spokenValue ?? value}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CieloSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: c.textSecondary, size: CieloSize.iconMd),
            ),
            const SizedBox(width: CieloSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: text.labelMedium?.copyWith(color: c.textSecondary),
                  ),
                  Text(
                    value,
                    style: tabular
                        ? CieloTypography.tabular(valueStyle)
                        : valueStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
