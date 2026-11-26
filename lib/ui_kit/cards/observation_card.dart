import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../../l10n/cielo_strings.dart';
import '../feedback/cielo_badge.dart';
import '../feedback/cielo_tone.dart';
import '../glyphs/cielo_glyph.dart';
import '../visuals/cielo_visuals.dart';

/// Origen de la ubicación mostrado en la tarjeta.
enum ObservationCardLocation { none, gps, manual }

/// Tarjeta de observación para el Diario y los Borradores.
///
/// Es un componente de presentación: recibe textos ya formateados y no
/// conoce el modelo de datos. La pantalla traduce el modelo de Codex a estas
/// propiedades (ver `lib/ui_kit/README.md`).
///
/// * Metadatos en filas con icono (fecha, lugar), no unidos con separadores.
/// * Un borrador se distingue por borde ámbar **y** la insignia "Borrador".
/// * TalkBack lee la tarjeta como un único botón con resumen completo.
class ObservationCard extends StatelessWidget {
  const ObservationCard({
    super.key,
    required this.title,
    required this.category,
    required this.whenLabel,
    this.placeLabel,
    this.isDraft = false,
    this.photoCount = 0,
    this.audioCount = 0,
    this.location = ObservationCardLocation.none,
    this.thumbnail,
    this.heroTag,
    this.onTap,
    this.onLongPress,
    this.semanticWhen,
  });

  final String title;
  final CategoryVisual category;

  /// Fecha y hora ya formateadas, p. ej. `CieloFormat.dateTime(...)`.
  final String whenLabel;

  /// Versión larga de la fecha para TalkBack; por defecto [whenLabel].
  final String? semanticWhen;

  /// Lugar escrito o nombre derivado de las coordenadas.
  final String? placeLabel;
  final bool isDraft;
  final int photoCount;
  final int audioCount;
  final ObservationCardLocation location;

  /// Miniatura de la primera foto (p. ej. `Image.file` con `cacheWidth`).
  /// Si es nula se muestra el glifo de la categoría.
  final Widget? thumbnail;

  /// Etiqueta para la transición Hero hacia el detalle.
  final Object? heroTag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  String get _semanticSummary => <String>[
        if (isDraft) CieloStrings.draft,
        title,
        category.label,
        semanticWhen ?? whenLabel,
        if (placeLabel != null && placeLabel!.isNotEmpty) placeLabel!,
        if (photoCount > 0) CieloStrings.photos(photoCount),
        if (audioCount > 0) CieloStrings.voiceNotes(audioCount),
      ]
          // Evita ".." cuando una parte ya termina en punto ("p. m.").
          .map((String part) => part.endsWith('.') ? part.substring(0, part.length - 1) : part)
          .join('. ');

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    Widget leading = _Leading(category: category, thumbnail: thumbnail);
    if (heroTag != null) leading = Hero(tag: heroTag!, child: leading);

    final List<Widget> badges = <Widget>[
      if (isDraft)
        const CieloBadge(label: CieloStrings.draft, tone: CieloTone.warning, icon: Icons.edit_note_rounded),
      if (photoCount > 0)
        CieloBadge(label: '$photoCount', icon: Icons.photo_camera_rounded, semanticLabel: CieloStrings.photos(photoCount)),
      if (audioCount > 0)
        CieloBadge(label: '$audioCount', icon: Icons.mic_rounded, semanticLabel: CieloStrings.voiceNotes(audioCount)),
      if (location == ObservationCardLocation.gps)
        const CieloBadge(label: CieloStrings.gpsLocation, icon: Icons.gps_fixed_rounded),
      if (location == ObservationCardLocation.manual)
        const CieloBadge(label: CieloStrings.manualLocation, icon: Icons.edit_location_alt_rounded),
    ];

    return Semantics(
      button: onTap != null,
      label: _semanticSummary,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Material(
        color: c.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: CieloRadius.cardAll,
          side: isDraft ? BorderSide(color: c.accent, width: 1.5) : BorderSide(color: c.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(CieloSpace.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                leading,
                const SizedBox(width: CieloSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: text.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: CieloSpace.xs),
                      _MetaRow(icon: Icons.schedule_rounded, label: whenLabel),
                      if (placeLabel != null && placeLabel!.isNotEmpty)
                        _MetaRow(icon: Icons.place_rounded, label: placeLabel!),
                      if (badges.isNotEmpty) ...<Widget>[
                        const SizedBox(height: CieloSpace.sm),
                        Wrap(spacing: CieloSpace.xs + 2, runSpacing: CieloSpace.xs + 2, children: badges),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.category, required this.thumbnail});

  final CategoryVisual category;
  final Widget? thumbnail;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final Widget content;
    if (thumbnail != null) {
      final ColorFilter? filter = c.mediaFilter;
      content = filter == null ? thumbnail! : ColorFiltered(colorFilter: filter, child: thumbnail);
    } else {
      content = ColoredBox(
        color: Color.alphaBlend(category.tint(c).withValues(alpha: 0.14), c.surface2),
        child: Center(
          child: CieloGlyphIcon(category.glyph, size: 30, color: category.tint(c)),
        ),
      );
    }
    return ClipRRect(
      borderRadius: CieloRadius.tileAll,
      child: SizedBox.square(dimension: CieloSize.thumbnail, child: content),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(top: CieloSpace.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: c.textSecondary),
          ),
          const SizedBox(width: CieloSpace.xs + 2),
          Expanded(
            child: Text(label, style: style, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
