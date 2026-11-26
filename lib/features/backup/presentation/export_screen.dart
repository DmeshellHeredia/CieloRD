import 'package:flutter/material.dart';

import '../../../app/contracts.dart';
import '../../../design/design.dart';
import '../../../l10n/cielo_strings.dart';
import '../../../ui_kit/ui_kit.dart';
import 'backup_messages.dart';
import 'backup_progress_view.dart';

/// Exportación a un archivo elegido con el selector del sistema.
class ExportScreen extends StatefulWidget {
  const ExportScreen({
    super.key,
    required this.backup,
    required this.documents,
    this.clock,
  });

  final BackupService backup;
  final DocumentGateway documents;
  final DateTime Function()? clock;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  BackupFormat _format = BackupFormat.zipComplete;
  bool _includeProfile = true;
  bool _busy = false;
  Result<BackupReceipt>? _result;

  String _fileName() {
    final DateTime now = (widget.clock ?? DateTime.now)();
    String two(int n) => n.toString().padLeft(2, '0');
    final String stamp =
        '${now.year}-${two(now.month)}-${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}';
    return switch (_format) {
      BackupFormat.zipComplete => 'CieloRD-copia-$stamp.zip',
      BackupFormat.jsonMetadata => 'CieloRD-datos-$stamp.json',
    };
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    Result<BackupReceipt>? result;
    try {
      final Uri? destination = await widget.documents.createDocument(
        suggestedName: _fileName(),
        mimeType: _format == BackupFormat.zipComplete
            ? 'application/zip'
            : 'application/json',
      );
      if (destination != null) {
        result = await widget.backup.export(
          filter: ObservationFilter(status: null),
          format: _format,
          destination: destination,
          includeProfile: _includeProfile,
        );
      }
    } on Object {
      result = Failure<BackupReceipt>(AppFailure(FailureCode.io));
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return PopScope<Object?>(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text(CieloStrings.exportTitle)),
        body: ListView(
          padding: const EdgeInsets.all(CieloSpace.gutter),
          children: <Widget>[
            if (_busy)
              BackupProgressView(
                title: CieloStrings.exporting,
                progress: widget.backup.progress,
              )
            else ...<Widget>[
              ..._resultBanner(),
              _FormatOption(
                title: CieloStrings.exportZip,
                subtitle: CieloStrings.exportZipHint,
                icon: Icons.folder_zip_outlined,
                selected: _format == BackupFormat.zipComplete,
                onTap: () => setState(() => _format = BackupFormat.zipComplete),
              ),
              const SizedBox(height: CieloSpace.md),
              _FormatOption(
                title: CieloStrings.exportJson,
                subtitle: CieloStrings.exportJsonHint,
                icon: Icons.data_object_rounded,
                selected: _format == BackupFormat.jsonMetadata,
                onTap: () =>
                    setState(() => _format = BackupFormat.jsonMetadata),
              ),
              const SizedBox(height: CieloSpace.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(CieloStrings.exportIncludeProfile),
                value: _includeProfile,
                onChanged: (bool on) => setState(() => _includeProfile = on),
              ),
              const SizedBox(height: CieloSpace.sm),
              Text(
                CieloStrings.exportPrivacy,
                style: text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            ],
          ],
        ),
        bottomNavigationBar: CieloActionBar(
          primaryLabel: CieloStrings.exportTitle,
          primaryIcon: Icons.ios_share_rounded,
          onPrimary: _export,
          busy: _busy,
          busyLabel: CieloStrings.exporting,
        ),
      ),
    );
  }

  List<Widget> _resultBanner() {
    final Widget? banner = switch (_result) {
      null => null,
      Success<BackupReceipt>(:final BackupReceipt value) => CieloBanner(
        tone: value.missingMedia > 0 ? CieloTone.warning : CieloTone.success,
        title: CieloStrings.exportDone,
        message: <String>[
          value.includesMedia
              ? CieloStrings.exportSummary(
                  value.observationCount,
                  value.mediaCount,
                )
              : '${CieloStrings.observationsCount(value.observationCount)}.',
          if (value.missingMedia > 0)
            CieloStrings.exportMissing(value.missingMedia),
        ].join(' '),
      ),
      Failure<BackupReceipt>(:final AppFailure failure) => CieloBanner(
        tone: CieloTone.danger,
        title: CieloStrings.exportFailed,
        message: BackupMessages.exportFailure(failure),
      ),
    };
    return <Widget>[
      if (banner != null) ...<Widget>[
        banner,
        const SizedBox(height: CieloSpace.lg),
      ],
    ];
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? c.primaryContainer : c.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: CieloRadius.tileAll,
          side: BorderSide(
            color: selected ? c.primary : c.outlineStrong,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(CieloSpace.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  selected ? Icons.check_circle_rounded : icon,
                  color: selected ? c.onPrimaryContainer : c.textSecondary,
                ),
                const SizedBox(width: CieloSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: text.titleMedium?.copyWith(
                          color: selected
                              ? c.onPrimaryContainer
                              : c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: CieloSpace.xxs),
                      Text(
                        subtitle,
                        style: text.bodyMedium?.copyWith(
                          color: selected
                              ? c.onPrimaryContainer
                              : c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
