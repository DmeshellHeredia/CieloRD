# CieloRD — Estado final del Hito B

Fecha de validación: 23-11-2026 (America/Santo_Domingo).

## Resultado

El Hito B está implementado e integrado sin avanzar al Hito C. GPS, ubicación
manual, fotografías, notas de voz y mapa provincial funcionan detrás de
contratos inyectables. SQLite está en versión 3 y conserva datos v1/v2. Las
funciones esenciales y la cartografía no dependen de internet.

No se ejecutaron commits, push, merges ni despliegues. El directorio no contiene
metadatos `.git`, por lo que el inventario de cambios se reconstruyó a partir
del plan, los archivos del hito y las pruebas, no de un diff de Git.

## Entorno validado

- Flutter 3.47.7 y Dart 3.13.5.
- Java de Android Studio: 25; código Android/Kotlin configurado a JVM 17.
- Gradle wrapper 9.3.1, Android Gradle Plugin 9.1.0, Kotlin 2.4.0.
- Android minSdk 24 y targetSdk 36 en el manifiesto fusionado.
- Emulador disponible: Pixel_7_2, `emulator-5554`.

Dependencias añadidas con versiones exactas: `geolocator 14.1.2`,
`image_picker 1.2.4`, `record 7.2.0`, `just_audio 0.10.6`,
`path_provider 2.1.6`, `image 4.13.1` y `crypto 3.0.8`. Se mantuvieron
`sqflite 2.4.6` y `sqflite_common_ffi 2.4.7`. No se hizo actualización masiva.

## Implementación completada

### GPS y ubicación

- Captura foreground bajo acción explícita; sin última ubicación ni background.
- Estados preciso, aproximado, apagado, denied, deniedForever y timeout.
- Entrada manual de lugar/latitud/longitud y selección provincial en mapa.
- `capturedAt` UTC solo para una fijación GPS fresca.
- Una denegación no invalida ni bloquea el guardado manual.

### SQLite v3

- Migración mínima añade `location_captured_at`.
- Pruebas directas 1→3 y 2→3 conservan observaciones y ubicación previa.
- Registros anteriores obtienen timestamp nulo, sin reescritura destructiva.
- Tablas de medios, referencias y cola de borrado mantienen integridad y
  transacciones con la observación.

### Fotografías y voz

- Cámara, galería y `retrieveLostData`; máximo 5 fotos.
- Copia privada validada, miniatura JPEG y SHA-256; no se modifica/elimina el
  original externo.
- Grabación AAC-LC/M4A; máximo 3 audios y corte automático a 120 segundos.
- Reproducción local con load/play/pause/seek/stop y estado por `mediaId`.
- Vista previa, ampliación, reproducción y eliminación desde formulario/detalle.

### Ciclo de archivos

- Escritura atómica mediante `.part` y estados staged/committed.
- Guardado: SQLite primero, `commitStaged` después.
- Cancelación/salida: elimina solo staged de la sesión.
- Eliminación: cola durable y limpieza exclusiva de rutas administradas.
- Reconciliación idempotente elimina `.part` y huérfanos administrados, nunca
  archivos externos ni medios todavía referenciados.
- Prueba de reinicio confirma persistencia; prueba de borrado confirma que solo
  desaparece la copia privada asociada.

### Mapa provincial

- `CustomPainter` + `InteractiveViewer`, 32 unidades ADM1 y marcadores.
- Proyección Web Mercator reversible, hit-test dentro/fuera y selección manual.
- Temas Noche, Día y Astrónomo cubiertos por pruebas widget.
- GeoJSON incluido: 85 704 bytes; SHA-256
  `4A6403DF6B0380BDCC1D0213D335426F8833D93F40E01B509B6806800C2F0E15`.
- Fuente `geoBoundaries DOM-ADM1-93820187`, Natural Earth, Public Domain;
  revisión y atribución en `assets/maps/ATTRIBUTION.md`.
- El APK contiene el GeoJSON y el archivo de atribución. No usa tiles, HTTP,
  geocodificación ni caché remoto.

### Integración UI

- Formulario completo: GPS, ubicación manual/mapa, fotos, grabación y borrado.
- Registro rápido: GPS opcional; fallo de permiso no bloquea borrador.
- Detalle: mapa, fotografías y controles independientes por audio.
- Diario: ruta de mapa y refresco tras guardar/editar.
- Composición real en `main.dart` y recuperación antes de reconciliar.

## Validación automatizada

| Comando | Resultado |
|---|---|
| `flutter pub get` | Aprobado. 16 paquetes tienen versiones nuevas incompatibles con las restricciones actuales; no se actualizaron. |
| `flutter analyze` | Aprobado: `No issues found! (ran in 18.4s)`. |
| `flutter test` | Aprobado: `+379 ~6: All tests passed!`. |
| `flutter build apk --debug --no-pub` | Aprobado: 315,6 s. |

Las 6 omisiones son capturas/goldens intencionales. La suite mostró una
advertencia no fatal ya existente en
`test/widgets/ui_kit/dialogs_and_bars_test.dart:118`: el target de tap del texto
“Entiendo que no se puede deshacer” está fuera de pantalla; la prueba aprueba y
no pertenece al Hito B.

Cobertura añadida: gateways GPS; fotos/archivos; recorder/player; límite de
audio; bootstrap; parser/proyección/mapa; migración v2→v3; cola/reconciliación;
reinicio/borrado; widgets de formulario, detalle y los tres temas.

## APK

- Ruta: `build/app/outputs/flutter-apk/app-debug.apk`.
- Tamaño: 243 481 013 bytes.
- SHA-256: `5D951166DB382424AA5208A7BE7B63E6457C161F189F8AB933325AE873EF7307`.
- Instalación ADB en `emulator-5554`: `Success`.

Advertencias de build, no bloqueantes:

- Java 25 avisa que el acceso nativo de Gradle se restringirá en una versión
  futura.
- Herramientas Android: lector de XML SDK hasta v3 encontró XML v4; indica
  desalineación de Android Studio/command-line tools.
- `geolocator_android` usa una API Android deprecada y compila con source/target
  Java 8 internamente.

## Verificación Android manual

Con Wi-Fi y datos desactivados en el emulador se verificó:

- inicio correcto del APK y apertura del Diario;
- mapa offline visible desde la primera apertura comprobada, con 32 límites y
  atribución;
- formulario completo y controles GPS/fotos/voz presentes;
- selector offline devuelve provincia `Duarte` y coordenadas
  `19.343013, -70.265273` al formulario;
- ausencia de excepciones Flutter en logcat. Solo se registró
  `OpenGLRenderer: Unable to match the desired swap behavior`, propio del
  emulador.

La red del emulador se restauró al terminar.

## Auditoría offline y permisos

`src/main/AndroidManifest.xml` declara únicamente ubicación aproximada/precisa
y micrófono. No declara Internet, almacenamiento externo ni ubicación en
segundo plano. No hay imports de clientes HTTP ni mapas por tiles.

El APK debug fusionado sí contiene `INTERNET`, añadido por el manifest debug de
Flutter para hot reload/debugger, y `ACCESS_NETWORK_STATE`, heredado de
AndroidX Media3 por `just_audio`. CieloRD carga en el player solo rutas locales;
ninguna función esencial usa esos permisos. No se eliminaron porque hacerlo
alteraría herramientas/plugins fuera del comportamiento de producción.

## Comprobaciones manuales pendientes

Estas no se declaran aprobadas porque requieren hardware o una sesión manual
estable:

- cámara real y selección de una foto real del dispositivo;
- micrófono real, reproducción audible y entrega exacta al alcanzar 120 s;
- GPS real preciso/aproximado y diálogo denied/denied forever del SO;
- interrupciones por llamada, cambio de ruta de audio y background;
- proceso muerto por Android durante picker/grabación;
- ampliación y borrado visual de varios adjuntos después de reiniciar;
- accesibilidad manual con TalkBack y escalas máximas de texto.

La lógica correspondiente sí está cubierta con gateways falsos y SQLite/FFI
real. No se simula como validación física.

## Archivos del Hito B

### Configuración y recursos

- `pubspec.yaml`, `pubspec.lock`.
- `android/app/src/main/AndroidManifest.xml`.
- `assets/maps/dominican_republic_adm1.geojson`.
- `assets/maps/ATTRIBUTION.md`.

### Producción

- `lib/main.dart`.
- `lib/app/app_dependencies.dart`, `lib/app/cielo_app.dart`,
  `lib/app/hito_b_bootstrap.dart`.
- `lib/core/database/schema_v3.dart`, `database_migrations.dart`.
- `lib/features/location/data/geolocator_location_service.dart` y contrato.
- `lib/features/media/domain/media_service.dart` y adaptadores/servicios de
  medios, grabación, reproducción y mantenimiento en `lib/features/media/data`.
- `lib/features/map/domain/offline_province_map.dart` y presentación en
  `lib/features/map/presentation`.
- modelos/validación/store de observaciones y pantallas de formulario, registro
  rápido, Diario y detalle.

### Pruebas

- `test/unit/geolocator_location_service_test.dart`.
- `test/unit/local_media_service_test.dart`.
- `test/unit/local_voice_recorder_test.dart`.
- `test/unit/local_audio_player_service_test.dart`.
- `test/unit/offline_province_map_test.dart`.
- `test/unit/hito_b_bootstrap_test.dart`.
- `test/repositories/media_maintenance_service_test.dart`.
- `test/repositories/media_lifecycle_integration_test.dart`.
- pruebas de migración/persistencia en `sqlite_observation_store_test.dart`.
- `test/widgets/map/offline_map_widget_test.dart`.
- `test/widgets/observations/hito_b_form_integration_test.dart`.
- `test/widgets/observations/hito_b_detail_integration_test.dart`.

## Contratos e integración

Las firmas públicas definitivas están en `docs/HITO_B_CONTRACTS.md`. La UI debe
inyectar servicios por constructor, resolver adjuntos mediante `MediaService`,
confirmar staged solo tras éxito SQLite y conservar el refresco por resultado de
navegación. No debe abrir rutas relativas ni solicitar permisos al construir un
widget.
