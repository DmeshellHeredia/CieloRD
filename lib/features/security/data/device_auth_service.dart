import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import '../../../l10n/cielo_strings.dart';
import '../domain/local_auth_service.dart';

/// Frontera con el plugin; las pruebas la sustituyen.
abstract interface class DeviceAuthGateway {
  Future<bool> isDeviceSupported();
  Future<bool> authenticate(String reason);
  Future<void> stop();
}

final class LocalAuthGateway implements DeviceAuthGateway {
  LocalAuthGateway([LocalAuthentication? plugin])
    : _plugin = plugin ?? LocalAuthentication();
  final LocalAuthentication _plugin;

  /// En Android es `KeyguardManager.isDeviceSecure` o biometría disponible.
  @override
  Future<bool> isDeviceSupported() => _plugin.isDeviceSupported();

  @override
  Future<bool> authenticate(String reason) => _plugin.authenticate(
    localizedReason: reason,
    authMessages: const [
      AndroidAuthMessages(
        signInTitle: CieloStrings.lockPromptTitle,
        signInHint: CieloStrings.lockPromptHint,
        cancelButton: CieloStrings.cancel,
      ),
    ],
    // Admite PIN, patrón o contraseña del teléfono además de biometría.
    biometricOnly: false,
  );

  @override
  Future<void> stop() => _plugin.stopAuthentication();
}

final class DeviceAuthService implements LocalAuthService {
  DeviceAuthService([DeviceAuthGateway? gateway])
    : _gateway = gateway ?? LocalAuthGateway();
  final DeviceAuthGateway _gateway;

  @override
  Future<AuthAvailability> availability() async {
    try {
      return await _gateway.isDeviceSupported()
          ? AuthAvailability.available
          : AuthAvailability.noCredentials;
    } on Object {
      return AuthAvailability.unknown;
    }
  }

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    try {
      return await _gateway.authenticate(reason)
          ? AuthOutcome.success
          : AuthOutcome.failed;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.authInProgress ||
        LocalAuthExceptionCode.userRequestedFallback => AuthOutcome.cancelled,
        LocalAuthExceptionCode.temporaryLockout =>
          AuthOutcome.temporarilyLocked,
        LocalAuthExceptionCode.biometricLockout => AuthOutcome.biometricLocked,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware => AuthOutcome.noCredentials,
        _ => AuthOutcome.unavailable,
      };
    } on Object {
      return AuthOutcome.unavailable;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _gateway.stop();
    } on Object {
      // No había diálogo en curso.
    }
  }
}
