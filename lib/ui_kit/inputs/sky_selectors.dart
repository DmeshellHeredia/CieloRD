import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../../l10n/cielo_strings.dart';
import '../visuals/cielo_visuals.dart';
import 'cielo_choice_chip.dart';

/// Selector de condición del cielo (selección única, opcional).
///
/// Tocar la opción seleccionada la desmarca si [allowDeselect] es `true`.
class SkyConditionSelector extends StatelessWidget {
  const SkyConditionSelector({
    super.key,
    required this.selectedCode,
    required this.onChanged,
    this.options = SkyConditionVisual.all,
    this.allowDeselect = true,
  });

  final String? selectedCode;
  final ValueChanged<String?> onChanged;
  final List<SkyConditionVisual> options;
  final bool allowDeselect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: CieloStrings.skyConditionLabel,
      child: Wrap(
        spacing: CieloSpace.sm,
        runSpacing: CieloSpace.sm,
        children: <Widget>[
          for (final SkyConditionVisual option in options)
            CieloChoiceChip(
              label: option.label,
              semanticLabel: option.hint == null ? option.label : '${option.label}, ${option.hint}',
              selected: option.code == selectedCode,
              leading: Icon(option.icon),
              onSelected: (bool selected) {
                if (selected) {
                  onChanged(option.code);
                } else if (allowDeselect) {
                  onChanged(null);
                }
              },
            ),
        ],
      ),
    );
  }
}

/// Rosa de los vientos de 8 puntos en cuadrícula 3×3.
///
/// La casilla central quita la dirección. Cada casilla mide al menos 56 dp,
/// cómoda para el pulgar. Las abreviaturas son visibles y TalkBack lee el
/// nombre completo ("Noroeste").
class DirectionSelector extends StatelessWidget {
  const DirectionSelector({
    super.key,
    required this.selectedCode,
    required this.onChanged,
  });

  final String? selectedCode;
  final ValueChanged<String?> onChanged;

  static const List<List<DirectionVisual?>> _layout = <List<DirectionVisual?>>[
    <DirectionVisual?>[DirectionVisual.nw, DirectionVisual.n, DirectionVisual.ne],
    <DirectionVisual?>[DirectionVisual.w, null, DirectionVisual.e],
    <DirectionVisual?>[DirectionVisual.sw, DirectionVisual.s, DirectionVisual.se],
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: CieloStrings.directionLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final List<DirectionVisual?> row in _layout)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: CieloSpace.xs / 2),
                child: Row(
                  children: <Widget>[
                    for (final DirectionVisual? cell in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: CieloSpace.xs / 2),
                          child: cell == null
                              ? _DirectionCell.center(
                                  selected: selectedCode == null,
                                  onTap: () => onChanged(null),
                                )
                              : _DirectionCell(
                                  label: cell.abbreviation,
                                  semanticLabel: cell.label,
                                  selected: cell.code == selectedCode,
                                  onTap: () => onChanged(cell.code),
                                ),
                        ),
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

class _DirectionCell extends StatelessWidget {
  const _DirectionCell({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  }) : isCenter = false;

  const _DirectionCell.center({required this.selected, required this.onTap})
      : label = '',
        semanticLabel = CieloStrings.directionNone,
        isCenter = true;

  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;
  final bool isCenter;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final Color fg = selected ? c.onPrimaryContainer : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: CieloMotion.resolve(context, CieloMotion.fast),
        decoration: ShapeDecoration(
          color: selected ? c.primaryContainer : (isCenter ? c.surface2 : c.surface1),
          shape: RoundedRectangleBorder(
            borderRadius: CieloRadius.chipAll,
            side: BorderSide(color: selected ? c.primary : c.outlineStrong, width: selected ? 2 : 1),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: CieloRadius.chipAll,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CieloSize.fieldTouch),
              child: Center(
                child: isCenter
                    ? Icon(Icons.explore_off_rounded, color: fg, size: CieloSize.iconMd)
                    : Text(label, style: text.titleMedium?.copyWith(color: fg)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
