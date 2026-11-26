/// Qué puede hacer el teléfono ahora mismo.
enum AuthAvailability {
  /// Hay biometría o credencial de pantalla (PIN, patrón, contraseña).
  available,

  /// El teléfono lo admite, pero no tiene ninguna credencial configurada.
  noCredentials,

  /// No se pudo averiguar. No equivale a "sin credenciales".
  unknown,
}

enum AuthOutcome {
  success,

  /// La persona canceló o el sistema cerró el diálogo.
  cancelled,

  /// El teléfono no reconoció a la persona.
  failed,

  /// Demasiados intentos: hay que esperar.
  temporarilyLocked,

  /// La biometría quedó bloqueada hasta usar el PIN del teléfono.
  biometricLocked,
  noCredentials,
  unavailable,
}

/// Verificación de identidad por el sistema operativo. CieloRD no recibe ni
/// guarda huellas, PIN ni ningún otro secreto. No cifra los datos.
abstract interface class LocalAuthService {
  Future<AuthAvailability> availability();

  /// Abre el diálogo del sistema. Nunca lanza.
  Future<AuthOutcome> authenticate(String reason);

  /// Cierra un diálogo en curso, si lo hay.
  Future<void> cancel();
}
