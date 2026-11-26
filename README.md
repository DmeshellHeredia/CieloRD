# CieloRD

CieloRD es una aplicación Android Flutter, diseñada para funcionar sin
internet, que registra observaciones del cielo en República Dominicana. La
versión final es `1.0.0+1` y usa el application ID
`com.dmeshell.cielo_rd`.

## Identidad académica

- Observador: **Michael Dmeshell Sanchez Heredia**.
- Matrícula: **2024-0063**.
- Frase: **«¡Quiero vivir!» — Nico Robin**.
- El perfil y su fotografía se instalan localmente en la primera apertura y
  continúan siendo editables.
- El icono adaptativo muestra `CieloRD` y `2024-0063`.

`Borrar Todo` elimina el perfil, las observaciones y los medios administrados.
Un marcador booleano sin datos personales impide que el perfil se vuelva a
crear automáticamente después del borrado; la pantalla Perfil permite crearlo
otra vez. Desinstalar o borrar los datos de la app restaura el comportamiento
de primera instalación.

## Funciones

- CRUD SQLite de observaciones publicadas y borradores.
- Título, fecha/hora, categoría, cielo, descripción, duración y lugar.
- Coordenadas manuales o GPS foreground opcional.
- Hasta cinco fotografías y tres notas de voz de 120 segundos.
- Diario con búsqueda y filtros por fecha, categoría y lugar.
- Detalle, estadísticas y mapa provincial interactivo sin internet.
- Exportación/importación, bloqueo local opcional y Borrar Todo.
- Temas Sistema, Día, Noche y Astrónomo rojo; texto del sistema y movimiento
  reducido.

## Arquitectura y datos

Flutter con inyección por constructor, `ChangeNotifier`, modelos inmutables y
contratos `Result<T>`. `lib/app` compone servicios y rutas; `lib/core` contiene
SQLite, plataforma y concurrencia; `lib/features` agrupa funcionalidades;
`lib/design` y `lib/ui_kit` contienen el sistema visual. SQLite está en versión
4 con migraciones acumulativas, claves foráneas y revisión optimista.

Contratos públicos: [C0](docs/C0_CONTRACTS.md),
[Hito B](docs/HITO_B_CONTRACTS.md) y
[Hito C](docs/HITO_C_CONTRACTS.md).

El mapa GeoJSON, su atribución, la foto inicial y las fuentes están
empaquetados. No hay clientes HTTP ni tiles remotos en las funciones
esenciales. Cámara, galería, micrófono y ubicación se solicitan solo cuando el
usuario los usa. Los archivos administrados viven en almacenamiento privado y
se reconcilian entre estados staged, committed y limpieza pendiente.

## Desarrollo y validación

Entorno de referencia: Flutter 3.47.7 y Dart 3.13.5. Las versiones exactas de
paquetes están bloqueadas en `pubspec.lock`.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release --no-pub
```

Puerta final del 24–25 de noviembre de 2026:

- `flutter analyze`: **0 incidencias**.
- `flutter test`: **577 aprobadas, 6 omitidas intencionalmente, 0 fallidas**.
- APK release universal: **66,484,844 bytes (63.40 MiB)**.
- SHA-256:
  `1F77A0762E133141E1A51BD13179FBC89E453847A46A8404A55BEB9CDA1E339B`.
- Firma: `apksigner` aprobado, esquema v2, un firmante RSA de 2048 bits.
- Nombre de entrega: `CieloRD_2024-0063_v1.0.apk`.

El APK no se versiona dentro del repositorio. Distribución pública:

- [Repositorio](https://github.com/DmeshellHeredia/CieloRD)
- [GitHub Release CieloRD 1.0](https://github.com/DmeshellHeredia/CieloRD/releases/tag/v1.0.0)
- [Descarga directa del APK](https://github.com/DmeshellHeredia/CieloRD/releases/download/v1.0.0/CieloRD_2024-0063_v1.0.apk)

Las tres rutas se comprobaron sin autenticación; el asset público reporta el
mismo tamaño y digest SHA-256 que el candidato local.

## QA Android

El release se instaló limpio en `emulator-5554` con Wi-Fi y datos apagados. La
primera apertura COLD terminó en 7.213 s. Se verificaron Diario, mapa provincial
offline, Acerca de `1.0.0 (1)`, foto e identidad, adaptive icon, temas Día,
Noche y Astrónomo y reapertura HOT. El búfer de crashes quedó vacío. Al cerrar
el QA se restauraron Wi-Fi, datos móviles y tema Noche.

Quedan para teléfono físico: cámara y galería reales, audio audible y corte a
120 s, GPS real/aproximado/denegado, biometría, TalkBack, round-trip con
selector de documentos, interrupciones, falta de espacio y Borrar Todo con
reinicio real. Consulte
[CHECKLIST_TELEFONO_FISICO.md](docs/entrega/CHECKLIST_TELEFONO_FISICO.md).

## Licencias

Atkinson Hyperlegible y Space Grotesk se distribuyen bajo SIL OFL. La
cartografía geoBoundaries/Natural Earth y su atribución están en
`assets/maps/ATTRIBUTION.md`. Las licencias de dependencias se muestran desde
Acerca de. No se declara licencia del código propio sin decisión expresa del
autor.

Estado detallado: [docs/entrega/ESTADO.md](docs/entrega/ESTADO.md).
