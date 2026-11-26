import '../../../core/domain/result.dart';

/// Lo que hay ahora mismo en el espacio privado de CieloRD.
final class EraseAllPreview {
  const EraseAllPreview({
    required this.published,
    required this.drafts,
    required this.photos,
    required this.audios,
    required this.hasProfile,
    required this.hasProfilePhoto,
    required this.hasSettings,
    required this.temporaryFiles,
  });
  final int published;
  final int drafts;

  /// Fotos de observaciones; la del perfil va en [hasProfilePhoto].
  final int photos;
  final int audios;
  final bool hasProfile;
  final bool hasProfilePhoto;
  final bool hasSettings;

  /// Temporales, adjuntos sin confirmar y archivos en cola de borrado.
  final int temporaryFiles;

  bool get isEmpty =>
      published == 0 &&
      drafts == 0 &&
      photos == 0 &&
      audios == 0 &&
      !hasProfile &&
      !hasSettings &&
      temporaryFiles == 0;
}

final class EraseAllReport {
  const EraseAllReport({
    required this.pendingFiles,
    this.databaseCleared = true,
    this.preferencesCleared = true,
    this.residual = const [],
  });

  /// Archivos privados que no se pudieron eliminar.
  final int pendingFiles;
  final bool databaseCleared;

  /// Preferencias que los plugins guardan fuera de SQLite.
  final bool preferencesCleared;

  /// Rutas privadas relativas pendientes, para diagnóstico.
  final List<String> residual;
  bool get isComplete =>
      pendingFiles == 0 && databaseCleared && preferencesCleared;
}

abstract interface class EraseAllService {
  /// Conteos reales leídos de SQLite y del disco.
  Future<Result<EraseAllPreview>> preview();

  /// Caller confirms with user. Serialized against writes; reentrant after crash.
  /// Includes profile/settings/internal backups, excludes externally exported files.
  Future<Result<EraseAllReport>> eraseAll();

  /// `true` si un borrado anterior no llegó a completarse.
  Future<bool> hasPendingErase();
}
