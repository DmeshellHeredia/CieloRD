import 'package:flutter/material.dart';

import '../../../../app/contracts.dart';
import '../../../../design/design.dart';
import '../../../../l10n/cielo_format.dart';
import '../../../../l10n/cielo_strings.dart';
import '../../../../l10n/failure_messages.dart';
import '../../../../ui_kit/ui_kit.dart';

/// Resultado del registro rápido.
sealed class QuickRecordResult {
  const QuickRecordResult();
}

/// Se guardó un borrador.
final class QuickRecordSaved extends QuickRecordResult {
  const QuickRecordSaved(this.draft);
  final Observation draft;
}

/// La persona prefirió el formulario completo con lo que ya había elegido.
final class QuickRecordOpenFullForm extends QuickRecordResult {
  const QuickRecordOpenFullForm(this.prefill);
  final ObservationInput prefill;
}

/// Abre el registro rápido. `null` si se cierra sin hacer nada.
Future<QuickRecordResult?> showQuickRecordSheet(
  BuildContext context, {
  required DraftService drafts,
  DateTime Function()? clock,
  LocationService? locationService,
}) {
  return showModalBottomSheet<QuickRecordResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => QuickRecordSheet(
      drafts: drafts,
      clock: clock,
      locationService: locationService,
    ),
  );
}

/// Registro en campo con una mano: categoría → cielo → Guardar.
///
/// Guarda siempre como **borrador** con la hora actual: los datos que faltan
/// se completan después (Plan Maestro §3). La hora se fija al abrir la hoja,
/// que es cuando ocurrió lo observado.
class QuickRecordSheet extends StatefulWidget {
  const QuickRecordSheet({
    super.key,
    required this.drafts,
    this.clock,
    this.locationService,
  });

  final DraftService drafts;
  final DateTime Function()? clock;
  final LocationService? locationService;

  @override
  State<QuickRecordSheet> createState() => _QuickRecordSheetState();
}

class _QuickRecordSheetState extends State<QuickRecordSheet> {
  late final DateTime _openedAt = (widget.clock ?? DateTime.now)();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _place = TextEditingController();
  ObservationCategory? _category;
  SkyCondition? _sky;
  bool _saving = false;
  AppFailure? _failure;
  ObservationLocation? _location;
  bool _locationBusy = false;

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  ObservationInput _compose() {
    final String place = _place.text.trim();
    final current = _location;
    final location = current == null
        ? (place.isEmpty
              ? null
              : ObservationLocation(
                  placeName: place,
                  source: LocationSource.text,
                ))
        : ObservationLocation(
            placeName: place.isEmpty ? null : place,
            latitude: current.latitude,
            longitude: current.longitude,
            source: current.source,
            accuracyM: current.accuracyM,
            capturedAt: current.capturedAt,
          );
    return ObservationInput(
      title: _title.text.trim(),
      observedAt: _openedAt.toUtc(),
      utcOffsetMinutes: _openedAt.timeZoneOffset.inMinutes.clamp(-840, 840),
      category: _category,
      skyCondition: _sky,
      location: location,
    );
  }

  Future<void> _useGps() async {
    final service = widget.locationService;
    if (service == null || _locationBusy) return;
    setState(() {
      _locationBusy = true;
      _failure = null;
    });
    final result = await service.current();
    if (!mounted) return;
    switch (result) {
      case Success<LocationFix>(:final value):
        setState(() {
          _locationBusy = false;
          _location = value.location;
        });
      case Failure<LocationFix>(:final failure):
        setState(() {
          _locationBusy = false;
          _failure = failure;
        });
    }
  }

  Future<void> _save() async {
    if (_category == null || _saving) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    final Result<Observation> result = await widget.drafts.save(_compose());
    if (!mounted) return;
    switch (result) {
      case Success<Observation>(:final Observation value):
        Navigator.of(context).pop(QuickRecordSaved(value));
      case Failure<Observation>(:final AppFailure failure):
        setState(() {
          _saving = false;
          _failure = failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final AppFailure? failure = _failure;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  CieloSpace.xl,
                  0,
                  CieloSpace.xl,
                  CieloSpace.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        CieloStrings.quickRecord,
                        style: text.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: CieloSpace.xs),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.schedule_rounded,
                          size: CieloSize.iconSm,
                          color: c.textSecondary,
                        ),
                        const SizedBox(width: CieloSpace.xs + 2),
                        Expanded(
                          child: Text(
                            CieloStrings.quickRecordNow(
                              CieloFormat.time(_openedAt),
                            ),
                            style: text.bodyMedium?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (failure != null) ...<Widget>[
                      const SizedBox(height: CieloSpace.md),
                      CieloBanner(
                        tone: CieloTone.danger,
                        message: FailureMessages.of(failure),
                      ),
                    ],
                    const CieloSectionHeader(title: CieloStrings.categoryLabel),
                    CategoryGrid(
                      selectedCode: _category?.name,
                      onSelected: (CategoryVisual v) => setState(
                        () => _category = ObservationCategory.values.byName(
                          v.code,
                        ),
                      ),
                    ),
                    const CieloSectionHeader(
                      title: CieloStrings.skyConditionLabel,
                    ),
                    SkyConditionSelector(
                      selectedCode: _sky?.code,
                      onChanged: (String? code) => setState(
                        () => _sky = code == null
                            ? null
                            : SkyCondition.values.firstWhere(
                                (SkyCondition s) => s.code == code,
                              ),
                      ),
                    ),
                    const SizedBox(height: CieloSpace.xl),
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: CieloStrings.quickTitleHint,
                      ),
                    ),
                    if (widget.locationService != null) ...[
                      const SizedBox(height: CieloSpace.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _locationBusy ? null : _useGps,
                          icon: _locationBusy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded),
                          label: Text(
                            _location == null
                                ? 'Usar GPS'
                                : 'GPS · ±${_location!.accuracyM?.round() ?? 0} m',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: CieloSpace.sm),
                    TextField(
                      controller: _place,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: CieloStrings.quickPlaceHint,
                        prefixIcon: Icon(Icons.place_rounded),
                      ),
                    ),
                    if (_category == null) ...<Widget>[
                      const SizedBox(height: CieloSpace.md),
                      Text(
                        CieloStrings.chooseCategoryFirst,
                        style: text.bodyMedium?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            CieloActionBar(
              primaryLabel: CieloStrings.saveDraft,
              primaryIcon: Icons.check_rounded,
              onPrimary: _category == null ? null : _save,
              secondaryLabel: CieloStrings.fullForm,
              onSecondary: () =>
                  Navigator.of(context)
                      .pop(QuickRecordOpenFullForm(_compose())),
              busy: _saving,
              prominent: true,
            ),
          ],
        ),
      ),
    );
  }
}
