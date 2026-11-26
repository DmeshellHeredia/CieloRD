enum FailureCode {
  validation,
  notFound,
  conflict,
  permissionDenied,
  permissionPermanentlyDenied,
  serviceDisabled,
  timeout,
  storageFull,
  corruptData,
  unsupportedVersion,
  persistence,
  io,
  unavailable,

  /// Otra operación exclusiva (exportar, importar, borrar) está en curso.
  busy,
  unexpected,
}

/// Stable machine code + optional field errors. UI owns translated messages.
final class AppFailure {
  AppFailure(
    this.code, {
    this.message = '',
    Map<String, String> fieldErrors = const {},
  }) : fieldErrors = Map.unmodifiable(fieldErrors);
  final FailureCode code;
  final String message;

  /// Keys are public input field paths; values are stable validation codes.
  final Map<String, String> fieldErrors;
}
