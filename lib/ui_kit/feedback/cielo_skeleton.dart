import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../../l10n/cielo_strings.dart';

/// Lista de tarjetas-esqueleto mientras cargan las observaciones.
///
/// Pulsa suavemente; con movimiento reducido queda estática. TalkBack lee
/// una sola etiqueta ([semanticLabel]) en lugar de cada bloque.
class CieloSkeletonList extends StatefulWidget {
  const CieloSkeletonList({
    super.key,
    this.count = 3,
    this.semanticLabel = CieloStrings.loadingObservations,
  });

  final int count;
  final String semanticLabel;

  @override
  State<CieloSkeletonList> createState() => _CieloSkeletonListState();
}

class _CieloSkeletonListState extends State<CieloSkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.55,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CieloMotion.isReduced(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      excludeSemantics: true,
      child: FadeTransition(
        opacity: _controller,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < widget.count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: CieloSpace.md),
                child: _SkeletonCard(color: c.surface2, background: c.surface1),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
          widthFactor: widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
            height: height,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(CieloSpace.lg),
      decoration: BoxDecoration(color: background, borderRadius: CieloRadius.cardAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: CieloSize.thumbnail,
            height: CieloSize.thumbnail,
            decoration: BoxDecoration(color: color, borderRadius: CieloRadius.tileAll),
          ),
          const SizedBox(width: CieloSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                bar(0.8, 16),
                const SizedBox(height: CieloSpace.sm),
                bar(0.5, 12),
                const SizedBox(height: CieloSpace.sm),
                bar(0.35, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
