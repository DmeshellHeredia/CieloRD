import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../l10n/cielo_format.dart';
import '../../../l10n/cielo_strings.dart';
import '../../../ui_kit/ui_kit.dart';

/// Textos propios de la galería (herramienta interna de revisión, no forma
/// parte de la app final). Los textos de producto viven en `CieloStrings`.
abstract final class _G {
  static const String title = 'Galería de diseño';
  static const String controls = 'Controles de revisión';
  static const String theme = 'Tema';
  static const String night = 'Noche';
  static const String day = 'Día';
  static const String astro = 'Astrónomo';
  static const String textSize = 'Tamaño de texto';
  static const String reduceMotion = 'Movimiento reducido';
  static const String leftHanded = 'Acción principal a la izquierda';
  static const String brand = 'Marca';
  static const String brandNote =
      'La matrícula definitiva se mostrará al recibirla. No se usa un valor inventado.';
  static const String colors = 'Colores';
  static const String colorsNote = 'Contraste de cada color sobre el fondo de este tema.';
  static const String type = 'Tipografía';
  static const String categories = 'Categorías';
  static const String categoryFilters = 'Filtros por categoría';
  static const String sky = 'Condición del cielo';
  static const String direction = 'Dirección';
  static const String duration = 'Duración';
  static const String cards = 'Tarjetas de observación';
  static const String badges = 'Insignias y avisos';
  static const String states = 'Estados';
  static const String dialogs = 'Diálogos';
  static const String loading = 'Carga';
  static const String openDelete = 'Eliminar una observación';
  static const String openEraseAll = 'Borrar todo';
  static const String openUnsaved = 'Salir con cambios';
  static String result(String r) => 'Resultado: $r';
}

class DesignGalleryPage extends StatefulWidget {
  const DesignGalleryPage({
    super.key,
    required this.variant,
    required this.onVariantChanged,
    required this.textScale,
    required this.onTextScaleChanged,
    required this.reduceMotion,
    required this.onReduceMotionChanged,
    required this.leftHanded,
    required this.onLeftHandedChanged,
  });

  final CieloThemeVariant variant;
  final ValueChanged<CieloThemeVariant> onVariantChanged;
  final double textScale;
  final ValueChanged<double> onTextScaleChanged;
  final bool reduceMotion;
  final ValueChanged<bool> onReduceMotionChanged;
  final bool leftHanded;
  final ValueChanged<bool> onLeftHandedChanged;

  @override
  State<DesignGalleryPage> createState() => _DesignGalleryPageState();
}

class _DesignGalleryPageState extends State<DesignGalleryPage> {
  String? _category = CategoryVisual.astronomy.code;
  final Set<String> _filterCategories = <String>{CategoryVisual.birds.code};
  String? _sky = SkyConditionVisual.clear.code;
  String? _direction = DirectionVisual.ne.code;
  Duration? _duration = const Duration(minutes: 5);
  bool _busy = false;
  Timer? _busyTimer;
  String? _lastResult;

  static final DateTime _now = DateTime(2026, 11, 22, 21, 30);

  @override
  void dispose() {
    _busyTimer?.cancel();
    super.dispose();
  }

  void _simulateSave() {
    setState(() => _busy = true);
    _busyTimer?.cancel();
    _busyTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _busy = false);
    });
  }

  void _showResult(String value) => setState(() => _lastResult = value);

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text(_G.title)),
      bottomNavigationBar: CieloActionBar(
        primaryLabel: CieloStrings.save,
        primaryIcon: Icons.check_rounded,
        onPrimary: _simulateSave,
        secondaryLabel: CieloStrings.saveDraft,
        onSecondary: () {},
        busy: _busy,
        leftHanded: widget.leftHanded,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CieloSpace.gutter, 0, CieloSpace.gutter, CieloSpace.xxl),
        children: <Widget>[
          // ── Controles ─────────────────────────────────────────────────
          const CieloSectionHeader(title: _G.controls),
          Text(_G.theme, style: text.labelLarge?.copyWith(color: c.textSecondary)),
          const SizedBox(height: CieloSpace.sm),
          Wrap(
            spacing: CieloSpace.sm,
            runSpacing: CieloSpace.sm,
            children: <Widget>[
              for (final (CieloThemeVariant v, String label, IconData icon) in <(CieloThemeVariant, String, IconData)>[
                (CieloThemeVariant.night, _G.night, Icons.dark_mode_rounded),
                (CieloThemeVariant.day, _G.day, Icons.light_mode_rounded),
                (CieloThemeVariant.astro, _G.astro, Icons.visibility_rounded),
              ])
                CieloChoiceChip(
                  label: label,
                  leading: Icon(icon),
                  selected: widget.variant == v,
                  onSelected: (_) => widget.onVariantChanged(v),
                ),
            ],
          ),
          const SizedBox(height: CieloSpace.lg),
          Text(_G.textSize, style: text.labelLarge?.copyWith(color: c.textSecondary)),
          const SizedBox(height: CieloSpace.sm),
          Wrap(
            spacing: CieloSpace.sm,
            runSpacing: CieloSpace.sm,
            children: <Widget>[
              for (final double scale in <double>[1.0, 1.3, 2.0])
                CieloChoiceChip(
                  label: '${(scale * 100).round()} %',
                  selected: widget.textScale == scale,
                  onSelected: (_) => widget.onTextScaleChanged(scale),
                ),
            ],
          ),
          const SizedBox(height: CieloSpace.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(_G.reduceMotion),
            value: widget.reduceMotion,
            onChanged: widget.onReduceMotionChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(_G.leftHanded),
            value: widget.leftHanded,
            onChanged: widget.onLeftHandedChanged,
          ),

          // ── Marca ─────────────────────────────────────────────────────
          const CieloSectionHeader(title: _G.brand, subtitle: _G.brandNote),
          const Align(alignment: Alignment.centerLeft, child: CieloBrandLockup()),

          // ── Colores ───────────────────────────────────────────────────
          const CieloSectionHeader(title: _G.colors, subtitle: _G.colorsNote),
          _Swatches(colors: c),

          // ── Tipografía ────────────────────────────────────────────────
          const CieloSectionHeader(title: _G.type),
          Text('9:42 p. m.', style: CieloTypography.tabular(text.displaySmall!)),
          Text('Leónidas sobre Valle Nuevo', style: text.headlineMedium),
          Text('Fenómeno atmosférico', style: text.titleMedium),
          const SizedBox(height: CieloSpace.xs),
          Text(
            'Más de cuarenta meteoros por hora con cielo despejado y sin luna. '
            'Bruma ligera hacia el sur.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: CieloSpace.xs),
          Text(
            CieloFormat.coordinates(18.8183, -70.6861),
            style: CieloTypography.tabular(text.bodyMedium!.copyWith(color: c.textSecondary)),
          ),

          // ── Categorías ────────────────────────────────────────────────
          const CieloSectionHeader(title: _G.categories),
          CategoryGrid(
            selectedCode: _category,
            onSelected: (CategoryVisual v) => setState(() => _category = v.code),
          ),
          const SizedBox(height: CieloSpace.lg),
          Text(_G.categoryFilters, style: text.labelLarge?.copyWith(color: c.textSecondary)),
          const SizedBox(height: CieloSpace.sm),
          Wrap(
            spacing: CieloSpace.sm,
            runSpacing: CieloSpace.sm,
            children: <Widget>[
              for (final CategoryVisual v in CategoryVisual.all)
                CategoryChip(
                  category: v,
                  selected: _filterCategories.contains(v.code),
                  onSelected: (bool s) => setState(
                    () => s ? _filterCategories.add(v.code) : _filterCategories.remove(v.code),
                  ),
                ),
            ],
          ),

          // ── Cielo, dirección y duración ───────────────────────────────
          const CieloSectionHeader(title: _G.sky),
          SkyConditionSelector(selectedCode: _sky, onChanged: (String? v) => setState(() => _sky = v)),
          const CieloSectionHeader(title: _G.direction),
          DirectionSelector(
            selectedCode: _direction,
            onChanged: (String? v) => setState(() => _direction = v),
          ),
          const CieloSectionHeader(title: _G.duration, subtitle: CieloStrings.durationOptional),
          DurationPicker(value: _duration, onChanged: (Duration? v) => setState(() => _duration = v)),

          // ── Tarjetas ──────────────────────────────────────────────────
          const CieloSectionHeader(title: _G.cards),
          ObservationCard(
            title: 'Lluvia de Leónidas sobre Valle Nuevo',
            category: CategoryVisual.astronomy,
            whenLabel: CieloFormat.dateTime(DateTime(2026, 11, 17, 2, 40), now: _now),
            placeLabel: 'Valle Nuevo, Constanza',
            photoCount: 3,
            audioCount: 1,
            location: ObservationCardLocation.gps,
            thumbnail: const _DemoNightPhoto(),
            onTap: () {},
          ),
          const SizedBox(height: CieloSpace.md),
          ObservationCard(
            title: 'Halo solar de 22°',
            category: CategoryVisual.atmospheric,
            whenLabel: CieloFormat.dateTime(DateTime(2026, 11, 21, 11, 5), now: _now),
            placeLabel: 'Santiago de los Caballeros',
            isDraft: true,
            location: ObservationCardLocation.manual,
            onTap: () {},
          ),
          const SizedBox(height: CieloSpace.md),
          ObservationCard(
            title: 'Bandada de garzas hacia el oeste',
            category: CategoryVisual.birds,
            whenLabel: CieloFormat.dateTime(DateTime(2026, 11, 20, 17, 48), now: _now),
            onTap: () {},
          ),
          const SizedBox(height: CieloSpace.md),
          ObservationCard(
            title: 'Estación Espacial cruzando hacia el noreste',
            category: CategoryVisual.artificial,
            whenLabel: CieloFormat.dateTime(DateTime(2025, 12, 3, 19, 12), now: _now),
            placeLabel: 'Malecón de Santo Domingo',
            audioCount: 2,
            location: ObservationCardLocation.gps,
            onTap: () {},
          ),

          // ── Insignias y avisos ────────────────────────────────────────
          const CieloSectionHeader(title: _G.badges),
          const Wrap(
            spacing: CieloSpace.sm,
            runSpacing: CieloSpace.sm,
            children: <Widget>[
              CieloBadge(label: CieloStrings.draft, tone: CieloTone.warning, icon: Icons.edit_note_rounded),
              CieloBadge(label: CieloStrings.gpsLocation, icon: Icons.gps_fixed_rounded),
              CieloBadge(label: CieloStrings.skySaharanDust, tone: CieloTone.info, icon: Icons.grain_rounded),
              CieloBadge(label: CieloStrings.noLocation, tone: CieloTone.danger, icon: Icons.location_off_rounded),
            ],
          ),
          const SizedBox(height: CieloSpace.md),
          CieloBanner(
            tone: CieloTone.warning,
            icon: Icons.location_off_rounded,
            message: CieloStrings.errorLocationDenied,
            actionLabel: CieloStrings.writePlace,
            onAction: () {},
            secondaryActionLabel: CieloStrings.openSettings,
            onSecondaryAction: () {},
          ),
          const SizedBox(height: CieloSpace.sm),
          CieloBanner(
            tone: CieloTone.info,
            icon: Icons.gps_not_fixed_rounded,
            message: CieloStrings.errorGpsTimeout(38),
            actionLabel: CieloStrings.retry,
            onAction: () {},
          ),
          const SizedBox(height: CieloSpace.sm),
          CieloBanner(
            tone: CieloTone.danger,
            message: CieloStrings.errorSave,
            actionLabel: CieloStrings.retry,
            onAction: () {},
            onDismiss: () {},
          ),

          // ── Estados ───────────────────────────────────────────────────
          const CieloSectionHeader(title: _G.states),
          _StateFrame(
            child: CieloEmptyState(
              title: CieloStrings.emptyDiaryTitle,
              message: CieloStrings.emptyDiaryMessage,
              actionLabel: CieloStrings.emptyDiaryAction,
              onAction: () {},
            ),
          ),
          const SizedBox(height: CieloSpace.md),
          _StateFrame(
            child: CieloEmptyState(
              icon: Icons.travel_explore_rounded,
              title: CieloStrings.noResultsTitle,
              message: CieloStrings.noResultsMessage('Perseidas'),
              secondaryActionLabel: CieloStrings.clearFilters,
              onSecondaryAction: () {},
            ),
          ),
          const SizedBox(height: CieloSpace.md),
          _StateFrame(
            child: CieloErrorState(message: CieloStrings.errorLoadObservations, onRetry: () {}),
          ),

          // ── Diálogos ──────────────────────────────────────────────────
          const CieloSectionHeader(title: _G.dialogs),
          Wrap(
            spacing: CieloSpace.sm,
            runSpacing: CieloSpace.sm,
            children: <Widget>[
              OutlinedButton(
                onPressed: () async {
                  final bool ok = await showCieloConfirmDialog(
                    context,
                    title: CieloStrings.deleteObservationTitle,
                    message: CieloStrings.deleteObservationMessage,
                    confirmLabel: CieloStrings.delete,
                    destructive: true,
                  );
                  _showResult(ok ? CieloStrings.delete : CieloStrings.cancel);
                },
                child: const Text(_G.openDelete),
              ),
              OutlinedButton(
                onPressed: () async {
                  final bool ok = await showCieloDangerConfirmDialog(
                    context,
                    title: CieloStrings.eraseAllTitle,
                    message: CieloStrings.eraseAllMessage,
                    confirmLabel: CieloStrings.eraseAllAction,
                    consequences: <String>[
                      CieloStrings.eraseAllObservations(37),
                      CieloStrings.eraseAllPhotos(52),
                      CieloStrings.eraseAllAudios(8),
                      CieloStrings.eraseAllProfile,
                    ],
                    footnote: CieloStrings.eraseAllKeepsExternal,
                  );
                  _showResult(ok ? CieloStrings.eraseAllDone : CieloStrings.cancel);
                },
                child: const Text(_G.openEraseAll),
              ),
              OutlinedButton(
                onPressed: () async {
                  final UnsavedChangesDecision d = await showUnsavedChangesSheet(context);
                  _showResult(d.name);
                },
                child: const Text(_G.openUnsaved),
              ),
            ],
          ),
          if (_lastResult != null)
            Padding(
              padding: const EdgeInsets.only(top: CieloSpace.sm),
              child: Semantics(
                liveRegion: true,
                child: Text(_G.result(_lastResult!), style: text.bodyMedium),
              ),
            ),

          // ── Carga ─────────────────────────────────────────────────────
          const CieloSectionHeader(title: _G.loading),
          const CieloSkeletonList(count: 2),
        ],
      ),
    );
  }
}

class _StateFrame extends StatelessWidget {
  const _StateFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    return Container(
      height: 520,
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: CieloRadius.cardAll,
        border: Border.all(color: c.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.colors});

  final CieloColors colors;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Map<String, Color> tokens = Map<String, Color>.of(colors.tokens)..remove('scrim');
    return Wrap(
      spacing: CieloSpace.sm,
      runSpacing: CieloSpace.sm,
      children: <Widget>[
        for (final MapEntry<String, Color> e in tokens.entries)
          Container(
            width: 152,
            decoration: BoxDecoration(
              color: colors.surface1,
              borderRadius: CieloRadius.tileAll,
              border: Border.all(color: colors.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(height: 40, color: e.value),
                Padding(
                  padding: const EdgeInsets.all(CieloSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(e.key, style: text.labelMedium),
                      Text(
                        '#${(e.value.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
                        '  ${contrastRatio(e.value, colors.background).toStringAsFixed(1)}:1',
                        style: CieloTypography.tabular(text.bodySmall!.copyWith(color: colors.textSecondary)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Foto nocturna simulada (degradado con estrellas) para mostrar el filtro
/// rojo de medios en modo astrónomo sin empaquetar imágenes de terceros.
class _DemoNightPhoto extends StatelessWidget {
  const _DemoNightPhoto();

  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _DemoNightPainter());
}

class _DemoNightPainter extends CustomPainter {
  const _DemoNightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0B1240), Color(0xFF2B3B85), Color(0xFFE08A3C)],
          stops: <double>[0, 0.7, 1],
        ).createShader(rect),
    );
    final Paint star = Paint()..color = const Color(0xFFFFFFFF);
    for (final Offset o in const <Offset>[
      Offset(0.2, 0.2), Offset(0.7, 0.12), Offset(0.45, 0.35), Offset(0.85, 0.4), Offset(0.15, 0.55), //
    ]) {
      canvas.drawCircle(Offset(o.dx * size.width, o.dy * size.height), 1.2, star);
    }
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.15),
      Offset(size.width * 0.62, size.height * 0.45),
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(0, size.height * 0.82)
        ..lineTo(size.width * 0.3, size.height * 0.7)
        ..lineTo(size.width * 0.55, size.height * 0.8)
        ..lineTo(size.width * 0.8, size.height * 0.66)
        ..lineTo(size.width, size.height * 0.78)
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = const Color(0xFF050814),
    );
  }

  @override
  bool shouldRepaint(_DemoNightPainter oldDelegate) => false;
}
