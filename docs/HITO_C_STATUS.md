# CieloRD — Estado final del Hito C

Fecha de validación: 24-11-2026 (America/Santo_Domingo).

## Resultado

Hito C implementado y validado sobre A/B sin avanzar al Hito D. Perfil,
estadísticas, ajustes, Borrar Todo, exportación/importación y bloqueo local
funcionan sin red. SQLite pasa a v4. No hay repositorio Git ni se creó; no hubo
commits, push, merges ni despliegues.

Diseño: `docs/superpowers/specs/2026-11-23-hito-c-design.md`.
Contratos: `docs/HITO_C_CONTRACTS.md`.

## Funcionalidades

- **Perfil:** foto privada, nombre, apellido, matrícula y frase; edición con
  aviso de cambios sin guardar; al cambiar la foto se elimina la anterior; lo que
  falta se muestra como "pendiente".
- **Acerca de:** perfil, versión, atribución cartográfica y licencias.
- **Estadísticas:** total, mes actual, categoría, mes, hora, provincia, lugar y
  duración, agregadas en SQLite; sin borradores; `CustomPainter`, cifras y textos
  visibles y tabla equivalente.
- **Ajustes:** Sistema/Día/Noche/Astrónomo persistentes, movimiento reducido,
  bloqueo, datos e información.
- **Borrar Todo:** conteos reales, casilla obligatoria, detención de audio, puerta
  de escrituras, verificación en disco, reintento y recuperación tras muerte del
  proceso.
- **Exportar:** JSON y ZIP con manifiesto y SHA-256, por el selector del sistema.
- **Importar:** inspección completa, vista previa, fusión determinista, atómica.
- **Bloqueo:** `local_auth`, opcional, sin PIN propio; oculta Recientes
  (Android 13+).

## Migraciones

v3 → v4: recrea `app_settings` para admitir `theme = 'system'` y copia la fila.
Probada con FFI (3→4 con datos) y en el emulador (instalación sobre el Hito B).

## Dependencias

Añadidas: `local_auth 3.0.2`, `local_auth_android 2.3.0` (y sus transitivas
`local_auth_darwin 2.0.5`, `local_auth_platform_interface 1.1.0`,
`local_auth_windows 2.0.2`). Desarrollo: `archive 4.7.1`, ya presente en el lock.
Ningún paquete existente cambió de versión.

## Validación automatizada

| Comando | Resultado |
|---|---|
| Línea base `flutter analyze` / `flutter test` | 0 incidencias / 379 aprobadas, 6 omitidas |
| `flutter pub get` | Aprobado |
| `flutter analyze` | `No issues found!` |
| `flutter test` | **564 aprobadas, 6 omitidas, 0 fallidas** |
| `flutter build apk --debug --no-pub` | Aprobado (185,9 s) |

185 pruebas nuevas. Las 6 omisiones son las capturas golden intencionales de A/B.
De A/B solo cambiaron dos aserciones que fijaban la versión `3` del esquema; ahora
usan `DatabaseMigrations.currentVersion`.

Comprobación de las propias pruebas: 25 mutaciones del código (quitar una
validación, un borrado, un bloqueo…). 22 se detectaron a la primera; las otras 3
revelaron pruebas flojas que se reforzaron. 25/25 detectadas al final.

## APK

- `build/app/outputs/flutter-apk/app-debug.apk`
- 243 821 889 bytes
- SHA-256 `D2C520E521D3B41C3DA7D017474172BA2B32DF7E5C2943408AE6BDD1492BF5FE`

## Verificación en emulador (Pixel_7_2, API 34, Wi-Fi y datos apagados)

El emulador dejó de estar conectado durante una compilación (poca RAM) y se
reinició el mismo AVD. Los puntos marcados con (†) se probaron con una compilación
previa que solo difiere en tres textos posteriores a importar; el resto, con el
APK final.

- Instalación sobre el Hito B y migración a v4. `ALLOW_BACKUP` desapareció de los
  flags y `bmgr backupnow` responde `Backup is not allowed`.
- Temas, Sistema claro/oscuro, movimiento reducido y persistencia. (†)
- Observación con GPS simulado, nota de voz y dos fotos de galería; borrador;
  perfil; cambio de foto con eliminación inmediata de la anterior. (†)
- Estadísticas: borrador excluido, provincia La Vega correcta. (†)
- Exportación ZIP y JSON a Descargas; ZIP abierto con Python: hashes del manifiesto
  correctos y bytes iguales a los privados. (†)
- Bloqueo: sin PIN, cancelado, PIN erróneo, activado, vuelta de segundo plano,
  arranque en frío, "atrás" sin saltarlo y Recientes en blanco. (†) PIN retirado
  con el bloqueo activo: salida explícita.
- **Round-trip:** exportar → Borrar Todo → importar: 2 observaciones, 4 adjuntos y
  perfil; cada adjunto idéntico byte a byte. (†) Repetido con el APK final.
- Copia con `../../databases/cielo_rd.db`: rechazada sin cambios. (†)
- Conflicto: la copia entra con ID derivado y la local no cambia. Reimportar no
  añade nada.
- **Borrar Todo:** quedan solo una base v4 vacía y `files/profileInstalled` (lo
  crea AndroidX, sin datos). Desaparecen medios, miniaturas, perfil, preferencias,
  bloqueo, las copias que `image_picker` deja en `cache/` y sus SharedPreferences.
  Exportados y originales, intactos. Tras matar y reabrir sigue vacío.
- Borrado interrumpido (marcador y proceso muerto): terminado al arrancar. (†)
- Texto al 200 % en Ajustes, Estadísticas y Acerca de.
- Logcat sin excepciones de Flutter ni ANR.

Al terminar se quitaron PIN, permisos y archivos de prueba y se restauró la red,
la rotación y la escala. La app quedó instalada y vacía.

## Limitaciones

- El borrado elimina y verifica archivos; no es forense.
- Las copias no van cifradas y el bloqueo no cifra nada; la interfaz lo dice.
- El JSON no se puede importar (no contiene adjuntos).
- Copias de hasta 2 GiB, 128 MiB por adjunto, 20 000 entradas; fotos de hasta
  64 MP. Exportar e importar necesitan espacio temporal similar al de la copia.
- El bloqueo salta también al volver de la cámara, la galería o el selector. El
  formulario abierto se conserva.
- Recientes se oculta solo desde Android 13; las capturas no se bloquean.
- Si Android mata la app con el selector de foto del perfil abierto, la foto se
  recupera como borrador (mecanismo del Hito B).
- En Astrónomo, la barra de estado y los diálogos del sistema no son rojos.
- Nombre visible (`cielo_rd`) e icono siguen siendo los de Flutter.
- El atenuador no estaba contemplado y no se añadió.

## Pendientes físicos

No se declaran aprobados:

- huella y rostro reales, y bloqueos temporales por intentos;
- cámara real para la foto del perfil y fotos grandes;
- Android 7–12 (el tema AppCompat y el traspaso entre teléfonos);
- exportar a Drive, SD o USB y quedarse sin espacio de verdad;
- copias grandes (cientos de MB) y su tiempo en un teléfono modesto;
- muerte real del proceso a mitad de importar o borrar;
- TalkBack y audición de las notas importadas.
