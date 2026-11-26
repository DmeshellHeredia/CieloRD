# CieloRD — Contratos C0

Referencia: Plan Maestro v1.0, leído completo el 22-11-2026. Alcance: contratos,
validaciones, controlador de formulario y apertura/migración SQLite v1. Las
implementaciones de CRUD y dispositivos NO forman parte de C0. No hay pantallas
nuevas, navegación ni inicialización de la base en `main.dart`.

## Integración de Claude

Import canónico: `package:cielo_rd/app/contracts.dart`.
Composición: `package:cielo_rd/app/app_dependencies.dart`.

1. Implementar fakes con `implements` de los contratos canónicos; no crear modelos
   paralelos. Los contratos de servicios son abstractos, no adaptadores funcionales.
2. Inyectar los colaboradores por constructor. No usar un service locator global.
3. Para el formulario usar `ObservationFormController`; Claude lo escucha y su
   propietario llama `dispose()`. C0 solo edita/valida: no guarda ni pide permisos.
4. Usar pattern matching de `Success<T>` / `Failure<T>` o `fold`. No interpretar
   cancelación de selector como error: `Success(null)`.
5. Acceder a los campos de la observación por `observation.input.title`, etc.
6. No abrir rutas relativas desde UI: `MediaService.resolveLocalPath(mediaId)`.
7. La UI traduce los códigos de error; no debe depender del texto `message`.
8. Los futuros controladores de listado/detalle y guardado se implementarán en C1
   tras revisión. Refresco explícito después de una mutación, sin streams de SQLite.
9. `go_router` está decidido, pero su instalación y composición quedan fuera de C0.

## Resultados y errores

```dart
sealed class Result<T>
const Success<T>(T value)
const Failure<T>(AppFailure failure)
R Result<T>.fold<R>({
  required R Function(T value) success,
  required R Function(AppFailure failure) failure,
})
AppFailure(FailureCode code, {
  String message = '',
  Map<String, String> fieldErrors = const {},
})
```

`Success.value`, `Failure.failure`, `AppFailure.code/message/fieldErrors` son
propiedades finales. El mapa de errores es una copia no modificable.
Comandos sin payload retornan `Success(Unit.value)`.

`FailureCode`: validation, notFound, conflict, permissionDenied,
permissionPermanentlyDenied, serviceDisabled, timeout, storageFull, corruptData,
unsupportedVersion, persistence, io, unavailable, unexpected.

Los contratos retornarán fallos esperados como `Failure`. Los errores de
programación de constructores (filtro invertido, configuración inválida) lanzan
`ArgumentError`; la UI debe construir esos valores desde entradas ya comprobadas.

## Modelos de observaciones

```dart
ObservationInput({
  String title = '', DateTime? observedAt, int? utcOffsetMinutes,
  ObservationCategory? category, String? subtypeCode,
  SkyCondition? skyCondition, String? description, int? durationSeconds,
  CardinalDirection? direction, double? elevationDegrees,
  ObservationLocation? location, List<ObservationMedia> media = const [],
})

ObservationInput copyWith({
  String? title, DateTime? Function()? observedAt,
  int? Function()? utcOffsetMinutes, ObservationCategory? Function()? category,
  String? Function()? subtypeCode, SkyCondition? Function()? skyCondition,
  String? Function()? description, int? Function()? durationSeconds,
  CardinalDirection? Function()? direction, double? Function()? elevationDegrees,
  ObservationLocation? Function()? location, List<ObservationMedia>? media,
})

Observation({
  required String id, required ObservationStatus status,
  required ObservationInput input, required DateTime createdAt,
  required DateTime updatedAt, required int revision,
})

const ObservationLocation({
  String? placeName, double? latitude, double? longitude,
  LocationSource? source, double? accuracyM,
})

const ObservationMedia({
  required String id, required MediaKind kind, required String relativePath,
  required String mimeType, required int byteSize,
  String? sha256, int? durationMs,
})
```

Los parámetros corresponden a propiedades finales con los mismos nombres.
`ObservationLocation.hasCoordinates` es un getter booleano. La lista de medios se
copia y queda no modificable. Reemplazar un valor requiere otra instancia.

**Borrar un campo nullable:** `input.copyWith(durationSeconds: () => null)`.
Omitir el callback conserva el valor anterior; `() => valor` lo reemplaza.

Fechas se normalizan a UTC. El offset original es un entero independiente; no se
infiere de la zona actual del dispositivo. `observedAt` y `utcOffsetMinutes` deben
existir juntos. Los IDs persistidos serán UUID generados en la capa de servicio
en C1; C0 no incorpora generación de IDs ni impone UUID a fixtures de pruebas.

### Códigos estables

| Tipo | Valores / códigos SQLite |
|---|---|
| ObservationStatus | draft, published |
| ObservationCategory | astronomy, atmospheric, birds, artificial, other |
| SkyCondition | clear, partlyCloudy → partly_cloudy, cloudy, mist, saharanDust → saharan_dust, lightRain → light_rain, other, unknown |
| CardinalDirection | north → n, northEast → ne, east → e, southEast → se, south → s, southWest → sw, west → w, northWest → nw |
| LocationSource | text, manual, gps |
| MediaKind | photo, audio |

Para cielo y dirección usar `.code`; para los demás `.name`. Nunca guardar `.index`.
Subtipo es un código opcional extensible en snake_case; no se impone una relación
cerrada con la categoría raíz. La UI es responsable de las etiquetas en español.

### Validación

```dart
const ObservationValidator()
Result<ObservationInput> validate(
  ObservationInput input, {required ObservationStatus status})
```

Publicar exige únicamente título no vacío tras trim, fecha/hora y categoría.
Descripción, cielo, ubicación y duración son opcionales. Un borrador vacío es
válido, pero los datos suministrados deben ser válidos en ambos estados.

- Duración: entero >= 0 en segundos; null significa desconocida, no cero.
- Offset: -840..840 minutos. Elevación estimada: 0..90 grados, finita.
- Coordenadas: juntas, finitas, latitud -90..90, longitud -180..180.
- Coordenadas requieren source manual/gps; source text requiere lugar escrito.
- Precisión: solo GPS con coordenadas, finita y >= 0.
- Máximo 5 fotos, 3 audios; audio de 1..120000 ms, fotos sin duración.
- Medios: ID no vacío y único en la observación, tamaño positivo, MIME coherente,
  ruta relativa sin segmentos vacíos, `..`, `.`, backslash, colon ni NUL.
- SHA-256 opcional: exactamente 64 caracteres hexadecimales minúsculos.
- El validador no modifica silenciosamente datos ni abre archivos.

Claves de errores: title, observedAt, category, utcOffsetMinutes,
durationSeconds, elevationDegrees, subtypeCode, location.coordinates,
location.latitude, location.longitude, location.source, location.placeName,
location.accuracyM, media.photos, media.audios y media.N.{id,relativePath,
byteSize,mimeType,durationMs,sha256} (N es índice desde cero).

Códigos de validación: required, time_offset_pair_required, out_of_range,
non_negative, invalid_code, pair_required, coordinate_source_required,
invalid_accuracy, max_5, max_3, invalid_or_duplicate, unsafe_path,
positive_required, wrong_media_type, audio_duration_1_120000,
photo_has_no_duration, invalid_hash.

## Consultas y mutaciones (solo contratos)

```dart
ObservationFilter({
  String query = '', DateTime? from, DateTime? until,
  ObservationCategory? category, String place = '',
  ObservationStatus? status = ObservationStatus.published,
})
ObservationPage({required List<Observation> items, String? nextCursor})

// ObservationRepository
Future<Result<ObservationPage>> list({
  required ObservationFilter filter, String? cursor, int limit = 30})
Future<Result<int>> count({required ObservationFilter filter})
Future<Result<Observation>> getById(String id)

// ObservationService
Future<Result<Observation>> create(
  ObservationInput input, {required ObservationStatus status})
Future<Result<Observation>> update(String id, ObservationInput input, {
  required ObservationStatus status, required int expectedRevision})
Future<Result<Unit>> delete(String id, {required int expectedRevision})

// DraftService
Future<Result<Observation>> save(
  ObservationInput input, {String? id, int? expectedRevision})
Future<Result<Observation>> publish(String id, {required int expectedRevision})
```

Filtros AND; inicio inclusivo, final exclusivo. La UI convierte el rango de días
a instantes antes de crear el filtro. Intervalo vacío o invertido lanza error.
`status: null` incluye ambos estados. La búsqueda cubre título,
descripción y lugar sin distinguir mayúsculas/acentos. Orden por fecha DESC,
nulos al final, luego ID DESC. Límite 1..100. Cursor opaco vinculado al filtro;
cambiar un filtro exige reiniciar el cursor. Páginas con copia inmutable.
`count` aplica exactamente los mismos filtros y devuelve el total sin paginar.

ID inexistente => notFound; revisión distinta => conflict; nunca sobrescribir en
silencio. `DraftService.save`: id/revisión ambos ausentes al crear, ambos presentes
al editar. La eliminación individual confirma borrado lógico y encola limpieza;
no promete que el disco ya se haya limpiado. No hay implementaciones C1 ocultas.

## Controlador C0

```dart
ObservationFormController({
  required ObservationValidator validator, ObservationInput? initialInput})
ObservationInput get input
AppFailure? get failure
bool get isDirty
void replaceInput(ObservationInput input)
Result<ObservationInput> validateFor(ObservationStatus status)
void reset()
```

Extiende ChangeNotifier. replaceInput limpia errores y marca dirty; validateFor
notifica y devuelve el resultado; reset vuelve a la instancia inicial y limpia
dirty/errores. No guarda. No ejecuta operaciones asíncronas ni pide permisos.

## Servicios de dispositivo (solo contratos)

```dart
// LocationService
Future<Result<LocationPermission>> permission()
Future<Result<LocationFix>> current({Duration timeout = const Duration(seconds: 20)})

// MediaService
Future<Result<ObservationMedia?>> pickPhoto(PhotoSource source)
Future<Result<List<ObservationMedia>>> recoverPhotos()
Future<Result<Unit>> discardStaged(String mediaId)
Future<Result<String>> resolveLocalPath(String mediaId)

// VoiceRecorder
Stream<RecordingState> get states
Future<Result<Unit>> start()
Future<Result<ObservationMedia>> stop()
Future<Result<Unit>> cancel()
Future<void> dispose()

// AudioPlayerService
Stream<PlaybackState> get states
Future<Result<Unit>> load(String mediaId)
Future<Result<Unit>> play()
Future<Result<Unit>> pause()
Future<Result<Unit>> seek(Duration position)
Future<Result<Unit>> stop()
Future<void> dispose()
```

`LocationFix({required ObservationLocation location, required DateTime capturedAt})`.
Permisos: notDetermined, denied, deniedPermanently, approximate, precise. Consultar
permission no muestra diálogo; current se invoca solo por acción del usuario.
PhotoSource: camera/gallery. Cancelar selector => Success(null).

`const RecordingState({required RecorderPhase phase, Duration elapsed = Duration.zero, AppFailure? failure})`.
RecorderPhase: idle/recording/stopping/failed.
`const PlaybackState({required PlayerPhase phase, Duration position = Duration.zero, Duration? duration, AppFailure? failure})`.
PlayerPhase: idle/loading/paused/playing/completed/failed. Errores de comandos
viajan por Result; errores asíncronos se publican como phase failed y failure
no nulo en el estado del stream. Fuera de failed, failure debe ser null.

## Perfil, preferencias, estadísticas

```dart
const ObserverProfile({String firstName = '', String lastName = '',
  String studentId = '', String motto = '', String? photoMediaId})
AppSettings({AppTheme theme = AppTheme.night, double? textScale,
  bool reducedMotion = false, bool authenticationEnabled = false})

// ProfileRepository
Future<Result<ObserverProfile?>> get()
Future<Result<ObserverProfile>> save(ObserverProfile profile)
// SettingsRepository
Future<Result<AppSettings>> get()
Future<Result<AppSettings>> save(AppSettings settings)
// StatsService
Future<Result<ObservationStats>> summarize(ObservationFilter filter)
```

Perfil ausente => Success(null). Matrícula es String, conserva ceros iniciales.
Preferencias ausentes => defaults. AppTheme: night/day/astronomer. Escala null sigue
el sistema; valor explícito finito > 0 y <= 3. No limitar el ajuste accesible del
sistema desde UI. Activar autenticación requerirá comprobar soporte en fase futura.

`ObservationStats({required int total, required int knownDurationSeconds,
required int withKnownDuration, required Map<ObservationCategory,int> byCategory,
required Map<String,int> byLocalDate, required Map<int,int> byLocalHour,
required Map<String,int> byProvince})`. Mapas copiados/no modificables. Fechas
YYYY-MM-DD con offset original, horas 0..23, provincia derivada offline cuando sea
posible. La duración desconocida no se trata como medición de cero.

## Backup y mantenimiento (solo contratos)

```dart
// BackupService
Stream<BackupProgress> get progress
Future<Result<BackupReceipt>> export({required ObservationFilter filter,
  required BackupFormat format, required Uri destination, bool includeProfile = false})
Future<Result<BackupInspection>> inspect(Uri source)
Future<Result<ImportReport>> importZip(String inspectionToken, {
  ImportConflictPolicy policy = ImportConflictPolicy.importAsCopies})

// EraseAllService
Future<Result<EraseAllReport>> eraseAll()
```

BackupFormat: jsonMetadata/zipComplete. ImportConflictPolicy: importAsCopies.
URI puede ser content: de Android; no asumir ruta del sistema de archivos.
inspect devuelve token opaco que la implementación revalidará contra los bytes
inspeccionados; el cliente no puede convertir una ruta arbitraria en plan confiable.

```dart
const BackupProgress({required String operationId, required String phase,
  required int completed, int? total})
const BackupReceipt({required Uri destination, required int observationCount,
  required bool includesMedia})
BackupInspection({required String token, required int formatVersion,
  required int observationCount, required int mediaCount,
  required int uncompressedBytes, List<String> warnings = const []})
const ImportReport({required int importedObservations, required int importedMedia})
const EraseAllReport({required int pendingFiles})
bool EraseAllReport.get isComplete
```

Todos esos parámetros corresponden a propiedades finales. Warnings es copia no
modificable. isComplete significa pendingFiles == 0. La UI confirma eraseAll;
el servicio futuro serializa escrituras y recupera borrados interrumpidos.

## Composición

```dart
const AppDependencies({
  required ObservationRepository observations,
  required ObservationService observationService, required DraftService drafts,
  required LocationService location, required MediaService media,
  required VoiceRecorder recorder, required AudioPlayerService player,
  required ProfileRepository profile, required SettingsRepository settings,
  required StatsService stats, required BackupService backup,
  required EraseAllService eraseAll,
  ObservationValidator validator = const ObservationValidator(),
})
```

Propiedades finales con esos nombres. La UI puede recibir solo el colaborador
necesario, sin exigir montar todos los fakes para un componente aislado.

## Infraestructura SQLite (no importar desde UI)

```dart
AppDatabase({required DatabaseFactory factory, required String path})
static Future<AppDatabase> AppDatabase.android()
Future<Database> AppDatabase.open()
Future<void> AppDatabase.close()
const DatabaseMigrations()
static const DatabaseMigrations.currentVersion = 2
Future<void> DatabaseMigrations.migrate(Database db, int from, int to)
```

Una instancia por ruta en composición. android usa el directorio privado de
sqflite y cielo_rd.db. Aperturas concurrentes de la misma instancia comparten
Future; close permite reabrir después. No iniciar la base desde un widget.

Seis tablas según Plan Maestro: observations, media_files, observation_media,
observer_profile, app_settings, pending_file_deletions. Consultar
`lib/core/database/schema_v1.dart` y `schema_v2.dart` para el DDL exacto. Tiempo INTEGER en ms UTC;
created_at/updated_at conservan esos nombres. Perfil/settings tienen id=1.
No hay filas de ejemplo ni datos personales preinsertados.

Índices explícitos por estado/fecha, estado/categoría/fecha y lugar; índices
implícitos de PK/UNIQUE cubren enlaces de observación y medios, más índice de foto
de perfil. Rutas relativas únicas. FK ON en cada apertura; borrar observación
borra enlaces, no archivos ni media_files automáticamente. La cola de limpieza
se crea aquí; su procesador/reconciliador llega en las fases de multimedia/borrado.

Las migraciones 0→1 y 1→2 corren en la transacción de sqflite. v2 agrega
`search_text` y rellena `search_text`/`place_search` normalizados en filas v1.
No anidar transacciones ni
usar DROP para recuperarse de errores. Una versión futura se rechaza sin borrar.
Nunca editar migraciones ya publicadas; los cambios siguientes van en v3.
El DDL aplica invariantes básicos; validación de archivos/límites por observación
pertenece al validador y a las futuras operaciones transaccionales del servicio.

## Decisiones que requieren revisión antes de C1

- Aprobar los nombres, la agrupación Observation.input y callbacks de copyWith.
- Aprobar elevación 0..90 y escala explícita (0,3], decisiones concretadas en C0.
- Vocabulary de subtipos extensible; acordar códigos que mostrará la UI.
- Revisar aceptación de C0 después de resolver dependencias y ejecutar los gates
  Flutter/Android pendientes; ver C0_STATUS.md. Estas firmas son la propuesta
  implementada para congelar con la revisión, no una aprobación ya recibida.
