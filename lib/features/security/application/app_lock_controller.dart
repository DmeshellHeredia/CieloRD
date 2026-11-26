import 'package:flutter/widgets.dart';

import '../../../core/domain/app_failure.dart';
import '../../settings/application/settings_controller.dart';
import '../domain/local_auth_service.dart';

/// Estado del bloqueo local opcional.
///
/// * Arranca bloqueado si la preferencia está activada.
/// * Bloquea al pasar a segundo plano y pide autenticación al volver.
/// * El diálogo del sistema también puede mandar la app a segundo plano: lo
///   que ocurra mientras se autentica no vuelve a bloquear.
/// * Tras cancelar o fallar no reintenta solo: espera a que la persona toque
///   "Desbloquear".
final class AppLockController extends ChangeNotifier
    with WidgetsBindingObserver {
  AppLockController({
    required this.settings,
    required this.auth,
    required this.unlockReason,
    this.onPrivacyChanged,
  }) : _locked = settings.settings.authenticationEnabled {
    _enabled = _locked;
    settings.addListener(_onSettings);
    _notifyPrivacy();
  }

  final SettingsController settings;
  final LocalAuthService auth;
  final String unlockReason;

  /// Oculta o muestra el contenido en Recientes según el bloqueo.
  final void Function(bool hidden)? onPrivacyChanged;

  bool _locked;
  bool _enabled = false;
  bool _authenticating = false;
  bool _promptOnResume = false;
  AuthOutcome? _lastOutcome;
  bool _credentialsMissing = false;

  /// El cambio de preferencia viene de este controlador, ya autenticado.
  bool _changing = false;

  bool get isLocked => _locked;
  bool get isAuthenticating => _authenticating;
  AuthOutcome? get lastOutcome => _lastOutcome;

  /// El teléfono ya no tiene credenciales: el bloqueo no puede verificarse.
  bool get credentialsMissing => _credentialsMissing;

  void attach() => WidgetsBinding.instance.addObserver(this);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    settings.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    final enabled = settings.settings.authenticationEnabled;
    if (enabled == _enabled) return;
    _enabled = enabled;
    _notifyPrivacy();
    if (enabled && !_changing) {
      // Preferencias leídas tras un fallo de arranque, o un cambio revertido:
      // nadie se ha autenticado todavía.
      _locked = true;
    } else if (!enabled) {
      _locked = false;
      _promptOnResume = false;
      _lastOutcome = null;
      _credentialsMissing = false;
    }
    notifyListeners();
  }

  void _notifyPrivacy() => onPrivacyChanged?.call(_enabled);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (!_enabled || _authenticating || _locked) return;
        _locked = true;
        _promptOnResume = true;
        _lastOutcome = null;
        notifyListeners();
      case AppLifecycleState.resumed:
        if (_promptOnResume) {
          _promptOnResume = false;
          unlock();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Pide autenticación para abrir la app.
  Future<void> unlock() async {
    if (!_locked || _authenticating) return;
    _promptOnResume = false;
    final outcome = await _authenticate(unlockReason);
    if (outcome == AuthOutcome.success) _locked = false;
    _lastOutcome = outcome;
    // Solo el propio sistema puede confirmar que no hay credenciales.
    _credentialsMissing =
        outcome == AuthOutcome.noCredentials &&
        await auth.availability() == AuthAvailability.noCredentials;
    notifyListeners();
  }

  /// Activa el bloqueo: exige credenciales en el teléfono y verificarse antes.
  Future<({AuthOutcome outcome, AppFailure? failure})> enable(
    String reason,
  ) async {
    if (await auth.availability() == AuthAvailability.noCredentials) {
      return (outcome: AuthOutcome.noCredentials, failure: null);
    }
    return _change(reason, enabled: true);
  }

  /// Desactiva el bloqueo: también exige verificarse.
  Future<({AuthOutcome outcome, AppFailure? failure})> disable(String reason) =>
      _change(reason, enabled: false);

  Future<({AuthOutcome outcome, AppFailure? failure})> _change(
    String reason, {
    required bool enabled,
  }) async {
    final outcome = await _authenticate(reason);
    if (outcome != AuthOutcome.success) {
      return (outcome: outcome, failure: null);
    }
    _changing = true;
    try {
      final failure = await settings.update(
        (s) => s.copyWith(authenticationEnabled: enabled),
      );
      return (outcome: outcome, failure: failure);
    } finally {
      _changing = false;
    }
  }

  /// Salida para quien quitó el PIN del teléfono (Android exige el PIN actual
  /// para quitarlo). Desactiva el bloqueo; no abre nada si hay credenciales.
  Future<AppFailure?> openWithoutCredentials() async {
    if (!_credentialsMissing ||
        await auth.availability() != AuthAvailability.noCredentials) {
      return AppFailure(FailureCode.permissionDenied);
    }
    return settings.update((s) => s.copyWith(authenticationEnabled: false));
  }

  Future<AuthOutcome> _authenticate(String reason) async {
    if (_authenticating) return AuthOutcome.cancelled;
    _authenticating = true;
    notifyListeners();
    var outcome = AuthOutcome.unavailable;
    try {
      return outcome = await auth.authenticate(reason);
    } finally {
      _authenticating = false;
      // Si se salió de la app con el diálogo abierto (por ejemplo, al cambiar
      // el ajuste), al volver hay que desbloquear.
      if (outcome != AuthOutcome.success) _lockIfInBackground();
      notifyListeners();
    }
  }

  void _lockIfInBackground() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      didChangeAppLifecycleState(state!);
    }
  }
}
