# Estado final de CieloRD 1.0

Fecha: 25-11-2026. Versión: `1.0.0+1`. Application ID:
`com.dmeshell.cielo_rd`.

## Resultado técnico

CieloRD queda cerrado como APK release final firmado. La identidad académica,
el icono con matrícula, el perfil inicial offline y la documentación técnica
están resueltos. No se detectaron fallos críticos ni requisitos funcionales
obligatorios ausentes.

| Validación | Resultado |
|---|---|
| `flutter pub get` | Aprobado; sin actualización indiscriminada. |
| `flutter analyze` | Aprobado; 0 incidencias. |
| `flutter test` | Aprobado; 577 aprobadas, 6 omitidas intencionalmente, 0 fallidas. |
| `flutter build apk --release --no-pub` | Aprobado. |
| `apksigner verify --verbose --print-certs` | Aprobado. |

Las seis omisiones son goldens deliberadamente deshabilitadas. Una prueba
widget preexistente emite una advertencia no fatal de tap fuera del viewport.
Las pruebas negativas de SQLite imprimen errores esperados al validar rollback,
esquema futuro y base ilegible.

## APK final

| Campo | Valor |
|---|---|
| Archivo | `CieloRD_2024-0063_v1.0.apk` |
| Ruta local | `build/app/outputs/flutter-apk/CieloRD_2024-0063_v1.0.apk` |
| Bytes | 66,484,844 |
| MiB | 63.40 |
| SHA-256 | `1F77A0762E133141E1A51BD13179FBC89E453847A46A8404A55BEB9CDA1E339B` |
| Firma | APK Signature Scheme v2; un firmante RSA 2048 |
| SHA-256 certificado | `760f14222aacc30dcd842b762dd72fc59a3ab73fc71300bd67c7be5f55b35852` |

`app-release.apk` y la copia final coinciden byte a byte. No se leyó, mostró ni
copió ningún secreto de `android/key.properties`.

## Identidad y branding

- Michael Dmeshell Sanchez Heredia.
- Matrícula `2024-0063`.
- «¡Quiero vivir!» — Nico Robin.
- Foto WebP definitiva empaquetada y copia privada visible desde la primera
  apertura.
- Adaptive icon/legacy icon con `CieloRD` y `2024-0063`.
- Splash coherente con la marca.
- Acerca de muestra `CieloRD`, versión `1.0.0 (1)` y permite editar el perfil.

## QA en emulator-5554

El candidato final se instaló desde cero con Wi-Fi y datos apagados. La primera
apertura COLD terminó en 7.213 s, sin timeout ni ANR. Se verificaron Diario,
reapertura HOT (3.614 s), navegación básica, mapa offline, Acerca de, foto,
identidad, launcher e icono y temas Día/Noche/Astrónomo. El búfer `crash` de
logcat permaneció vacío. Al finalizar se restauraron Wi-Fi, datos móviles y
tema Noche.

## Publicación pública

- Repositorio: <https://github.com/DmeshellHeredia/CieloRD>
- Commit inicial: `8cdef94` — `Initial release of CieloRD 1.0`.
- Tag/Release: <https://github.com/DmeshellHeredia/CieloRD/releases/tag/v1.0.0>
- APK: <https://github.com/DmeshellHeredia/CieloRD/releases/download/v1.0.0/CieloRD_2024-0063_v1.0.apk>

El repositorio es público, `main` es la rama predeterminada y la Release no es
borrador ni prerelease. Repositorio, README y Release respondieron HTTP 200 sin
credenciales; la descarga directa respondió HTTP 206 a una solicitud de rango.
El API público confirmó nombre, tamaño y digest exactos del APK.

## Pendientes

Quedan pendientes solo las comprobaciones que requieren teléfono físico:
cámara/galería, audio audible y límite real, GPS real y permisos, biometría,
TalkBack, selectores de documentos, falta de espacio, interrupciones,
round-trip y Borrar Todo con reinicio real. No se generan todavía QR ni PDF.

**Recomendación:** listo para descargar y para preparar QR/PDF. La evidencia
física debe completarse antes de la presentación académica definitiva.
