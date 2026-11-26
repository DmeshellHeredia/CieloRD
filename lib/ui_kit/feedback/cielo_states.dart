import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../../l10n/cielo_strings.dart';
import '../glyphs/cielo_glyph.dart';

/// Estado vacío: una invitación a actuar, no un mensaje de ánimo.
///
/// Se puede usar dentro de un área con altura (centra el contenido y
/// permite desplazamiento con texto grande) o dentro de una lista.
class CieloEmptyState extends StatelessWidget {
  const CieloEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.glyph = CieloGlyph.brandMark,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String message;

  /// Glifo central de la ilustración; [icon] lo reemplaza si se indica.
  final CieloGlyph glyph;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    return _StateLayout(
      illustration: _OrbitIllustration(
        ringColor: c.outlineStrong,
        starColor: c.accent,
        discColor: c.surface2,
        child: icon != null
            ? Icon(icon, size: 40, color: c.primary)
            : CieloGlyphIcon(glyph, size: 44, color: c.primary),
      ),
      title: title,
      message: message,
      primary: actionLabel != null && onAction != null
          ? FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.add_rounded),
              label: Text(actionLabel!),
            )
          : null,
      secondary: secondaryActionLabel != null && onSecondaryAction != null
          ? TextButton(onPressed: onSecondaryAction, child: Text(secondaryActionLabel!))
          : null,
    );
  }
}

/// Estado de error con reintento. Explica qué pasó y qué hacer; no se
/// disculpa ni es vago.
class CieloErrorState extends StatelessWidget {
  const CieloErrorState({
    super.key,
    required this.message,
    this.title = CieloStrings.errorTitle,
    this.onRetry,
    this.retryLabel = CieloStrings.retry,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: _StateLayout(
        illustration: _OrbitIllustration(
          ringColor: c.outlineStrong,
          starColor: c.danger,
          discColor: c.dangerContainer,
          child: Icon(Icons.error_outline_rounded, size: 40, color: c.onDangerContainer),
        ),
        title: title,
        message: message,
        primary: onRetry != null
            ? FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              )
            : null,
        secondary: secondaryActionLabel != null && onSecondaryAction != null
            ? TextButton(onPressed: onSecondaryAction, child: Text(secondaryActionLabel!))
            : null,
      ),
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.illustration,
    required this.title,
    required this.message,
    this.primary,
    this.secondary,
  });

  final Widget illustration;
  final String title;
  final String message;
  final Widget? primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CieloSpace.xl, vertical: CieloSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            illustration,
            const SizedBox(height: CieloSpace.xl),
            Semantics(
              header: true,
              child: Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
            ),
            const SizedBox(height: CieloSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: c.textSecondary),
            ),
            if (primary != null) ...<Widget>[const SizedBox(height: CieloSpace.xl), primary!],
            if (secondary != null) ...<Widget>[const SizedBox(height: CieloSpace.sm), secondary!],
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedHeight) return Center(child: content);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight, minWidth: constraints.maxWidth),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}

/// Disco con una órbita inclinada y dos estrellas: la ilustración propia de
/// los estados de CieloRD. Es decorativa y se excluye de la semántica.
class _OrbitIllustration extends StatelessWidget {
  const _OrbitIllustration({
    required this.child,
    required this.ringColor,
    required this.starColor,
    required this.discColor,
  });

  final Widget child;
  final Color ringColor;
  final Color starColor;
  final Color discColor;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 128,
        child: CustomPaint(
          painter: _OrbitPainter(ringColor: ringColor, starColor: starColor, discColor: discColor),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.ringColor, required this.starColor, required this.discColor});

  final Color ringColor;
  final Color starColor;
  final Color discColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    canvas.drawCircle(center, size.width * 0.34, Paint()..color = discColor);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 9);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size.width * 0.96, height: size.height * 0.36),
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
    final Paint star = Paint()..color = starColor;
    canvas.drawPath(CieloGlyphPainter.sparkle(Offset(size.width * 0.86, size.height * 0.16), 6), star);
    canvas.drawPath(CieloGlyphPainter.sparkle(Offset(size.width * 0.12, size.height * 0.78), 3.5), star);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.ringColor != ringColor || old.starColor != starColor || old.discColor != discColor;
}
