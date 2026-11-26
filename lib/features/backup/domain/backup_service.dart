import '../../../core/domain/result.dart';
import '../../observations/domain/observation_filter.dart';

enum BackupFormat { jsonMetadata, zipComplete }

enum ImportConflictPolicy { importAsCopies }

final class BackupProgress {
  const BackupProgress({
    required this.operationId,
    required this.phase,
    required this.completed,
    this.total,
  });
  final String operationId;
  final String phase;
  final int completed;
  final int? total;
}

final class BackupReceipt {
  const BackupReceipt({
    required this.destination,
    required this.observationCount,
    required this.includesMedia,
    this.mediaCount = 0,
    this.missingMedia = 0,
    this.byteSize = 0,
  });

  /// URI from the system document picker; may be content: on Android.
  final Uri destination;
  final int observationCount;
  final bool includesMedia;
  final int mediaCount;

  /// Adjuntos registrados cuyo archivo ya no estaba en el teléfono.
  final int missingMedia;
  final int byteSize;
}

final class BackupInspection {
  BackupInspection({
    required this.token,
    required this.formatVersion,
    required this.observationCount,
    required this.mediaCount,
    required this.uncompressedBytes,
    this.appVersion = '',
    this.createdAt,
    this.draftCount = 0,
    this.photoCount = 0,
    this.audioCount = 0,
    this.newCount = 0,
    this.identicalCount = 0,
    this.copyCount = 0,
    this.hasProfile = false,
    this.willImportProfile = false,
    List<String> warnings = const [],
  }) : warnings = List.unmodifiable(warnings);

  /// Opaque service-issued token bound to the inspected bytes, not a trusted UI path.
  final String token;
  final int formatVersion;

  /// Publicadas y borradores.
  final int observationCount;
  final int mediaCount;
  final int uncompressedBytes;
  final String appVersion;
  final DateTime? createdAt;
  final int draftCount;

  /// Fotos de observaciones y del perfil.
  final int photoCount;
  final int audioCount;

  /// Se añadirán con su ID original.
  final int newCount;

  /// Ya están en el teléfono: se omitirán.
  final int identicalCount;

  /// Difieren de la versión del teléfono: se añadirán como copia.
  final int copyCount;
  final bool hasProfile;
  final bool willImportProfile;
  final List<String> warnings;
}

final class ImportReport {
  const ImportReport({
    required this.importedObservations,
    required this.importedMedia,
    this.importedAsCopies = 0,
    this.skippedIdentical = 0,
    this.profileImported = false,
  });

  /// Incluye las copias.
  final int importedObservations;
  final int importedMedia;
  final int importedAsCopies;
  final int skippedIdentical;
  final bool profileImported;
}

/// Motivos estables de rechazo, en `AppFailure.fieldErrors['backup']`.
abstract final class BackupErrors {
  static const String notAZip = 'not_a_zip';
  static const String unsafePath = 'unsafe_path';
  static const String unexpectedEntry = 'unexpected_entry';
  static const String tooLarge = 'too_large';
  static const String structure = 'invalid_structure';
  static const String hash = 'hash_mismatch';
  static const String size = 'size_mismatch';
  static const String type = 'wrong_type';
  static const String version = 'unsupported_version';
  static const String expired = 'inspection_expired';
}

abstract interface class BackupService {
  Stream<BackupProgress> get progress;
  Future<Result<BackupReceipt>> export({
    required ObservationFilter filter,
    required BackupFormat format,
    required Uri destination,
    bool includeProfile = false,
  });

  /// Valida el archivo completo sin tocar los datos del teléfono.
  Future<Result<BackupInspection>> inspect(Uri source);

  /// Must revalidate the snapshot/token; never trust a client-created inspection.
  Future<Result<ImportReport>> importZip(
    String inspectionToken, {
    ImportConflictPolicy policy = ImportConflictPolicy.importAsCopies,
  });

  /// Elimina la copia temporal de una inspección que no se va a importar.
  Future<void> discardInspection(String inspectionToken);
}

/// Selector de documentos del sistema y copia por flujo.
abstract interface class DocumentGateway {
  /// `null` si se canceló.
  Future<Uri?> createDocument({
    required String suggestedName,
    required String mimeType,
  });

  /// `null` si se canceló.
  Future<Uri?> openDocument({required List<String> mimeTypes});
}
