import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../../l10n/cielo_strings.dart';
import 'cielo_tone.dart';

/// Aviso en línea para permisos, errores recuperables y estados de GPS.
///
/// Se anuncia como región viva: TalkBack lo lee al aparecer. La acción
/// principal y la secundaria se colocan debajo del texto, alineadas al final,
/// para que no compitan por ancho con texto grande.
class CieloBanner extends StatelessWidget {
  const CieloBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = CieloTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.onDismiss,
  });

  final String message;
  final String? title;
  final CieloTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final CieloToneColors colors = CieloToneColors.of(tone, CieloColors.of(context));
    final TextTheme text = Theme.of(context).textTheme;
    final ButtonStyle actionStyle = TextButton.styleFrom(foregroundColor: colors.foreground);
    final bool hasActions = (actionLabel != null && onAction != null) ||
        (secondaryActionLabel != null && onSecondaryAction != null);

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.background, borderRadius: CieloRadius.tileAll),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(CieloSpace.lg, CieloSpace.md, CieloSpace.xs, CieloSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(icon ?? colors.icon, color: colors.foreground),
                  ),
                  const SizedBox(width: CieloSpace.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: CieloSpace.md, bottom: CieloSpace.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (title != null)
                            Text(title!, style: text.titleSmall?.copyWith(color: colors.foreground)),
                          Text(message, style: text.bodyMedium?.copyWith(color: colors.foreground)),
                        ],
                      ),
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      tooltip: CieloStrings.close,
                      onPressed: onDismiss,
                      icon: Icon(Icons.close_rounded, color: colors.foreground),
                    ),
                ],
              ),
              if (hasActions)
                Wrap(
                  alignment: WrapAlignment.end,
                  children: <Widget>[
                    if (secondaryActionLabel != null && onSecondaryAction != null)
                      TextButton(style: actionStyle, onPressed: onSecondaryAction, child: Text(secondaryActionLabel!)),
                    if (actionLabel != null && onAction != null)
                      TextButton(style: actionStyle, onPressed: onAction, child: Text(actionLabel!)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
