# CieloRD — Diseño técnico del Hito C

Fecha: 23-11-2026. Ejecución autónoma autorizada por el responsable. Base: Hito B
aprobado (analyze 0, 379 pruebas aprobadas, 6 omitidas).

## Decisiones

1. **Sin red y con dependencias mínimas.** Solo se añaden `local_auth` (exigido)
   y `local_auth_android` (textos en español del diálogo del sistema), más
   `archive` como dependencia *de desarrollo* (ya estaba en el lock) para
   verificar el ZIP con una implementación independiente.
2. **SQLite v4.** Recrea `app_settings` para admitir `theme = 'system'`,
   conservando la fila existente. Nada más cambia.
3. **`WriteGate`.** Puerta única de escrituras. Las escrituras normales la
   cruzan en paralelo; exportar, importar y borrar la toman en exclusiva:
   rechazan escrituras nuevas (`FailureCode.busy`) y esperan las que ya estaban
   en curso.
4. **Borrar Todo** elimina el archivo SQLite completo (no fila por fila), los
   directorios `media/` y `staging/`, la caché privada y las preferencias de
   plugins. Un marcador durable (`erase_all.pending`) se escribe antes de
   empezar y se quita solo tras verificar: si el proceso muere a mitad, el
   siguiente arranque termina el borrado antes de abrir nada.
5. **ZIP propio y estricto.** Lector con lista blanca de nombres, directorio
   central verificado y descompresión acotada por el tamaño declarado. Un
   descompresor genérico normaliza rutas y descomprime sin tope, justo lo que
   hay que rechazar.
6. **Selector del sistema (SAF) por un canal Kotlin mínimo.** `ACTION_CREATE_DOCUMENT`
   y `ACTION_OPEN_DOCUMENT`: sin permisos de almacenamiento, copia por flujo y
   con tope de bytes.
7. **Bloqueo local** como capa visual sobre el `Navigator`: al volver de segundo
   plano se exige autenticación sin destruir el formulario que hubiera debajo.
   No es cifrado y la interfaz lo dice.

## Estrategia de importación (exacta)

Las observaciones se procesan en orden ascendente de ID.

| Caso | Acción |
|---|---|
| El ID no existe en el teléfono | Se inserta con el mismo ID, fechas y revisión |
| El ID existe y el contenido es idéntico | Se omite |
| El ID existe y el contenido difiere | Se inserta como copia; la local no se toca |
| La copia determinista ya existe | Se omite (reimportar es idempotente) |

- *Contenido* = estado, todos los campos y, por adjunto en orden, tipo, duración
  y SHA-256. No cuentan IDs de adjuntos, `createdAt`, `updatedAt` ni `revision`.
- ID de copia = UUID derivado de `SHA-256("cielord-import-copy|id|huella")`.
- ID de adjunto: se conserva si está libre; si no, derivado de
  `SHA-256("cielord-import-media|idDestino|idAdjunto")`.
- Perfil: se importa solo si el teléfono no tiene perfil; nunca lo sobrescribe.
- Preferencias y bloqueo no forman parte de la copia.

Atomicidad: inspección completa → extracción y miniaturas en `staging/` → mover a
`media/` → una única transacción SQLite. Si algo falla antes del commit se quitan
los archivos movidos; si el proceso muere, la reconciliación del Hito B elimina
los huérfanos al arrancar. Dentro de la transacción se retiran de
`pending_file_deletions` las rutas recuperadas, para que la cola no borre un
archivo recién importado.

## Formato de copia v1

```
manifest.json   format, schemaVersion, createdAt, appVersion, databaseVersion,
                counts, data{path,byteSize,sha256}, files[], missingMedia[]
data.json       schemaVersion, observations[], media[], profile|null
media/photos/<id>.jpg
media/audio/<id>.m4a
```

Límites: 2 GiB en total, 128 MiB por adjunto, 32 MiB de `data.json`, 16 MiB de
manifiesto y 20 000 entradas; fotos de hasta 64 megapíxeles. La exportación
aplica los mismos límites para no crear copias que luego no se puedan importar.
Las miniaturas se regeneran. El JSON simple es solo de lectura externa: no se
importa porque no contiene adjuntos.

## Fuera de alcance

PDF, QR, publicación y Hito D. El atenuador no estaba contemplado en contratos,
esquema ni interfaz, por lo que no se añade. `AppSettings.textScale` se conserva
sin interfaz: manda la escala del sistema.
