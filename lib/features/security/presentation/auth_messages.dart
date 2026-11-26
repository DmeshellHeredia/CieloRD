import '../../../l10n/cielo_strings.dart';
import '../domain/local_auth_service.dart';

/// Mensaje para cada resultado de autenticación.
abstract final class AuthMessages {
  static String of(AuthOutcome outcome) => switch (outcome) {
    AuthOutcome.success => CieloStrings.done,
    AuthOutcome.cancelled => CieloStrings.lockCancelled,
    AuthOutcome.failed => CieloStrings.lockFailed,
    AuthOutcome.temporarilyLocked => CieloStrings.lockTemporarily,
    AuthOutcome.biometricLocked => CieloStrings.lockBiometric,
    AuthOutcome.noCredentials => CieloStrings.settingsLockNoCredentials,
    AuthOutcome.unavailable => CieloStrings.lockUnavailable,
  };
}
