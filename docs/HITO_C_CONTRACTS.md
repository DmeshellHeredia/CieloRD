# CieloRD — Contratos públicos del Hito C

Fecha: 23-11-2026. Import canónico: `package:cielo_rd/app/contracts.dart`.
Todo lo de C0 y Hito B sigue vigente salvo las ampliaciones indicadas aquí.
Los parámetros nuevos son opcionales: ningún llamador de A/B cambia.

## Errores

`FailureCode.busy` (nuevo): hay una operación exclusiva en curso (exportar,
importar o borrar). Lo devuelve cualquier escritura rechazada por `WriteGate`.

## Puerta de escrituras (infraestructura)

```dart
final class WriteGate {
  bool get isClosed;
  Future<T> write<T>(Future<T> Function() action);      // concurrente
  Future<T> exclusive<T>(Future<T> Function() action);  // en solitario
}
```

Se crea una sola en `main.dart` y la comparten almacén, medios, mantenimiento,
perfil, preferencias, copias y borrado (`gate:` opcional en sus constructores).
No es reentrante. Con la puerta cerrada, `write` y `exclusive` lanzan
`WriteGateClosed`, que los adaptadores traducen a `FailureCode.busy`.

## Perfil

```dart
Future<Result<ObserverProfile?>> get();
Future<Result<ObserverProfile>> save(ObserverProfile profile,
    {ObservationMedia? newPhoto});
```

`newPhoto` es el adjunto *staged* cuyo ID coincide con `photoMediaId`. Tras
`Success`, el llamador ejecuta `commitStaged([id])` y `MediaMaintenance.run()`.
La foto anterior pasa a `pending_file_deletions` si nadie más la usa. Límites:
60/60/30/200 caracteres; errores `too_long`, `invalid_characters`,
`wrong_media_type` en `firstName`, `lastName`, `studentId`, `motto`, `photo`.

## Preferencias

`AppTheme` gana `system` (SQLite v4). `AppSettings.copyWith(...)`.
`SettingsController` (ChangeNotifier): `settings`, `loadFailure`, `load()`,
`update(cambio)` (optimista, en orden, revierte si falla) y `resetToDefaults()`.
Si `loadFailure != null`, la app no se abre: no se sabe si hay bloqueo.

## Estadísticas

`ObservationStats` gana `byPlace`, `byLocalMonth` e `inMonthOf(DateTime)`.
`SqliteStatsService({database, provinceMap, maxPlaces = 10})` agrega en SQLite con
los mismos filtros que el Diario (`ObservationFilterSql`). El filtro por defecto
(`status: published`) excluye borradores.

## Copias

`BackupReceipt`, `BackupInspection` e `ImportReport` ganan campos opcionales
(conteos, versión, fecha, faltantes, copias, omitidas, perfil).

```dart
Future<void> discardInspection(String inspectionToken);   // BackupService
abstract interface class DocumentGateway {
  Future<Uri?> createDocument({required String suggestedName, required String mimeType});
  Future<Uri?> openDocument({required List<String> mimeTypes});
}
```

Rechazos: `AppFailure.fieldErrors['backup']` con un código de `BackupErrors`
(`not_a_zip`, `unsafe_path`, `unexpected_entry`, `too_large`,
`invalid_structure`, `hash_mismatch`, `size_mismatch`, `wrong_type`,
`unsupported_version`, `inspection_expired`). El token solo vale para la última
inspección y se revalida contra el SHA-256 de los bytes revisados. Formato y
estrategia de fusión: `docs/superpowers/specs/2026-11-23-hito-c-design.md`.

## Borrar Todo

```dart
Future<Result<EraseAllPreview>> preview();
Future<Result<EraseAllReport>> eraseAll();
Future<bool> hasPendingErase();
bool EraseAllReport.isComplete =>
    pendingFiles == 0 && databaseCleared && preferencesCleared;
```

La interfaz anuncia éxito solo con `isComplete`. `main.dart` llama a `eraseAll()`
antes de recuperar o abrir nada si `hasPendingErase()`.

## Autenticación local

```dart
enum AuthAvailability { available, noCredentials, unknown }
enum AuthOutcome { success, cancelled, failed, temporarilyLocked,
                   biometricLocked, noCredentials, unavailable }
abstract interface class LocalAuthService {
  Future<AuthAvailability> availability();
  Future<AuthOutcome> authenticate(String reason);   // nunca lanza
  Future<void> cancel();
}
```

`AppLockController` (ChangeNotifier): `isLocked`, `isAuthenticating`,
`lastOutcome`, `credentialsMissing`, `attach()`, `unlock()`, `enable()`,
`disable()`, `openWithoutCredentials()`. No es cifrado.

## Composición y rutas

`CieloApp` acepta opcionalmente `settings`, `lock`, `profile`, `stats`, `backup`,
`documents`, `eraseAll` y `pendingErase`. `DiaryScreen.dataReset` (Listenable)
devuelve el Diario a sus filtros iniciales y recarga.

`/estadisticas`, `/ajustes`, `/ajustes/exportar`, `/ajustes/importar`,
`/ajustes/borrar`, `/acerca`, `/perfil`.

## SQLite v4

Recrea `app_settings` con `theme IN ('system','night','day','astronomer')` y copia
la fila. No editar `schema_v4.dart` una vez distribuida. `AppDatabase.destroy()`
cierra y elimina la base; las aperturas concurrentes reciben una nueva y vacía.

## Canal Android `com.dmeshell.cielo_rd/platform`

`createDocument`, `openDocument`, `writeDocument`, `readDocument`,
`deleteDocument`, `clearPreferences`, `setRecentsPrivacy`. Solo acepta rutas
dentro de `dataDir` y URI `content:`.
