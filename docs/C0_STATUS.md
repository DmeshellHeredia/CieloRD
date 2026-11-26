# CieloRD — C0 y Hito A validados

Fecha de cierre: 22-11-2026, República Dominicana.

**Estado recomendado: aprobar C0/C1/U2 (Hito A) y detenerse antes del Hito B.**
El núcleo, SQLite, CRUD, Diario, registro rápido, formulario completo,
navegación y accesibilidad automatizada compilan y pasan la suite. Queda como
verificación manual pendiente instalar el APK en un dispositivo/emulador Android,
porque durante este cierre no había ninguno conectado.

## Alcance comprobado

- Dominio inmutable, `AppFailure`, `Result<T>`, validaciones, borradores y
  publicaciones.
- Contratos con inyección por constructor y `ChangeNotifier` en controladores.
- SQLite real mediante `sqflite`, esquema v2, migraciones 0→1 y 1→2, claves
  foráneas activas y rechazo de versiones futuras sin pérdida de datos.
- CRUD con concurrencia optimista por revisión, borradores, filtros AND,
  conteos exactos, búsqueda normalizada sin acentos, paginación y orden estable.
- Diario con refresco después de crear, editar o borrar; rutas
  Diario→Detalle→Editar; registro rápido y formulario completo; protección de
  cambios sin guardar y mensajes estables para fallos.
- Composición de producción en `main.dart` con `SqliteObservationStore`. Las
  implementaciones en memoria quedan limitadas a vistas previas y pruebas.
- Fuentes y recursos empaquetados para uso offline. Ninguna función esencial
  validada depende de internet.

No se implementó ni adelantó Hito B: GPS, fotografías, audio o mapa offline.

## Correcciones realizadas durante la auditoría

- Se corrigieron cuatro pruebas antiguas del Diario: una recarga ejecuta una
  lista y dos conteos, y un fallo de conteo no invalida una lista válida.
- El repositorio de prueba ahora permite programar fallos específicos de
  `list` y `count`, sin depender del orden interno de llamadas concurrentes.
- El resumen paginado espera el conteo exacto (`12 observaciones`) en vez de
  inferir `5+` a partir de la primera página.
- Se eliminó un import sin uso y se corrigieron 12 lints de llaves, sin cambios
  de comportamiento productivo.
- Se añadieron los archivos que no llegó a crear Claude:
  `test/widgets/observations/app_flow_test.dart` y
  `test/widgets/accessibility/form_accessibility_test.dart`.
- `C0_CONTRACTS.md` ahora documenta la firma `count`, SQLite v2 y la migración
  de búsqueda normalizada; no se cambió ninguna firma pública de código.

## Evidencia de persistencia real

La prueba funcional nueva usa SQLite/FFI real y verifica en una misma historia:

1. creación y lectura de una observación publicada;
2. edición con incremento de revisión 1→2;
3. cierre y reapertura física de la base;
4. recuperación de la edición;
5. filtro combinado por estado, categoría, lugar y búsqueda sin acentos;
6. conteo exacto;
7. borrado con revisión vigente;
8. segunda reapertura y resultado `notFound`.

Las pruebas existentes también cubren migración v1→v2 con conservación de datos,
rollback, claves foráneas, medios, conflictos, cursores y borradores.

## Resultado de comandos

| Comando | Resultado final |
|---|---|
| `git status --short --branch` | No es un repositorio Git; no se inicializó ni se ejecutaron operaciones Git |
| `flutter pub get` | Exit 0; dependencias resueltas, sin actualización indiscriminada; 10 versiones más nuevas incompatibles con las restricciones actuales fueron solo informadas |
| `flutter analyze` | Exit 0: `No issues found!` |
| `flutter test --reporter expanded` | Exit 0: 356 aprobadas, 6 omitidas intencionalmente (capturas golden bajo `CIELO_SCREENSHOTS`) |
| `flutter build apk --debug` | Exit 0: APK debug generado |
| `flutter devices` | Windows, Chrome y Edge; ningún Android conectado |
| `flutter doctor -v` | Toolchain Android correcto; una incidencia de red al comprobar pub.dev |

Durante la línea base, la suite tenía 346 aprobadas, 6 omitidas y 4 fallidas;
las cuatro fallas quedaron corregidas y se agregaron seis pruebas nuevas.

## Entorno verificado

| Elemento | Versión / estado real |
|---|---|
| Flutter | 3.47.7 stable, revisión `abaf9c5237` |
| Dart / DevTools | 3.13.5 / 2.60.0 |
| Android SDK | 36.0.0; plataforma 37.0; Build Tools 36.0.0; licencias aceptadas |
| Java usado por Flutter | JBR OpenJDK 25.0.3 de Android Studio |
| Java de `java -version` | Oracle 22.0.2 |
| Gradle wrapper | 9.3.1; launcher/daemon sobre JDK 17.0.12 |

APK: `build/app/outputs/flutter-apk/app-debug.apk`, 166,010,392 bytes.
SHA-256: `657FE0A4300DB6997EB3C181551A80626B554AAD4680CFDD6A1BF2EBBAC69953`.

## Advertencias y pendientes

- La suite U0 emite una advertencia no fatal en
  `test/widgets/ui_kit/dialogs_and_bars_test.dart:118`: intenta tocar el texto
  de confirmación de “Borrar todo” fuera del viewport 360×780. La prueba pasa.
  Se reporta sin modificar archivos U0 de Claude.
- Gradle/JBR advierte que `java.lang.System::load` es una API restringida y
  podrá requerir `--enable-native-access=ALL-UNNAMED` en un Java futuro. No
  afecta la compilación actual y no se cambió Android innecesariamente.
- `flutter doctor -v` encontró un error criptográfico de red al consultar
  pub.dev. El proyecto ya resolvió dependencias, analiza, prueba y compila; el
  funcionamiento esencial permanece offline.
- Falta una prueba manual en Android real/emulador de instalación, arranque,
  cierre forzado y reapertura. La prueba SQLite/FFI y el APK no sustituyen esa
  comprobación de plataforma.

## Archivos de esta auditoría

Creados:

- `test/widgets/observations/app_flow_test.dart`
- `test/widgets/accessibility/form_accessibility_test.dart`

Modificados:

- `lib/features/observations/presentation/preview/in_memory_observation_repository.dart`
- `test/widgets/observations/diary_view_model_test.dart`
- `test/widgets/observations/diary_screen_test.dart`
- `test/widgets/observations/form_test.dart`
- `docs/C0_CONTRACTS.md`
- `docs/C0_STATUS.md`

No se modificaron configuraciones Android, dependencias, contratos de código ni
archivos de presentación U0. No hubo commits, push, merges ni despliegues.
