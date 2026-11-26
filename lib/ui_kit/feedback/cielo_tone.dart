import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';

/// Tono semántico compartido por insignias y avisos.
enum CieloTone { neutral, info, success, warning, danger }

/// Par de colores (fondo y contenido) con contraste verificado para un tono.
@immutable
class CieloToneColors {
  const CieloToneColors(this.background, this.foreground, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;

  factory CieloToneColors.of(CieloTone tone, CieloColors c) => switch (tone) {
        CieloTone.neutral => CieloToneColors(c.surface3, c.textPrimary, Icons.info_outline_rounded),
        CieloTone.info => CieloToneColors(c.primaryContainer, c.onPrimaryContainer, Icons.info_outline_rounded),
        CieloTone.success =>
          CieloToneColors(c.primaryContainer, c.onPrimaryContainer, Icons.check_circle_outline_rounded),
        CieloTone.warning =>
          CieloToneColors(c.accentContainer, c.onAccentContainer, Icons.warning_amber_rounded),
        CieloTone.danger => CieloToneColors(c.dangerContainer, c.onDangerContainer, Icons.error_outline_rounded),
      };
}
