# CieloRD — Diseño técnico del Hito B

Fecha: 22-11-2026. Ejecución autónoma autorizada por el responsable.

## Intención

Integrar ubicación GPS opcional, fotografías, notas de voz y un mapa provincial
offline de República Dominicana sin degradar el CRUD y la experiencia offline
del Hito A. El hardware siempre es opcional: una denegación, interrupción o
ausencia de archivo debe producir un estado recuperable, nunca impedir guardar
una observación manual.

## Alcance y límites

- Solo permisos foreground, solicitados por una acción explícita.
- Máximo 5 fotos y 3 audios; cada audio dura como máximo 120 segundos.
- Archivos en almacenamiento privado y metadatos/rutas relativas en SQLite.
- Mapa vectorial empaquetado; ninguna petición HTTP, tile o geocodificación.
- No se implementan perfil, borrado integral, exportación, estadísticas ni
  autenticación del Hito C.
- No se afirma funcionamiento de cámara, GPS o micrófono sin prueba Android.

## Enfoques considerados

1. **Adaptadores de plugins + almacenamiento propio + mapa pintado (elegido).**
   `geolocator`, `image_picker`, `record`, `just_audio` y `path_provider` quedan
   detrás de los contratos existentes. `CustomPainter` e `InteractiveViewer`
   dibujan GeoJSON local. Es el enfoque del Plan Maestro, mantiene pruebas por
   inyección y garantiza que el mapa nunca use red.
2. **`flutter_map` sin tiles.** Simplifica algunos gestos, pero agrega una capa
   cartográfica innecesaria para 32 polígonos y facilita una futura dependencia
   accidental de tiles. Se descarta.
3. **Canales Android propios.** Darían control máximo, pero duplican plugins
   maduros, amplían el código Kotlin y el riesgo antes de la fecha académica.
   Se descarta.

## Dependencias verificadas

- `geolocator 14.1.2`: permisos foreground, precisión aproximada/precisa y
  posición actual. No se usa `ACCESS_BACKGROUND_LOCATION` ni última posición.
- `image_picker 1.2.4`: cámara/galería y `retrieveLostData`; todo resultado de
  caché se copia antes de devolverse.
- `record 7.2.0`: AAC-LC/M4A y permiso de micrófono.
- `just_audio 0.10.6`: archivos locales, play/pause/seek y streams de estado.
- `path_provider 2.1.6`: directorio de soporte privado y temporal.
- `image 4.13.1`: validación/decodificación y miniatura JPEG.
- `crypto 3.0.8`: SHA-256 de adjuntos.

El dry-run de Pub resolvió estas versiones con Flutter 3.47.7/Dart 3.13.5.

## Ubicación

`GeolocatorLocationService` implementa `LocationService` mediante un gateway
inyectable. `permission()` solo consulta; `current()` comprueba el servicio,
solicita permiso si corresponde y obtiene una posición con timeout. Android 12
puede conceder ubicación aproximada; el resultado conserva la precisión real.
No se usa la última posición conocida, evitando presentar datos antiguos como
actuales.

`ObservationLocation` gana `capturedAt`; SQLite v3 agrega
`location_captured_at`. Coordenadas editadas a mano cambian el origen a
`manual` y eliminan precisión/timestamp GPS. El formulario permite capturar,
marcar en mapa, editar texto/coordenadas y eliminar la ubicación.

## Multimedia y consistencia

`LocalMediaService` administra:

- `media/photos/<uuid>.<ext>` para originales privados;
- `media/audio/<uuid>.m4a` para grabaciones;
- `media/thumbnails/<uuid>.jpg` para miniaturas;
- archivos `*.part` durante escrituras atómicas.

Una foto se valida y se copia sin tocar el original. Los nuevos adjuntos son
*staged*. Después de una transacción SQLite exitosa, la UI llama
`commitStaged`; si se cancela, `discardStaged`. Un fallo de BD deja un archivo
staged recuperable y elegible para reconciliación, no una referencia rota.

`LocalMediaMaintenance` procesa `pending_file_deletions` de forma idempotente:
archivo ausente equivale a éxito; un fallo incrementa intentos y conserva el
registro. También elimina `.part` y archivos administrados que no aparecen en
`media_files`. Toda ruta pasa por un resolvedor que rechaza absolutas, `..` y
salidas del directorio privado.

`LocalVoiceRecorder` graba AAC-LC a M4A, publica tiempo transcurrido y se detiene
automáticamente a los 120 segundos. La finalización expone el adjunto staged.
`JustAudioPlayerService` resuelve el ID por `MediaService`, reproduce solo el
archivo local y traduce sus streams al contrato `PlaybackState`.

## Recuperación

Al iniciar, la composición ejecuta en orden: `retrieveLostData`, creación de un
borrador con las fotos recuperadas, confirmación staged→committed y finalmente
reconciliación/cola de borrado. Así una captura recuperable no se elimina como
huérfana. Grabaciones interrumpidas conservan solo `.part`, que se limpia.

## Cartografía offline

Fuente elegida: geoBoundaries gbOpen `DOM-ADM1-93820187`, año representado
2022, 32 unidades, fuente Natural Earth. La API oficial declara licencia
**Public Domain** y enlaza los términos de Natural Earth, que permiten uso,
modificación y redistribución. Se empaqueta el GeoJSON simplificado fijado a la
revisión `9469f09` junto con metadatos/licencia.

Un parser estricto admite `Polygon` y `MultiPolygon`. `WebMercatorProjection`
transforma lon/lat a coordenadas de lienzo e invierte la selección manual.
`OfflineProvinceMap` usa `CustomPainter` + `InteractiveViewer`, pinta límites y
marcadores y adopta colores de los tres temas. Una coordenada fuera de los
límites del conjunto muestra un mensaje y no se simula una calle/provincia.
La cartografía solo representa límites provinciales, no vías ni direcciones.

El Diario ofrece una ruta de mapa con todas las observaciones con coordenadas;
detalle muestra un marcador; formulario usa el mismo componente en modo
selector. La atribución se muestra desde el mapa mediante “Acerca de la
cartografía”, sin adelantar el perfil del Hito C.

## Pruebas

- Gateways falsos para permisos, GPS, picker, recorder y player; se prueba la
  lógica real de adaptadores/controladores, no los plugins del SO.
- Sistema de archivos temporal y SQLite/FFI real para staging, SHA, miniaturas,
  cola, reconciliación, reinicio y rollback.
- Parser/proyección/punto-en-polígono con valores literales y asset real.
- Widgets de formulario, detalle, mapa y tres temas.
- Suite completa del Hito A, análisis y APK debug.

La prueba manual Android sigue siendo obligatoria para hardware, permisos,
interrupciones del sistema y reproducción/captura real.
