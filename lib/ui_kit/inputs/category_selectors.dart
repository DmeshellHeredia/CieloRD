import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../glyphs/cielo_glyph.dart';
import '../visuals/cielo_visuals.dart';
import 'cielo_choice_chip.dart';

/// Chip de categoría para filtros (selección múltiple por defecto).
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onSelected,
    this.multiSelect = true,
  });

  final CategoryVisual category;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    return CieloChoiceChip(
      label: category.shortLabel,
      semanticLabel: category.label,
      selected: selected,
      onSelected: onSelected,
      mutuallyExclusive: !multiSelect,
      leading: CieloGlyphIcon(
        category.glyph,
        size: CieloSize.iconSm + 2,
        color: selected ? c.onPrimaryContainer : category.tint(c),
      ),
    );
  }
}

/// Cuadrícula de categorías grandes para el registro rápido y el formulario.
///
/// Selección única. Cada casilla mide al menos 88 dp de alto para tocarla
/// con el pulgar sin mirar con detalle. Se adapta a 3 columnas en teléfono y
/// 5 en pantallas anchas; con texto al 200 % las casillas crecen en altura.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.selectedCode,
    required this.onSelected,
    this.categories = CategoryVisual.all,
  });

  final String? selectedCode;
  final ValueChanged<CategoryVisual> onSelected;
  final List<CategoryVisual> categories;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = CieloSpace.sm;
        final int columns = constraints.maxWidth >= 520 ? 5 : 3;
        final double width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final CategoryVisual category in categories)
              SizedBox(
                width: width,
                child: _CategoryTile(
                  category: category,
                  selected: category.code == selectedCode,
                  onTap: () => onSelected(category),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.selected, required this.onTap});

  final CategoryVisual category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final Color fg = selected ? c.onPrimaryContainer : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: category.label,
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: CieloMotion.resolve(context, CieloMotion.fast),
        curve: CieloMotion.standard,
        decoration: ShapeDecoration(
          color: selected ? c.primaryContainer : c.surface1,
          shape: RoundedRectangleBorder(
            borderRadius: CieloRadius.tileAll,
            side: BorderSide(color: selected ? c.primary : c.outlineStrong, width: selected ? 2 : 1),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: CieloRadius.tileAll,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: CieloSpace.sm, vertical: CieloSpace.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        CieloGlyphIcon(
                          category.glyph,
                          size: CieloSize.iconLg,
                          color: selected ? c.onPrimaryContainer : category.tint(c),
                        ),
                        if (selected)
                          Positioned(
                            right: -10,
                            top: -6,
                            child: Icon(Icons.check_circle_rounded, size: CieloSize.iconSm, color: c.primary),
                          ),
                      ],
                    ),
                    const SizedBox(height: CieloSpace.sm),
                    Text(
                      category.shortLabel,
                      textAlign: TextAlign.center,
                      style: text.labelLarge?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
