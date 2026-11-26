import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/contracts.dart';
import '../../../design/design.dart';
import '../../../l10n/cielo_strings.dart';
import '../../../l10n/failure_messages.dart';
import '../../../ui_kit/ui_kit.dart';
import 'profile_avatar.dart';

/// Edición del perfil. Devuelve el [ObserverProfile] guardado al cerrarse.
///
/// La foto nueva queda *staged* hasta guardar; al salir sin guardar se
/// descarta. La original de la galería nunca se toca.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.repository,
    this.media,
    this.maintenance,
  });

  final ProfileRepository repository;
  final MediaService? media;
  final MediaMaintenance? maintenance;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final TextEditingController _first = TextEditingController();
  final TextEditingController _last = TextEditingController();
  final TextEditingController _studentId = TextEditingController();
  final TextEditingController _motto = TextEditingController();

  ObserverProfile _saved = const ObserverProfile();
  String? _photoId;
  ObservationMedia? _staged;
  bool _loading = true;
  bool _busy = false;
  AppFailure? _loadFailure;
  AppFailure? _failure;

  List<TextEditingController> get _fields => [
    _first,
    _last,
    _studentId,
    _motto,
  ];

  bool get _dirty =>
      _photoId != _saved.photoMediaId ||
      _first.text.trim() != _saved.firstName ||
      _last.text.trim() != _saved.lastName ||
      _studentId.text.trim() != _saved.studentId ||
      _motto.text.trim() != _saved.motto;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in _fields) {
      c.addListener(_onChanged);
    }
    _load();
  }

  @override
  void dispose() {
    final ObservationMedia? staged = _staged;
    if (staged != null) unawaited(widget.media?.discardStaged(staged.id));
    for (final TextEditingController c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailure = null;
    });
    final Result<ObserverProfile?> result = await widget.repository.get();
    if (!mounted) return;
    switch (result) {
      case Success<ObserverProfile?>(:final ObserverProfile? value):
        _saved = value ?? const ObserverProfile();
        _first.text = _saved.firstName;
        _last.text = _saved.lastName;
        _studentId.text = _saved.studentId;
        _motto.text = _saved.motto;
        _photoId = _saved.photoMediaId;
      case Failure<ObserverProfile?>(:final AppFailure failure):
        _loadFailure = failure;
    }
    setState(() => _loading = false);
  }

  Future<void> _pick(PhotoSource source) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    final Result<ObservationMedia?> result = await widget.media!.pickPhoto(
      source,
    );
    if (!mounted) {
      if (result case Success<ObservationMedia?>(:final value?)) {
        await widget.media!.discardStaged(value.id);
      }
      return;
    }
    switch (result) {
      case Success<ObservationMedia?>(value: final ObservationMedia photo?):
        await _discardStaged();
        _staged = photo;
        _photoId = photo.id;
      case Success<ObservationMedia?>():
        break;
      case Failure<ObservationMedia?>(:final AppFailure failure):
        _failure = failure;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _removePhoto() async {
    await _discardStaged();
    if (mounted) setState(() => _photoId = null);
  }

  Future<void> _discardStaged() async {
    final ObservationMedia? staged = _staged;
    _staged = null;
    if (staged != null) await widget.media?.discardStaged(staged.id);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _failure = null;
    });
    final Result<ObserverProfile> result = await widget.repository.save(
      ObserverProfile(
        firstName: _first.text,
        lastName: _last.text,
        studentId: _studentId.text,
        motto: _motto.text,
        photoMediaId: _photoId,
      ),
      newPhoto: _staged,
    );
    if (result case Success<ObserverProfile>(:final value)) {
      final ObservationMedia? staged = _staged;
      _staged = null;
      _saved = value;
      if (staged != null) await widget.media?.commitStaged([staged.id]);
      // Elimina ya la foto anterior; si falla, queda en la cola durable.
      await widget.maintenance?.run();
      if (mounted) Navigator.of(context).pop(value);
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = (result as Failure<ObserverProfile>).failure;
    });
  }

  Future<void> _confirmLeave() async {
    if (_busy) return;
    final bool leave = await showCieloConfirmDialog(
      context,
      title: CieloStrings.discardTitle,
      message: CieloStrings.profileDiscardMessage,
      confirmLabel: CieloStrings.discardChanges,
      cancelLabel: CieloStrings.keepEditing,
      destructive: true,
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  String? _error(String field) => switch (_failure?.fieldErrors[field]) {
    null => null,
    'too_long' => CieloStrings.profileTooLong,
    'invalid_characters' => CieloStrings.profileInvalidCharacters,
    _ => CieloStrings.fieldInvalid,
  };

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text(CieloStrings.profileEdit)),
        body: _body(context),
        bottomNavigationBar: _loading || _loadFailure != null
            ? null
            : CieloActionBar(
                primaryLabel: CieloStrings.save,
                onPrimary: _dirty ? _save : null,
                busy: _busy,
              ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(CieloSpace.gutter),
        child: CieloSkeletonList(count: 3),
      );
    }
    if (_loadFailure != null) {
      return CieloErrorState(
        message: FailureMessages.of(_loadFailure!),
        onRetry: _load,
      );
    }
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool hasPhoto = _photoId != null;
    return ListView(
      padding: const EdgeInsets.all(CieloSpace.gutter),
      children: <Widget>[
        if (_failure != null && _failure!.fieldErrors.isEmpty) ...<Widget>[
          CieloBanner(
            tone: CieloTone.danger,
            message: FailureMessages.of(_failure!),
          ),
          const SizedBox(height: CieloSpace.lg),
        ],
        Center(
          child: ProfileAvatar(
            photoMediaId: _photoId,
            resolve: widget.media?.resolveLocalPath,
            size: 128,
          ),
        ),
        const SizedBox(height: CieloSpace.md),
        if (widget.media != null)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: CieloSpace.sm,
            runSpacing: CieloSpace.sm,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(PhotoSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text(CieloStrings.profilePhotoCamera),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(PhotoSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text(CieloStrings.profilePhotoGallery),
              ),
              if (hasPhoto)
                TextButton.icon(
                  onPressed: _busy ? null : _removePhoto,
                  icon: const Icon(Icons.no_photography_rounded),
                  label: const Text(CieloStrings.profilePhotoRemove),
                ),
            ],
          ),
        const SizedBox(height: CieloSpace.xl),
        _field(
          controller: _first,
          label: CieloStrings.profileFirstName,
          error: _error('firstName'),
          maxLength: ObserverProfile.maxNameLength,
          capitalization: TextCapitalization.words,
          autofill: AutofillHints.givenName,
        ),
        _field(
          controller: _last,
          label: CieloStrings.profileLastName,
          error: _error('lastName'),
          maxLength: ObserverProfile.maxNameLength,
          capitalization: TextCapitalization.words,
          autofill: AutofillHints.familyName,
        ),
        _field(
          controller: _studentId,
          label: CieloStrings.profileStudentId,
          helper: CieloStrings.profileStudentIdHelp,
          error: _error('studentId'),
          maxLength: ObserverProfile.maxStudentIdLength,
          capitalization: TextCapitalization.characters,
        ),
        _field(
          controller: _motto,
          label: CieloStrings.profileMotto,
          error: _error('motto'),
          maxLength: ObserverProfile.maxMottoLength,
          capitalization: TextCapitalization.sentences,
          action: TextInputAction.done,
        ),
        Text(
          CieloStrings.profilePrivacy,
          style: text.bodyMedium?.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required int maxLength,
    String? helper,
    String? error,
    String? autofill,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: CieloSpace.lg),
    child: TextField(
      controller: controller,
      enabled: !_busy,
      maxLength: maxLength,
      textCapitalization: capitalization,
      textInputAction: action,
      autofillHints: autofill == null ? null : <String>[autofill],
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        errorText: error,
        errorMaxLines: 3,
        counterText: '',
      ),
    ),
  );
}
