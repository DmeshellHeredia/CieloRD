import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';

/// Chip seleccionable base de CieloRD.
///
/// * Altura visible mínima de 48 dp (no solo el área táctil).
/// * El estado seleccionado se comunica con relleno, borde grueso **y** una
///   marca de verificación, nunca solo con color.
/// * Expone `selected` y, si [mutuallyExclusive], pertenencia a grupo
///   exclusivo para TalkBack.
class CieloChoiceChip extends StatelessWidget {
  const CieloChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.leading,
    this.semanticLabel,
    this.mutuallyExclusive = true,
  });

  final String label;
  final bool selected;

  /// Recibe el nuevo estado deseado. Nulo deshabilita el chip.
  final ValueChanged<bool>? onSelected;
  final Widget? leading;

  /// Etiqueta alternativa para lectores de pantalla (por defecto, [label]).
  final String? semanticLabel;
  final bool mutuallyExclusive;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool enabled = onSelected != null;
    final Color fg = !enabled
        ? c.textSecondary
        : selected
            ? c.onPrimaryContainer
            : c.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: mutuallyExclusive,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: enabled ? () => onSelected!(!selected) : null,
      child: AnimatedContainer(
        duration: CieloMotion.resolve(context, CieloMotion.fast),
        curve: CieloMotion.standard,
        decoration: ShapeDecoration(
          color: selected ? c.primaryContainer : c.surface1,
          shape: RoundedRectangleBorder(
            borderRadius: CieloRadius.chipAll,
            side: BorderSide(
              color: selected ? c.primary : c.outlineStrong,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: CieloRadius.chipAll,
            onTap: enabled ? () => onSelected!(!selected) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CieloSize.minTouch, minWidth: CieloSize.minTouch),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: CieloSpace.md, vertical: CieloSpace.sm),
                child: IconTheme.merge(
                  data: IconThemeData(color: fg, size: CieloSize.iconSm + 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (leading != null) ...<Widget>[leading!, const SizedBox(width: CieloSpace.sm)],
                      Flexible(
                        child: Text(
                          label,
                          style: text.labelLarge?.copyWith(color: fg),
                          softWrap: true,
                        ),
                      ),
                      if (selected) ...<Widget>[
                        const SizedBox(width: CieloSpace.sm),
                        Icon(Icons.check_rounded, size: CieloSize.iconSm, color: fg),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
