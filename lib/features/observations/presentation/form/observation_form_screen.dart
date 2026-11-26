import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../app/contracts.dart';
import '../../../../design/design.dart';
import '../../../../l10n/cielo_format.dart';
import '../../../../l10n/cielo_strings.dart';
import '../../../../l10n/failure_messages.dart';
import '../../../../l10n/field_error_messages.dart';
import '../../../../ui_kit/ui_kit.dart';
import '../../../map/domain/offline_province_map.dart';
import '../../../map/presentation/province_map_view.dart';

/// Registro completo y edición de observaciones (U2).
///
/// * Estado del formulario en el `ObservationFormController` de C0; la
///   pantalla solo traduce cada control a `replaceInput`.
/// * Publicar exige título, fecha/hora y categoría (validador C0). El resto es
///   opcional. Los borradores aceptan datos incompletos.
/// * La hora se edita como hora local del lugar: se guarda en UTC con el
///   desplazamiento original (o el del dispositivo si es nueva).
/// * Al salir con cambios pregunta: borrador → hoja "¿Guardar como
///   borrador?"; publicada → confirmación para descartar.
///
/// Devuelve con `Navigator.pop` la [Observation] guardada, o nada si se
/// sale sin guardar.
class ObservationFormScreen extends StatefulWidget {
  const ObservationFormScreen({
    super.key,
    required this.service,
    required this.drafts,
    this.validator = const ObservationValidator(),
    this.initial,
    this.prefill,
    this.clock,
    this.locationService,
    this.mediaService,
    this.recorder,
    this.provinceMap,
    this.maintenance,
  });

  final ObservationService service;
  final DraftService drafts;
  final ObservationValidator validator;

  /// Observación a editar; `null` para crear una nueva.
  final Observation? initial;

  /// Datos iniciales de una observación nueva (p. ej., desde el registro rápido).
  final ObservationInput? prefill;
  final DateTime Function()? clock;
  final LocationService? locationService;
  final MediaService? mediaService;
  final VoiceRecorder? recorder;
  final OfflineProvinceMap? provinceMap;
  final MediaMaintenance? maintenance;

  @override
  State<ObservationFormScreen> createState() => _ObservationFormScreenState();
}

class _ObservationFormScreenState extends State<ObservationFormScreen> {
  late final DateTime _now = (widget.clock ?? DateTime.now)();
  late final ObservationFormController _form = ObservationFormController(
    validator: widget.validator,
    initialInput: widget.initial?.input ?? _defaultInput(),
  );

  late final TextEditingController _title = TextEditingController(
    text: _form.input.title,
  );
  late final TextEditingController _description = TextEditingController(
    text: _form.input.description ?? '',
  );
  late final TextEditingController _place = TextEditingController(
    text: _form.input.location?.placeName ?? '',
  );
  late final TextEditingController _lat = TextEditingController(
    text: _fmt(_form.input.location?.latitude),
  );
  late final TextEditingController _lon = TextEditingController(
    text: _fmt(_form.input.location?.longitude),
  );
  late bool _coordinatesOpen = _form.input.location?.hasCoordinates ?? false;

  final Map<String, String> _localErrors = <String, String>{};
  bool _showErrors = false;
  bool _saving = false;
  bool _finished = false;
  AppFailure? _saveFailure;
  bool _locationBusy = false;
  bool _mediaBusy = false;
  RecordingState _recording = const RecordingState(phase: RecorderPhase.idle);
  StreamSubscription<RecordingState>? _recordingSubscription;
  final Set<String> _newMediaIds = <String>{};

  bool get _isNew => widget.initial == null;
  bool get _isDraft =>
      _isNew || widget.initial!.status == ObservationStatus.draft;
  ObservationInput get _input => _form.input;

  ObservationInput _defaultInput() {
    final ObservationInput base = widget.prefill ?? ObservationInput();
    if (base.observedAt != null) return base;
    final int offset = _now.timeZoneOffset.inMinutes.clamp(-840, 840);
    return base.copyWith(
      observedAt: () => _now.toUtc(),
      utcOffsetMinutes: () => offset,
    );
  }

  static String _fmt(double? v) => v == null ? '' : v.toString();

  @override
  void initState() {
    super.initState();
    _form.addListener(_rebuild);
    _recordingSubscription = widget.recorder?.states.listen((state) {
      if (!mounted) return;
      setState(() => _recording = state);
      if (state.phase == RecorderPhase.completed && state.media != null) {
        _addMedia(state.media!);
      } else if (state.phase == RecorderPhase.failed && state.failure != null) {
        _showFailure(state.failure!);
      }
    });
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    unawaited(_recordingSubscription?.cancel());
    if (_recording.phase == RecorderPhase.recording) {
      unawaited(widget.recorder?.cancel());
    }
    if (!_finished && widget.mediaService != null) {
      for (final id in _newMediaIds) {
        unawaited(widget.mediaService!.discardStaged(id));
      }
    }
    _form
      ..removeListener(_rebuild)
      ..dispose();
    for (final TextEditingController c in <TextEditingController>[
      _title,
      _description,
      _place,
      _lat,
      _lon,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(ObservationInput next) {
    _saveFailure = null;
    _form.replaceInput(next);
  }

  // ── Ubicación ───────────────────────────────────────────────────────────

  double? _parseCoordinate(String text, String key) {
    final String t = text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final double? v = double.tryParse(t);
    if (v == null || !v.isFinite) {
      _localErrors[key] = CieloStrings.fieldInvalidNumber;
      return null;
    }
    return v;
  }

  void _updateLocation() {
    _localErrors.removeWhere((String k, _) => k.startsWith('location.'));
    final String place = _place.text.trim();
    double? lat;
    double? lon;
    if (_coordinatesOpen) {
      lat = _parseCoordinate(_lat.text, 'location.latitude');
      lon = _parseCoordinate(_lon.text, 'location.longitude');
    }
    ObservationLocation? location;
    if (lat == null &&
        lon == null &&
        !(_coordinatesOpen &&
            (_lat.text.trim().isNotEmpty || _lon.text.trim().isNotEmpty))) {
      location = place.isEmpty
          ? null
          : ObservationLocation(placeName: place, source: LocationSource.text);
    } else {
      // Si las coordenadas no cambiaron, se conserva su origen (p. ej. GPS).
      final ObservationLocation? original = _input.location;
      final bool unchanged =
          original != null &&
          original.latitude == lat &&
          original.longitude == lon;
      location = ObservationLocation(
        placeName: place.isEmpty ? null : place,
        latitude: lat,
        longitude: lon,
        source: unchanged ? original.source : LocationSource.manual,
        accuracyM: unchanged ? original.accuracyM : null,
        capturedAt: unchanged ? original.capturedAt : null,
      );
    }
    _set(_input.copyWith(location: () => location));
  }

  Future<void> _useGps() async {
    final service = widget.locationService;
    if (service == null || _locationBusy) return;
    setState(() => _locationBusy = true);
    final result = await service.current();
    if (!mounted) return;
    setState(() => _locationBusy = false);
    switch (result) {
      case Success<LocationFix>(:final value):
        final location = value.location;
        _lat.text = location.latitude!.toStringAsFixed(6);
        _lon.text = location.longitude!.toStringAsFixed(6);
        _coordinatesOpen = true;
        _set(
          _input.copyWith(
            location: () => ObservationLocation(
              placeName: _place.text.trim().isEmpty ? null : _place.text.trim(),
              latitude: location.latitude,
              longitude: location.longitude,
              source: LocationSource.gps,
              accuracyM: location.accuracyM,
              capturedAt: location.capturedAt,
            ),
          ),
        );
      case Failure<LocationFix>(:final failure):
        _showFailure(failure);
    }
  }

  Future<void> _selectOnMap() async {
    final map = widget.provinceMap;
    if (map == null) return;
    final selection = await showDialog<OfflineMapSelection>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar ubicación'),
        content: SizedBox(
          width: 700,
          child: ProvinceMapView(
            map: map,
            selected: _input.location?.hasCoordinates ?? false
                ? GeoCoordinate(
                    _input.location!.latitude!,
                    _input.location!.longitude!,
                  )
                : null,
            onSelected: (value) => Navigator.of(context).pop(value),
            onOutsideCoverage: (_) => ScaffoldMessenger.maybeOf(context)
                ?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Ese punto está fuera de la cobertura provincial.',
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
    if (selection == null || !mounted) return;
    _place.text = selection.province.name;
    _lat.text = selection.coordinate.latitude.toStringAsFixed(6);
    _lon.text = selection.coordinate.longitude.toStringAsFixed(6);
    setState(() => _coordinatesOpen = true);
    _set(
      _input.copyWith(
        location: () => ObservationLocation(
          placeName: selection.province.name,
          latitude: selection.coordinate.latitude,
          longitude: selection.coordinate.longitude,
          source: LocationSource.manual,
        ),
      ),
    );
  }

  Future<void> _pickPhoto(PhotoSource source) async {
    final media = widget.mediaService;
    if (media == null || _mediaBusy) return;
    if (_input.media.where((item) => item.kind == MediaKind.photo).length >=
        5) {
      _showFailure(
        AppFailure(
          FailureCode.validation,
          fieldErrors: const {'media.photos': 'max_5'},
        ),
      );
      return;
    }
    setState(() => _mediaBusy = true);
    final result = await media.pickPhoto(source);
    if (!mounted) return;
    setState(() => _mediaBusy = false);
    switch (result) {
      case Success<ObservationMedia?>(:final value):
        if (value != null) _addMedia(value);
      case Failure<ObservationMedia?>(:final failure):
        _showFailure(failure);
    }
  }

  void _addMedia(ObservationMedia media) {
    if (_input.media.any((item) => item.id == media.id)) return;
    _newMediaIds.add(media.id);
    _set(_input.copyWith(media: [..._input.media, media]));
  }

  Future<void> _removeMedia(ObservationMedia media) async {
    _set(
      _input.copyWith(
        media: _input.media
            .where((item) => item.id != media.id)
            .toList(growable: false),
      ),
    );
    if (_newMediaIds.remove(media.id)) {
      await widget.mediaService?.discardStaged(media.id);
    }
  }

  Future<void> _toggleRecording() async {
    final recorder = widget.recorder;
    if (recorder == null) return;
    final audios = _input.media
        .where((item) => item.kind == MediaKind.audio)
        .length;
    if (_recording.phase != RecorderPhase.recording && audios >= 3) {
      _showFailure(
        AppFailure(
          FailureCode.validation,
          fieldErrors: const {'media.audios': 'max_3'},
        ),
      );
      return;
    }
    final result = _recording.phase == RecorderPhase.recording
        ? await recorder.stop()
        : await recorder.start();
    switch (result) {
      case Failure<Object>(:final failure) when mounted:
        _showFailure(failure);
      case Success<Object>():
      case Failure<Object>():
        break;
    }
  }

  void _showFailure(AppFailure failure) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(FailureMessages.of(failure))));
  }

  // ── Fecha y hora ────────────────────────────────────────────────────────

  int get _offset =>
      _input.utcOffsetMinutes ?? _now.timeZoneOffset.inMinutes.clamp(-840, 840);

  /// Hora de pared del lugar (campos locales en un DateTime UTC).
  DateTime get _wall =>
      (_input.observedAt ?? _now.toUtc()).add(Duration(minutes: _offset));

  void _setWall(DateTime wall) {
    final DateTime utc = DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
    ).subtract(Duration(minutes: _offset));
    _set(
      _input.copyWith(observedAt: () => utc, utcOffsetMinutes: () => _offset),
    );
  }

  Future<void> _pickDate() async {
    final DateTime wall = _wall;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(wall.year, wall.month, wall.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(_now.year + 1, 12, 31),
      helpText: CieloStrings.changeDate,
    );
    if (picked != null) {
      _setWall(
        DateTime.utc(
          picked.year,
          picked.month,
          picked.day,
          wall.hour,
          wall.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final DateTime wall = _wall;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: wall.hour, minute: wall.minute),
      helpText: CieloStrings.changeTime,
    );
    if (picked != null) {
      _setWall(
        DateTime.utc(
          wall.year,
          wall.month,
          wall.day,
          picked.hour,
          picked.minute,
        ),
      );
    }
  }

  // ── Guardar ─────────────────────────────────────────────────────────────

  String? _error(String key) {
    if (!_showErrors) return null;
    final String? local = _localErrors[key];
    if (local != null) return local;
    final Map<String, String> errors =
        (_form.failure ?? _saveFailure)?.fieldErrors ??
        const <String, String>{};
    final String? code = errors[key];
    return code == null ? null : FieldErrorMessages.forField(key, code);
  }

  String? _locationError() =>
      _error('location.latitude') ??
      _error('location.longitude') ??
      _error('location.coordinates') ??
      _error('location.placeName') ??
      _error('location.source') ??
      _error('location.capturedAt');

  Future<void> _submit(ObservationStatus status) async {
    if (_saving) return;
    if (_coordinatesOpen) _updateLocation();
    final Result<ObservationInput> valid = _form.validateFor(status);
    if (_localErrors.isNotEmpty || valid is Failure<ObservationInput>) {
      setState(() => _showErrors = true);
      _announce(CieloStrings.fixErrors);
      return;
    }
    setState(() {
      _saving = true;
      _saveFailure = null;
    });
    final Observation? initial = widget.initial;
    final Result<Observation> result;
    if (initial == null) {
      result = status == ObservationStatus.draft
          ? await widget.drafts.save(_input)
          : await widget.service.create(
              _input,
              status: ObservationStatus.published,
            );
    } else if (status == ObservationStatus.draft) {
      result = await widget.drafts.save(
        _input,
        id: initial.id,
        expectedRevision: initial.revision,
      );
    } else {
      result = await widget.service.update(
        initial.id,
        _input,
        status: ObservationStatus.published,
        expectedRevision: initial.revision,
      );
    }
    if (!mounted) return;
    switch (result) {
      case Success<Observation>(:final Observation value):
        if (_newMediaIds.isNotEmpty && widget.mediaService != null) {
          await widget.mediaService!.commitStaged(_newMediaIds);
          _newMediaIds.clear();
        }
        await widget.maintenance?.run();
        if (!mounted) return;
        _finished = true;
        final String message = status == ObservationStatus.draft
            ? CieloStrings.draftSaved
            : (_isNew || initial!.status == ObservationStatus.draft
                  ? CieloStrings.published
                  : CieloStrings.changesSaved);
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(message)));
        Navigator.of(context).pop(value);
      case Failure<Observation>(:final AppFailure failure):
        setState(() {
          _saving = false;
          _saveFailure = failure;
          _showErrors = failure.fieldErrors.isNotEmpty;
        });
        _announce(FailureMessages.of(failure));
    }
  }

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  Future<void> _onPopBlocked() async {
    if (_isDraft) {
      final UnsavedChangesDecision d = await showUnsavedChangesSheet(context);
      if (!mounted) return;
      switch (d) {
        case UnsavedChangesDecision.saveDraft:
          await _submit(ObservationStatus.draft);
        case UnsavedChangesDecision.discard:
          _finished = true;
          Navigator.of(context).pop();
        case UnsavedChangesDecision.keepEditing:
          break;
      }
    } else {
      final bool discard = await showCieloConfirmDialog(
        context,
        title: CieloStrings.discardTitle,
        message: CieloStrings.discardMessage,
        confirmLabel: CieloStrings.discardChanges,
        cancelLabel: CieloStrings.keepEditing,
        destructive: true,
      );
      if (discard && mounted) {
        _finished = true;
        Navigator.of(context).pop();
      }
    }
  }

  // ── Construcción ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String screenTitle = _isNew
        ? CieloStrings.newObservation
        : (_isDraft
              ? CieloStrings.completeDraft
              : CieloStrings.editObservation);
    final DateTime wall = _wall;
    final AppFailure? saveFailure = _saveFailure;

    return PopScope<Object?>(
      canPop: !_form.isDirty || _finished,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _onPopBlocked();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(screenTitle)),
        bottomNavigationBar: CieloActionBar(
          primaryLabel: _isDraft
              ? CieloStrings.publish
              : CieloStrings.saveChanges,
          primaryIcon: Icons.check_rounded,
          onPrimary: () => _submit(ObservationStatus.published),
          secondaryLabel: _isDraft ? CieloStrings.saveDraft : null,
          onSecondary: _isDraft ? () => _submit(ObservationStatus.draft) : null,
          busy: _saving,
          busyLabel: CieloStrings.saving,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            CieloSpace.gutter,
            0,
            CieloSpace.gutter,
            CieloSpace.xxl,
          ),
          children: <Widget>[
            if (saveFailure != null && saveFailure.fieldErrors.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: CieloSpace.md),
                child: CieloBanner(
                  tone: CieloTone.danger,
                  message: FailureMessages.of(saveFailure),
                ),
              ),
            if (_showErrors &&
                (_form.failure != null || _localErrors.isNotEmpty))
              const Padding(
                padding: EdgeInsets.only(top: CieloSpace.md),
                child: CieloBanner(
                  tone: CieloTone.danger,
                  message: CieloStrings.fixErrors,
                ),
              ),

            const CieloSectionHeader(
              title: CieloStrings.titleLabel,
              subtitle: CieloStrings.requiredToPublish,
            ),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: InputDecoration(
                hintText: CieloStrings.titleHint,
                errorText: _error('title'),
              ),
              onChanged: (String v) => _set(_input.copyWith(title: v)),
            ),

            const CieloSectionHeader(
              title: CieloStrings.categoryLabel,
              subtitle: CieloStrings.requiredToPublish,
            ),
            CategoryGrid(
              selectedCode: _input.category?.name,
              onSelected: (CategoryVisual v) => _set(
                _input.copyWith(
                  category: () => ObservationCategory.values.byName(v.code),
                ),
              ),
            ),
            _FieldError(_error('category')),

            const CieloSectionHeader(
              title: CieloStrings.observedAtLabel,
              subtitle: CieloStrings.dateTimeHelp,
            ),
            Wrap(
              spacing: CieloSpace.sm,
              runSpacing: CieloSpace.sm,
              children: <Widget>[
                Semantics(
                  label: CieloStrings.changeDate,
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_rounded),
                    label: Text(CieloFormat.dateLong(wall)),
                  ),
                ),
                Semantics(
                  label: CieloStrings.changeTime,
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(CieloFormat.time(wall)),
                  ),
                ),
              ],
            ),
            _FieldError(_error('observedAt') ?? _error('utcOffsetMinutes')),

            const CieloSectionHeader(
              title: CieloStrings.skyConditionLabel,
              subtitle: CieloStrings.optional,
            ),
            SkyConditionSelector(
              selectedCode: _input.skyCondition?.code,
              onChanged: (String? code) => _set(
                _input.copyWith(
                  skyCondition: () => code == null
                      ? null
                      : SkyCondition.values.firstWhere(
                          (SkyCondition s) => s.code == code,
                        ),
                ),
              ),
            ),

            const CieloSectionHeader(
              title: CieloStrings.locationLabel,
              subtitle: CieloStrings.optional,
            ),
            if (widget.locationService != null || widget.provinceMap != null)
              Wrap(
                spacing: CieloSpace.sm,
                children: [
                  if (widget.locationService != null)
                    FilledButton.tonalIcon(
                      onPressed: _locationBusy ? null : _useGps,
                      icon: _locationBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                      label: const Text('Usar GPS'),
                    ),
                  if (widget.provinceMap != null)
                    OutlinedButton.icon(
                      onPressed: _selectOnMap,
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Marcar en mapa'),
                    ),
                ],
              ),
            if (_input.location?.source == LocationSource.gps)
              Padding(
                padding: const EdgeInsets.only(top: CieloSpace.sm),
                child: Text(
                  'GPS${_input.location?.accuracyM == null ? '' : ' · ±${_input.location!.accuracyM!.round()} m'}',
                  style: text.bodyMedium?.copyWith(color: c.textSecondary),
                ),
              ),
            TextField(
              controller: _place,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: CieloStrings.placeHint,
                prefixIcon: Icon(Icons.place_rounded),
              ),
              onChanged: (_) => _updateLocation(),
            ),
            const SizedBox(height: CieloSpace.sm),
            if (!_coordinatesOpen)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _coordinatesOpen = true),
                  icon: const Icon(Icons.edit_location_alt_rounded),
                  label: const Text(CieloStrings.addCoordinates),
                ),
              )
            else ...<Widget>[
              Text(
                CieloStrings.coordinatesHelp,
                style: text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: CieloSpace.sm),
              _CoordinateField(
                controller: _lat,
                label: CieloStrings.latitudeLabel,
                hint: CieloStrings.latitudeHint,
                onChanged: _updateLocation,
              ),
              const SizedBox(height: CieloSpace.sm),
              _CoordinateField(
                controller: _lon,
                label: CieloStrings.longitudeLabel,
                hint: CieloStrings.longitudeHint,
                onChanged: _updateLocation,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    _lat.clear();
                    _lon.clear();
                    setState(() => _coordinatesOpen = false);
                    _updateLocation();
                  },
                  icon: const Icon(Icons.close_rounded),
                  label: const Text(CieloStrings.removeCoordinates),
                ),
              ),
            ],
            _FieldError(_locationError()),

            if (widget.mediaService != null || widget.recorder != null) ...[
              const CieloSectionHeader(
                title: CieloStrings.mediaLabel,
                subtitle: CieloStrings.optional,
              ),
              Wrap(
                spacing: CieloSpace.sm,
                runSpacing: CieloSpace.sm,
                children: [
                  if (widget.mediaService != null)
                    OutlinedButton.icon(
                      onPressed: _mediaBusy
                          ? null
                          : () => _pickPhoto(PhotoSource.camera),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Cámara'),
                    ),
                  if (widget.mediaService != null)
                    OutlinedButton.icon(
                      onPressed: _mediaBusy
                          ? null
                          : () => _pickPhoto(PhotoSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Galería'),
                    ),
                  if (widget.recorder != null)
                    FilledButton.tonalIcon(
                      onPressed: _toggleRecording,
                      icon: Icon(
                        _recording.phase == RecorderPhase.recording
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                      ),
                      label: Text(
                        _recording.phase == RecorderPhase.recording
                            ? 'Detener ${_recording.elapsed.inSeconds}s'
                            : 'Grabar voz',
                      ),
                    ),
                ],
              ),
              if (_input.media.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: CieloSpace.md),
                  child: Wrap(
                    spacing: CieloSpace.sm,
                    runSpacing: CieloSpace.sm,
                    children: [
                      for (final item in _input.media)
                        _MediaPreview(
                          media: item,
                          service: widget.mediaService,
                          onRemove: () => _removeMedia(item),
                        ),
                    ],
                  ),
                ),
            ],

            const CieloSectionHeader(
              title: CieloStrings.descriptionLabel,
              subtitle: CieloStrings.optional,
            ),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: CieloStrings.descriptionHint,
              ),
              onChanged: (String v) => _set(
                _input.copyWith(description: () => v.trim().isEmpty ? null : v),
              ),
            ),

            const CieloSectionHeader(
              title: CieloStrings.durationLabel,
              subtitle: CieloStrings.optional,
            ),
            DurationPicker(
              value: _input.durationSeconds == null
                  ? null
                  : Duration(seconds: _input.durationSeconds!),
              onChanged: (Duration? d) =>
                  _set(_input.copyWith(durationSeconds: () => d?.inSeconds)),
            ),
            _FieldError(_error('durationSeconds')),

            const CieloSectionHeader(
              title: CieloStrings.directionLabel,
              subtitle: CieloStrings.optional,
            ),
            DirectionSelector(
              selectedCode: _input.direction?.code,
              onChanged: (String? code) => _set(
                _input.copyWith(
                  direction: () => code == null
                      ? null
                      : CardinalDirection.values.firstWhere(
                          (CardinalDirection d) => d.code == code,
                        ),
                ),
              ),
            ),

            const CieloSectionHeader(
              title: CieloStrings.elevationLabel,
              subtitle: CieloStrings.optional,
            ),
            _ElevationField(
              value: _input.elevationDegrees,
              onChanged: (double? v) =>
                  _set(_input.copyWith(elevationDegrees: () => v)),
            ),
            _FieldError(_error('elevationDegrees')),
          ],
        ),
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final CieloColors c = CieloColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: CieloSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: CieloSize.iconSm,
              color: c.danger,
            ),
            const SizedBox(width: CieloSpace.xs + 2),
            Expanded(
              child: Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: c.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoordinateField extends StatelessWidget {
  const _CoordinateField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      style: CieloTypography.tabular(
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
      ),
      decoration: InputDecoration(labelText: label, hintText: hint),
      onChanged: (_) => onChanged(),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({
    required this.media,
    required this.service,
    required this.onRemove,
  });
  final ObservationMedia media;
  final MediaService? service;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (media.kind == MediaKind.photo && service != null) {
      content = FutureBuilder<Result<String>>(
        future: service!.resolveThumbnailPath(media.id),
        builder: (context, snapshot) {
          final result = snapshot.data;
          if (result is Success<String>) {
            return Image.file(
              File(result.value),
              width: 96,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded),
            );
          }
          return const SizedBox(
            width: 96,
            height: 72,
            child: Icon(Icons.image_rounded),
          );
        },
      );
    } else {
      content = SizedBox(
        width: 96,
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.graphic_eq_rounded),
            Text('${((media.durationMs ?? 0) / 1000).ceil()} s'),
          ],
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: CieloRadius.tileAll,
          child: ColoredBox(
            color: CieloColors.of(context).surface2,
            child: content,
          ),
        ),
        Positioned(
          right: -8,
          top: -8,
          child: IconButton.filledTonal(
            tooltip: 'Quitar adjunto',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ),
      ],
    );
  }
}

/// Altura estimada opcional: interruptor + deslizador de 0° a 90° en pasos de 5°.
class _ElevationField extends StatelessWidget {
  const _ElevationField({required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final double? v = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(CieloStrings.elevationToggle),
          value: v != null,
          onChanged: (bool on) => onChanged(on ? 45 : null),
        ),
        if (v != null) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Slider(
                  value: v.clamp(0, 90),
                  max: 90,
                  divisions: 18,
                  label: CieloStrings.elevationValue(v.round()),
                  semanticFormatterCallback: (double x) =>
                      CieloStrings.elevation(x),
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  CieloStrings.elevationValue(v.round()),
                  textAlign: TextAlign.end,
                  style: CieloTypography.tabular(
                    text.titleMedium ?? const TextStyle(),
                  ),
                ),
              ),
            ],
          ),
          Text(
            CieloStrings.elevationHelp,
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
        ],
      ],
    );
  }
}
