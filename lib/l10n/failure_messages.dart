import '../app/contracts.dart';
import 'cielo_strings.dart';

/// Traduce el código estable de un [AppFailure] a un mensaje para la persona
/// usuaria. Nunca muestra `AppFailure.message`, que es técnico (C0 §Integración 7).
abstract final class FailureMessages {
  static String of(AppFailure failure) => forCode(failure.code);

  static String forCode(FailureCode code) => switch (code) {
        FailureCode.validation => CieloStrings.failureValidation,
        FailureCode.notFound => CieloStrings.errorNotFound,
        FailureCode.conflict => CieloStrings.failureConflict,
        FailureCode.permissionDenied => CieloStrings.failurePermissionDenied,
        FailureCode.permissionPermanentlyDenied => CieloStrings.failurePermissionPermanentlyDenied,
        FailureCode.serviceDisabled => CieloStrings.failureServiceDisabled,
        FailureCode.timeout => CieloStrings.failureTimeout,
        FailureCode.storageFull => CieloStrings.errorStorageFull,
        FailureCode.corruptData => CieloStrings.failureCorruptData,
        FailureCode.unsupportedVersion => CieloStrings.failureUnsupportedVersion,
        FailureCode.persistence => CieloStrings.failurePersistence,
        FailureCode.io => CieloStrings.failureIo,
        FailureCode.unavailable => CieloStrings.failureUnavailable,
        FailureCode.busy => CieloStrings.failureBusy,
        FailureCode.unexpected => CieloStrings.failureUnexpected,
      };
}
