import '../../../app/contracts.dart';
import '../../../l10n/cielo_strings.dart';
import '../../../l10n/failure_messages.dart';

/// Explica por qué no se pudo exportar o importar.
abstract final class BackupMessages {
  static String importFailure(AppFailure failure) =>
      switch (failure.fieldErrors['backup']) {
        BackupErrors.notAZip => CieloStrings.importNotAZip,
        BackupErrors.unsafePath => CieloStrings.importUnsafe,
        BackupErrors.unexpectedEntry => CieloStrings.importUnexpected,
        BackupErrors.tooLarge => CieloStrings.importTooLarge,
        BackupErrors.hash || BackupErrors.size => CieloStrings.importHash,
        BackupErrors.type => CieloStrings.importWrongType,
        BackupErrors.version => CieloStrings.errorImportNewer,
        BackupErrors.expired => CieloStrings.importExpired,
        BackupErrors.structure => CieloStrings.errorImportInvalid,
        _ => FailureMessages.of(failure),
      };

  static String exportFailure(AppFailure failure) =>
      failure.fieldErrors['backup'] == BackupErrors.tooLarge
      ? CieloStrings.exportTooLarge
      : FailureMessages.of(failure);
}
