import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../../l10n/cielo_strings.dart';

/// Filtro activo que se quita con un toque ("Últimos 7 días ✕").
///
/// Todo el chip es el área táctil (≥ 48 dp) y TalkBack lo anuncia como
/// "Quitar filtro …".
class CieloRemovableChip extends StatelessWidget {
  const CieloRemovableChip({super.key, required this.label, required this.onRemove, this.icon});

  final String label;
  final VoidCallback onRemove;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextStyle? style = Theme.of(context).textTheme.labelLarge?.copyWith(color: c.onPrimaryContainer);
    return Semantics(
      button: true,
      label: CieloStrings.removeFilter(label),
      excludeSemantics: true,
      onTap: onRemove,
      child: Material(
        color: c.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CieloRadius.badge),
          side: BorderSide(color: c.primary),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onRemove,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CieloSize.minTouch),
            child: Padding(
              padding: const EdgeInsets.only(left: CieloSpace.md, right: CieloSpace.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: CieloSize.iconSm, color: c.onPrimaryContainer),
                    const SizedBox(width: CieloSpace.xs + 2),
                  ],
                  Flexible(child: Text(label, style: style)),
                  const SizedBox(width: CieloSpace.xs),
                  Icon(Icons.close_rounded, size: CieloSize.iconSm, color: c.onPrimaryContainer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón con forma de chip que abre el panel de filtros y muestra cuántos
/// filtros hay activos (además del cambio de estilo, para no depender del color).
class CieloFilterButton extends StatelessWidget {
  const CieloFilterButton({super.key, required this.activeCount, required this.onPressed});

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final bool active = activeCount > 0;
    final Color fg = active ? c.onPrimaryContainer : c.textPrimary;
    final String label = CieloStrings.filtersWithCount(activeCount);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: active ? c.primaryContainer : c.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: CieloRadius.chipAll,
          side: BorderSide(color: active ? c.primary : c.outlineStrong, width: active ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: CieloRadius.chipAll,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CieloSize.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CieloSpace.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.tune_rounded, size: CieloSize.iconSm + 2, color: fg),
                  const SizedBox(width: CieloSpace.sm),
                  Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
