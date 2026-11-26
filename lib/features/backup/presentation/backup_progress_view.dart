import 'package:flutter/material.dart';

import '../../../app/contracts.dart';
import '../../../design/design.dart';
import '../../../l10n/cielo_strings.dart';

/// Fase actual de una copia. Se anuncia al cambiar de fase.
class BackupProgressView extends StatelessWidget {
  const BackupProgressView({
    super.key,
    required this.title,
    required this.progress,
  });

  final String title;
  final Stream<BackupProgress> progress;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return StreamBuilder<BackupProgress>(
      stream: progress,
      builder: (BuildContext context, AsyncSnapshot<BackupProgress> snapshot) {
        final BackupProgress? value = snapshot.data;
        final int? total = value?.total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: CieloSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                liveRegion: true,
                child: Text(title, style: text.titleLarge),
              ),
              const SizedBox(height: CieloSpace.md),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: total == null || total == 0
                      ? null
                      : value!.completed / total,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: CieloSpace.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  value == null ? '' : CieloStrings.backupPhase(value.phase),
                  style: text.bodyMedium?.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Líneas con marca, para listas de "qué incluye" o "qué pasará".
class CheckLines extends StatelessWidget {
  const CheckLines({
    super.key,
    required this.lines,
    this.icon = Icons.check_rounded,
    this.color,
  });

  final List<String> lines;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: CieloSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    icon,
                    size: CieloSize.iconSm,
                    color: color ?? c.primary,
                  ),
                ),
                const SizedBox(width: CieloSpace.sm),
                Expanded(
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
