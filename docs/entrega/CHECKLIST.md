# Checklist de cierre — CieloRD 1.0

## Automatización

- [x] `flutter pub get` con lockfile respetado.
- [x] `flutter analyze`: 0 incidencias.
- [x] `flutter test`: 577 aprobadas, 6 omitidas, 0 fallidas.
- [x] APK release universal compilado.
- [x] APK final copiado como `CieloRD_2024-0063_v1.0.apk`.
- [x] Tamaño y SHA-256 registrados.
- [x] Firma release verificada con `apksigner`.
- [x] Icono adaptativo, legado, monocromo y splash validados.
- [x] Nombre, matrícula, frase y foto definitivos empaquetados.
- [x] Borrar Todo y semántica de perfil posterior cubiertos por pruebas.

## Emulador release limpio

- [x] Instalación limpia de `com.dmeshell.cielo_rd` versión `1.0.0 (1)`.
- [x] Primera apertura con Wi-Fi y datos apagados: 7.213 s COLD.
- [x] Diario y navegación básica.
- [x] Mapa provincial offline renderizado sin red.
- [x] Acerca de muestra foto, nombre, matrícula, frase y versión correctos.
- [x] Temas Día, Noche y Astrónomo inspeccionados.
- [x] Reapertura HOT aprobada en 3.614 s.
- [x] Adaptive icon visible con `CieloRD` y `2024-0063`.
- [x] Búfer de crashes vacío; sin `FATAL EXCEPTION`.
- [x] Wi-Fi, datos y tema Noche restaurados.

## Publicación

- [ ] Repositorio público GitHub creado y verificado.
- [ ] Rama `main` publicada sin secretos.
- [ ] GitHub Release `v1.0.0` creada.
- [ ] APK final adjunto y descarga pública verificada.
- [ ] README público renderizado correctamente.

## Teléfono físico

Pendiente únicamente la matriz documentada en
`CHECKLIST_TELEFONO_FISICO.md`: cámara/galería, audio audible, GPS real,
biometría, TalkBack, selectores externos, falta de espacio, interrupciones,
round-trip completo y Borrar Todo con reinicio real.

No generar QR ni PDF hasta verificar la URL pública directa del APK.
