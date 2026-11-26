import 'package:flutter/material.dart';

import '../../../app/contracts.dart';
import '../../../design/design.dart';
import '../../../l10n/cielo_strings.dart';
import '../../../l10n/failure_messages.dart';
import '../../../ui_kit/ui_kit.dart';
import '../../backup/presentation/backup_progress_view.dart';

enum _Stage { counting, review, erasing, partial, done, failure }

/// Borrar Todo: conteos reales, confirmación inequívoca y resultado verificado.
/// Solo anuncia éxito si el servicio comprobó que no queda nada.
class EraseAllScreen extends StatefulWidget {
  const EraseAllScreen({
    super.key,
    required this.service,
    required this.onDataErased,
    required this.onGoToDiary,
    this.onExportFirst,
    this.interrupted = false,
  });

  final EraseAllService service;

  /// Se llama en cuanto la base queda vacía, aunque falten archivos: la app
  /// debe dejar de mostrar los datos que tenía en memoria.
  final VoidCallback onDataErased;
  final VoidCallback onGoToDiary;
  final void Function(BuildContext context)? onExportFirst;

  /// Un borrado anterior quedó a medias.
  final bool interrupted;

  @override
  State<EraseAllScreen> createState() => _EraseAllScreenState();
}

class _EraseAllScreenState extends State<EraseAllScreen> {
  _Stage _stage = _Stage.counting;
  EraseAllPreview? _preview;
  EraseAllReport? _report;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _count();
  }

  Future<void> _count() async {
    setState(() => _stage = _Stage.counting);
    final Result<EraseAllPreview> result = await widget.service.preview();
    if (!mounted) return;
    setState(() {
      switch (result) {
        case Success<EraseAllPreview>(:final EraseAllPreview value):
          _preview = value;
          _stage = _Stage.review;
        case Failure<EraseAllPreview>(:final AppFailure failure):
          // Unos datos ilegibles no impiden borrarlos.
          _failure = failure;
          _preview = null;
          _stage = _Stage.review;
      }
    });
  }

  Future<void> _confirm() async {
    final bool accepted = await showCieloDangerConfirmDialog(
      context,
      title: CieloStrings.eraseAllTitle,
      message: CieloStrings.eraseAllMessage,
      confirmLabel: CieloStrings.eraseAllAction,
      consequences: _consequences(),
      footnote: CieloStrings.eraseAllKeepsExternal,
    );
    if (accepted && mounted) await _erase();
  }

  Future<void> _erase() async {
    setState(() {
      _failure = null;
      _stage = _Stage.erasing;
    });
    final Result<EraseAllReport> result = await widget.service.eraseAll();
    if (result case Success<EraseAllReport>(:final value)
        when value.databaseCleared) {
      widget.onDataErased();
    }
    if (!mounted) return;
    setState(() {
      switch (result) {
        case Success<EraseAllReport>(:final EraseAllReport value):
          _report = value;
          _stage = value.isComplete ? _Stage.done : _Stage.partial;
        case Failure<EraseAllReport>(:final AppFailure failure):
          _failure = failure;
          _stage = _Stage.failure;
      }
    });
  }

  List<String> _consequences() {
    final EraseAllPreview? p = _preview;
    if (p == null) return const <String>[];
    return <String>[
      CieloStrings.erasePublished(p.published),
      CieloStrings.eraseDrafts(p.drafts),
      CieloStrings.eraseAllPhotos(p.photos),
      CieloStrings.eraseAllAudios(p.audios),
      if (!p.hasProfile)
        CieloStrings.eraseProfileNone
      else if (p.hasProfilePhoto)
        CieloStrings.eraseProfileWithPhoto
      else
        CieloStrings.eraseProfileOnly,
      CieloStrings.eraseSettings,
      if (p.temporaryFiles > 0) CieloStrings.eraseTemporary(p.temporaryFiles),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool erasing = _stage == _Stage.erasing;
    return PopScope<Object?>(
      canPop: !erasing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(CieloStrings.eraseAllAction),
          automaticallyImplyLeading: !erasing && _stage != _Stage.done,
        ),
        body: _body(context),
        bottomNavigationBar: switch (_stage) {
          _Stage.counting => null,
          _Stage.review => CieloActionBar(
            primaryLabel: widget.interrupted
                ? CieloStrings.eraseFinish
                : CieloStrings.eraseAllAction,
            primaryIcon: Icons.delete_forever_rounded,
            destructive: true,
            onPrimary: _confirm,
          ),
          _Stage.erasing => CieloActionBar(
            primaryLabel: CieloStrings.eraseAllAction,
            onPrimary: null,
            busy: true,
            busyLabel: CieloStrings.erasing,
          ),
          _Stage.partial || _Stage.failure => CieloActionBar(
            primaryLabel: CieloStrings.retry,
            primaryIcon: Icons.refresh_rounded,
            onPrimary: _erase,
          ),
          _Stage.done => CieloActionBar(
            primaryLabel: CieloStrings.goToDiary,
            onPrimary: widget.onGoToDiary,
          ),
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle? secondary = text.bodyMedium?.copyWith(
      color: c.textSecondary,
    );
    if (_stage == _Stage.counting) {
      return Semantics(
        label: CieloStrings.eraseCounting,
        child: const Padding(
          padding: EdgeInsets.all(CieloSpace.gutter),
          child: CieloSkeletonList(count: 3),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(CieloSpace.gutter),
      children: switch (_stage) {
        _Stage.erasing => <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(CieloStrings.erasing, style: text.titleLarge),
          ),
          const SizedBox(height: CieloSpace.md),
          const ExcludeSemantics(child: LinearProgressIndicator()),
        ],
        _Stage.done => <Widget>[
          const CieloBanner(
            tone: CieloTone.success,
            title: CieloStrings.eraseAllDone,
            message: CieloStrings.eraseDoneMessage,
          ),
          const SizedBox(height: CieloSpace.md),
          Text(CieloStrings.eraseNotForensic, style: secondary),
        ],
        _Stage.partial => <Widget>[
          CieloBanner(
            tone: CieloTone.danger,
            title: CieloStrings.erasePartialTitle,
            message: <String>[
              if (_report!.pendingFiles > 0)
                CieloStrings.erasePartialFiles(_report!.pendingFiles),
              if (!_report!.databaseCleared) CieloStrings.erasePartialDatabase,
              if (!_report!.preferencesCleared)
                CieloStrings.erasePartialPreferences,
              CieloStrings.erasePartialRetry,
            ].join(' '),
          ),
        ],
        _Stage.failure => <Widget>[
          CieloBanner(
            tone: CieloTone.danger,
            title: CieloStrings.erasePartialTitle,
            message:
                '${FailureMessages.of(_failure!)} '
                '${CieloStrings.erasePartialRetry}',
          ),
        ],
        _ => <Widget>[
          if (widget.interrupted) ...<Widget>[
            const CieloBanner(
              tone: CieloTone.warning,
              message: CieloStrings.erasePendingMessage,
            ),
            const SizedBox(height: CieloSpace.md),
          ],
          if (_failure != null) ...<Widget>[
            CieloBanner(
              tone: CieloTone.warning,
              message: FailureMessages.of(_failure!),
            ),
            const SizedBox(height: CieloSpace.md),
          ],
          const CieloSectionHeader(title: CieloStrings.eraseWillDelete),
          CheckLines(
            lines: _consequences(),
            icon: Icons.remove_circle_outline_rounded,
            color: c.danger,
          ),
          const CieloSectionHeader(title: CieloStrings.eraseWillKeep),
          const CheckLines(
            lines: <String>[
              CieloStrings.eraseKeepOriginals,
              CieloStrings.eraseKeepExports,
              CieloStrings.eraseKeepResources,
            ],
          ),
          const SizedBox(height: CieloSpace.md),
          Text(CieloStrings.eraseNotForensic, style: secondary),
          if (widget.onExportFirst != null) ...<Widget>[
            const SizedBox(height: CieloSpace.lg),
            OutlinedButton.icon(
              onPressed: () => widget.onExportFirst!(context),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text(CieloStrings.eraseAllExportFirst),
            ),
          ],
        ],
      },
    );
  }
}
