import 'package:flutter/material.dart';

import '../../../../app/contracts.dart';
import '../../../../design/design.dart';
import '../diary/diary_screen.dart';
import 'in_memory_observation_repository.dart';
import 'sample_observations.dart';

/// Vista previa del Diario con datos en memoria (sin SQLite ni plugins):
///
/// ```
/// flutter run -t lib/features/observations/presentation/preview/main_diary_preview.dart
/// ```
///
/// El menú de la barra superior cambia el tema y simula estados vacío y de
/// error. No se importa desde `main.dart`.
class DiaryPreviewApp extends StatefulWidget {
  const DiaryPreviewApp({
    super.key,
    this.initialVariant = CieloTheme.defaultVariant,
    this.now,
    this.latency = const Duration(milliseconds: 450),
  });

  final CieloThemeVariant initialVariant;

  /// Fecha de referencia de los datos de ejemplo (fija en capturas).
  final DateTime? now;
  final Duration latency;

  @override
  State<DiaryPreviewApp> createState() => _DiaryPreviewAppState();
}

enum _PreviewAction { night, day, astro, empty, failure, sample }

class _DiaryPreviewAppState extends State<DiaryPreviewApp> {
  late CieloThemeVariant _variant = widget.initialVariant;
  late DateTime _now = widget.now ?? DateTime.now();
  late InMemoryObservationRepository _repository = _sampleRepository();
  int _screenKey = 0;

  InMemoryObservationRepository _sampleRepository() => InMemoryObservationRepository(
        observations: sampleObservations(now: _now),
        latency: widget.latency,
      );

  void _handle(_PreviewAction action) {
    setState(() {
      switch (action) {
        case _PreviewAction.night:
          _variant = CieloThemeVariant.night;
        case _PreviewAction.day:
          _variant = CieloThemeVariant.day;
        case _PreviewAction.astro:
          _variant = CieloThemeVariant.astro;
        case _PreviewAction.empty:
          _repository = InMemoryObservationRepository(latency: widget.latency);
          _screenKey++;
        case _PreviewAction.failure:
          _repository = _sampleRepository()
            ..scheduledFailures.addAll(<AppFailure>[
              AppFailure(FailureCode.persistence),
              AppFailure(FailureCode.persistence),
            ]);
          _screenKey++;
        case _PreviewAction.sample:
          _now = widget.now ?? DateTime.now();
          _repository = _sampleRepository();
          _screenKey++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CieloRD · Diario (vista previa)',
      debugShowCheckedModeBanner: false,
      theme: CieloTheme.build(_variant),
      themeAnimationDuration: Duration.zero,
      home: Builder(
        builder: (BuildContext context) => DiaryScreen(
          key: ValueKey<int>(_screenKey),
          observations: _repository,
          clock: () => _now,
          onCreateObservation: (BuildContext context) async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vista previa del Diario: el registro está en main_app_preview.dart.')),
            );
            return false;
          },
          appBarActions: <Widget>[
            PopupMenuButton<_PreviewAction>(
              tooltip: 'Opciones de vista previa',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: _handle,
              itemBuilder: (BuildContext context) => const <PopupMenuEntry<_PreviewAction>>[
                PopupMenuItem<_PreviewAction>(value: _PreviewAction.night, child: Text('Tema Noche')),
                PopupMenuItem<_PreviewAction>(value: _PreviewAction.day, child: Text('Tema Día')),
                PopupMenuItem<_PreviewAction>(value: _PreviewAction.astro, child: Text('Tema Astrónomo')),
                PopupMenuDivider(),
                PopupMenuItem<_PreviewAction>(value: _PreviewAction.sample, child: Text('Datos de ejemplo')),
                PopupMenuItem<_PreviewAction>(value: _PreviewAction.empty, child: Text('Diario vacío')),
                PopupMenuItem<_PreviewAction>(value: _PreviewAction.failure, child: Text('Simular error al cargar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
