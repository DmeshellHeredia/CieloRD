import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/contracts.dart';
import '../../../design/design.dart';
import '../../../l10n/cielo_format.dart';
import '../../../l10n/cielo_strings.dart';
import '../../../ui_kit/ui_kit.dart';
import 'backup_messages.dart';
import 'backup_progress_view.dart';

enum _Stage { choose, inspecting, preview, importing, done }

/// Importación en dos pasos: revisar la copia entera y confirmar.
class ImportScreen extends StatefulWidget {
  const ImportScreen({
    super.key,
    required this.backup,
    required this.documents,
    this.onImported,
  });

  final BackupService backup;
  final DocumentGateway documents;

  /// Se llama tras una importación que cambió datos.
  final VoidCallback? onImported;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  _Stage _stage = _Stage.choose;
  BackupInspection? _inspection;
  ImportReport? _report;
  AppFailure? _failure;

  bool get _busy => _stage == _Stage.inspecting || _stage == _Stage.importing;

  @override
  void dispose() {
    final BackupInspection? pending = _inspection;
    if (pending != null) {
      unawaited(widget.backup.discardInspection(pending.token));
    }
    super.dispose();
  }

  Future<void> _choose() async {
    setState(() {
      _failure = null;
      _stage = _Stage.inspecting;
    });
    final BackupInspection? previous = _inspection;
    _inspection = null;
    if (previous != null) {
      await widget.backup.discardInspection(previous.token);
    }
    Result<BackupInspection>? result;
    try {
      final Uri? source = await widget.documents.openDocument(
        // Algunos gestores de archivos no declaran bien el tipo ZIP.
        mimeTypes: const <String>[
          'application/zip',
          'application/x-zip-compressed',
          'application/octet-stream',
        ],
      );
      if (source != null) result = await widget.backup.inspect(source);
    } on Object {
      result = Failure<BackupInspection>(AppFailure(FailureCode.io));
    }
    if (!mounted) {
      if (result case Success<BackupInspection>(:final value)) {
        await widget.backup.discardInspection(value.token);
      }
      return;
    }
    setState(() {
      switch (result) {
        case null:
          _stage = _Stage.choose;
        case Success<BackupInspection>(:final BackupInspection value):
          _inspection = value;
          _stage = _Stage.preview;
        case Failure<BackupInspection>(:final AppFailure failure):
          _failure = failure;
          _stage = _Stage.choose;
      }
    });
  }

  Future<void> _import() async {
    setState(() {
      _failure = null;
      _stage = _Stage.importing;
    });
    final Result<ImportReport> result = await widget.backup.importZip(
      _inspection!.token,
    );
    if (result is Success<ImportReport>) {
      _inspection = null;
      widget.onImported?.call();
    }
    if (!mounted) return;
    setState(() {
      switch (result) {
        case Success<ImportReport>(:final ImportReport value):
          _report = value;
          _stage = _Stage.done;
        case Failure<ImportReport>(:final AppFailure failure):
          _failure = failure;
          _stage = failure.fieldErrors['backup'] == BackupErrors.expired
              ? _Stage.choose
              : _Stage.preview;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final BackupInspection? inspection = _inspection;
    return PopScope<Object?>(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text(CieloStrings.importTitle)),
        body: ListView(
          padding: const EdgeInsets.all(CieloSpace.gutter),
          children: <Widget>[
            if (_failure != null) ...<Widget>[
              CieloBanner(
                tone: CieloTone.danger,
                title: CieloStrings.importFailed,
                message:
                    '${BackupMessages.importFailure(_failure!)} '
                    '${CieloStrings.importFailedSuffix}',
              ),
              const SizedBox(height: CieloSpace.lg),
            ],
            ...switch (_stage) {
              _Stage.choose => _intro(context),
              _Stage.inspecting => <Widget>[
                BackupProgressView(
                  title: CieloStrings.importInspecting,
                  progress: widget.backup.progress,
                ),
              ],
              _Stage.preview when inspection != null => _preview(
                context,
                inspection,
              ),
              _Stage.importing => <Widget>[
                BackupProgressView(
                  title: CieloStrings.importing,
                  progress: widget.backup.progress,
                ),
              ],
              _Stage.done => _done(),
              _ => _intro(context),
            },
          ],
        ),
        bottomNavigationBar: _bar(inspection),
      ),
    );
  }

  Widget _bar(BackupInspection? inspection) => switch (_stage) {
    _Stage.preview when inspection != null => CieloActionBar(
      primaryLabel: CieloStrings.importTitle,
      primaryIcon: Icons.download_done_rounded,
      onPrimary: _hasChanges(inspection) ? _import : null,
      secondaryLabel: CieloStrings.importChoose,
      onSecondary: _choose,
    ),
    _Stage.done => CieloActionBar(
      primaryLabel: CieloStrings.done,
      onPrimary: () => Navigator.of(context).maybePop(),
    ),
    _ => CieloActionBar(
      primaryLabel: CieloStrings.importChoose,
      primaryIcon: Icons.file_open_rounded,
      onPrimary: _choose,
      busy: _busy,
      busyLabel: _stage == _Stage.importing
          ? CieloStrings.importing
          : CieloStrings.importInspecting,
    ),
  };

  static bool _hasChanges(BackupInspection i) =>
      i.newCount + i.copyCount > 0 || i.willImportProfile;

  List<Widget> _intro(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return <Widget>[
      Text(CieloStrings.importIntro, style: text.bodyLarge),
      const SizedBox(height: CieloSpace.md),
      Text(
        CieloStrings.importMerge,
        style: text.bodyMedium?.copyWith(color: c.textSecondary),
      ),
    ];
  }

  List<Widget> _preview(BuildContext context, BackupInspection i) {
    final int missing = i.warnings
        .where((String w) => w.startsWith('missing_media:'))
        .map((String w) => int.tryParse(w.split(':').last) ?? 0)
        .fold(0, (int a, int b) => a + b);
    return <Widget>[
      const CieloSectionHeader(title: CieloStrings.importPreviewTitle),
      _Detail(CieloStrings.importObservations, '${i.observationCount}'),
      if (i.draftCount > 0)
        _Detail(CieloStrings.importDrafts, '${i.draftCount}'),
      _Detail(CieloStrings.importPhotos, '${i.photoCount}'),
      _Detail(CieloStrings.importAudios, '${i.audioCount}'),
      if (i.createdAt != null)
        _Detail(
          CieloStrings.importCreated,
          CieloFormat.dateLong(i.createdAt!.toLocal()),
        ),
      _Detail(CieloStrings.importVersion, i.appVersion),
      _Detail(CieloStrings.importFormat, '${i.formatVersion}'),
      const CieloSectionHeader(title: CieloStrings.importPlanTitle),
      if (!_hasChanges(i))
        const CheckLines(lines: <String>[CieloStrings.importNothing]),
      CheckLines(
        lines: <String>[
          if (i.newCount > 0) CieloStrings.importNew(i.newCount),
          if (i.copyCount > 0) CieloStrings.importCopies(i.copyCount),
          if (i.identicalCount > 0)
            CieloStrings.importIdentical(i.identicalCount),
          if (i.hasProfile)
            i.willImportProfile
                ? CieloStrings.importProfileYes
                : CieloStrings.importProfileNo,
        ],
      ),
      if (missing > 0)
        CieloBanner(
          tone: CieloTone.warning,
          message: CieloStrings.importMissing(missing),
        ),
    ];
  }

  List<Widget> _done() => <Widget>[
    CieloBanner(
      tone: CieloTone.success,
      title: CieloStrings.importDone,
      message: CieloStrings.importSummary(
        _report!.importedObservations,
        _report!.importedMedia,
      ),
    ),
    const SizedBox(height: CieloSpace.lg),
    CheckLines(
      lines: <String>[
        if (_report!.importedAsCopies > 0)
          CieloStrings.importCopiesDone(_report!.importedAsCopies),
        if (_report!.skippedIdentical > 0)
          CieloStrings.importIdenticalDone(_report!.skippedIdentical),
        if (_report!.profileImported) CieloStrings.importProfileDone,
      ],
    ),
  ];
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: CieloSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: text.bodyLarge?.copyWith(color: c.textSecondary),
              ),
            ),
            const SizedBox(width: CieloSpace.md),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: text.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
