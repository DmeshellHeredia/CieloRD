import 'package:flutter/material.dart';

import '../../app/app_identity.dart';
import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../../l10n/cielo_strings.dart';
import '../glyphs/cielo_glyph.dart';

/// Firma de CieloRD: marca + nombre + matrícula.
///
/// [studentId] permite vistas de prueba; en producción usa la matrícula
/// académica definitiva.
class CieloBrandLockup extends StatelessWidget {
  const CieloBrandLockup({
    super.key,
    this.studentId = AppIdentity.studentId,
    this.markSize = 56,
  });

  final String studentId;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String visibleStudentId = studentId.trim().isEmpty
        ? AppIdentity.studentId
        : studentId.trim();
    return Semantics(
      label: '${CieloStrings.appName}. $visibleStudentId',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CieloBrandMark(size: markSize),
          const SizedBox(width: CieloSpace.md),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(CieloStrings.appName, style: text.headlineLarge),
                Text(
                  visibleStudentId,
                  style: text.labelLarge?.copyWith(
                    color: c.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marca sobre su disco de fondo, como en el icono de la app.
class CieloBrandMark extends StatelessWidget {
  const CieloBrandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          // La marca conserva el fondo Abismo en Día y Noche, como el icono.
          color: c.isAstro ? c.surface2 : CieloColors.night.background,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: c.outline),
        ),
        padding: EdgeInsets.all(size * 0.16),
        child: CustomPaint(
          painter: CieloGlyphPainter(
            CieloGlyph.brandMark,
            c.isAstro ? c.textPrimary : CieloColors.night.accent,
          ),
        ),
      ),
    );
  }
}
