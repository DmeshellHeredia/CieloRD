import 'package:flutter/foundation.dart';

import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../domain/settings_repository.dart';

/// Preferencias vigentes de la app. La interfaz lo escucha; cada cambio se
/// aplica al instante y se guarda. Si guardar falla, se revierte.
final class SettingsController extends ChangeNotifier {
  SettingsController({required this.repository, AppSettings? initial})
    : _settings = initial ?? AppSettings();

  final SettingsRepository repository;
  AppSettings _settings;
  AppFailure? _loadFailure;
  Future<void> _queue = Future<void>.value();

  AppSettings get settings => _settings;

  /// No nulo si las preferencias no se pudieron leer. La app no debe abrirse
  /// en ese estado: no se sabe si el bloqueo está activado.
  AppFailure? get loadFailure => _loadFailure;

  Future<void> load() async {
    switch (await repository.get()) {
      case Success<AppSettings>(:final value):
        _settings = value;
        _loadFailure = null;
      case Failure<AppSettings>(:final failure):
        _loadFailure = failure;
    }
    notifyListeners();
  }

  /// Aplica [change] y lo persiste. Los cambios seguidos se guardan en orden.
  /// Devuelve el fallo, si lo hubo.
  Future<AppFailure?> update(AppSettings Function(AppSettings) change) async {
    final previous = _settings;
    final next = change(previous);
    _settings = next;
    notifyListeners();
    final saving = _queue.then((_) => repository.save(next));
    _queue = saving.then((_) {}, onError: (_) {});
    final result = await saving;
    if (result is Failure<AppSettings>) {
      if (identical(_settings, next)) {
        _settings = previous;
        notifyListeners();
      }
      return result.failure;
    }
    return null;
  }

  /// Vuelve a los valores de fábrica en memoria (tras Borrar Todo).
  void resetToDefaults() {
    _settings = AppSettings();
    _loadFailure = null;
    notifyListeners();
  }
}
