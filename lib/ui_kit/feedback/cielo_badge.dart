import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import 'cielo_tone.dart';

/// Insignia informativa no interactiva (p. ej., "Borrador", "GPS", "2 fotos").
///
/// Siempre lleva icono y texto. [icon] sustituye al icono del tono.
class CieloBadge extends StatelessWidget {
  const CieloBadge({
    super.key,
    required this.label,
    this.tone = CieloTone.neutral,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final CieloTone tone;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final CieloToneColors colors = CieloToneColors.of(tone, CieloColors.of(context));
    final TextStyle? style = Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.foreground);
    return Semantics(
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(CieloRadius.badge),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CieloSpace.md - 2, vertical: CieloSpace.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon ?? colors.icon, size: 16, color: colors.foreground),
              const SizedBox(width: CieloSpace.xs),
              Flexible(child: Text(label, style: style)),
            ],
          ),
        ),
      ),
    );
  }
}
