import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../../l10n/cielo_strings.dart';

/// Barra de acciones fija en la parte inferior (zona del pulgar).
///
/// * La acción principal mide 56 dp de alto (64 dp con [prominent]).
/// * Con texto grande o pantalla estrecha, los botones se apilan y la acción
///   principal queda abajo, más cerca del pulgar.
/// * [leftHanded] coloca la acción principal a la izquierda.
/// * Mientras [busy] es `true`, la acción principal se deshabilita y muestra
///   progreso con [busyLabel].
class CieloActionBar extends StatelessWidget {
  const CieloActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
    this.busyLabel = CieloStrings.saving,
    this.destructive = false,
    this.prominent = false,
    this.leftHanded = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final IconData? primaryIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;
  final String busyLabel;
  final bool destructive;
  final bool prominent;
  final bool leftHanded;

  /// Mide ambas etiquetas con el estilo y la escala de texto reales: si no
  /// caben en una línea cada una, los botones se apilan en lugar de partir
  /// el texto o desbordar.
  bool _fitsInRow(BuildContext context, double maxWidth) {
    final TextStyle style = Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 16);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    double measure(String label) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final double width = painter.width;
      painter.dispose();
      return width;
    }

    const double buttonPadding = CieloSpace.xl * 2;
    final double primaryIconWidth = primaryIcon == null ? 0 : CieloSize.iconMd + CieloSpace.sm;
    final double needed = measure(secondaryLabel!) +
        buttonPadding +
        CieloSpace.md +
        measure(busy ? busyLabel : primaryLabel) +
        primaryIconWidth +
        buttonPadding;
    return needed <= maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final double height = prominent ? CieloSize.heroTouch : CieloSize.fieldTouch;

    final Widget primary = FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: Size(0, height),
        backgroundColor: destructive ? c.dangerFilledBackground : null,
        foregroundColor: destructive ? c.onDangerFilled : null,
      ),
      onPressed: busy ? null : onPrimary,
      child: busy
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: c.textSecondary),
                ),
                const SizedBox(width: CieloSpace.md),
                Flexible(child: Text(busyLabel)),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (primaryIcon != null) ...<Widget>[Icon(primaryIcon), const SizedBox(width: CieloSpace.sm)],
                Flexible(child: Text(primaryLabel, textAlign: TextAlign.center)),
              ],
            ),
    );

    final Widget? secondary = secondaryLabel == null
        ? null
        : OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: Size(0, height)),
            onPressed: busy ? null : onSecondary,
            child: Text(secondaryLabel!, textAlign: TextAlign.center),
          );

    return Material(
      color: c.surface1,
      shape: Border(top: BorderSide(color: c.outline)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(CieloSpace.lg, CieloSpace.md, CieloSpace.lg, CieloSpace.md),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (secondary == null) return SizedBox(width: double.infinity, child: primary);
              if (!_fitsInRow(context, constraints.maxWidth)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[secondary, const SizedBox(height: CieloSpace.sm), primary],
                );
              }
              // La secundaria ocupa su ancho natural; la principal, el resto.
              final List<Widget> row = <Widget>[
                secondary,
                const SizedBox(width: CieloSpace.md),
                Expanded(child: primary),
              ];
              return Row(children: leftHanded ? row.reversed.toList() : row);
            },
          ),
        ),
      ),
    );
  }
}

/// Encabezado de sección; se anuncia como encabezado a TalkBack.
class CieloSectionHeader extends StatelessWidget {
  const CieloSectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: CieloSpace.xl, bottom: CieloSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(header: true, child: Text(title, style: text.titleLarge)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: CieloSpace.xxs),
                    child: Text(subtitle!, style: text.bodyMedium?.copyWith(color: c.textSecondary)),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
