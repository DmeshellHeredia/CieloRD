# CieloRD — identidad final y APK académico

Fecha: 24-11-2026.

## Intención

Cerrar la identidad académica definitiva de CieloRD con el nombre Michael
Dmeshell Sanchez Heredia, matrícula 2024-0063, la frase
«¡Quiero vivir!» — Nico Robin y la foto local del proyecto. Regenerar el
icono con CieloRD + 2024-0063 y producir un APK release firmado sin cambiar
applicationId, versionName ni versionCode.

## Restricciones

- Funcionamiento completamente offline.
- El perfil continúa editable.
- Borrar Todo debe eliminar el perfil y su copia privada, sin que los datos
  personales reaparezcan en el siguiente arranque.
- No leer secretos de `android/key.properties`.
- No Git, publicación, URL ni QR.

## Enfoque elegido

Se añade una siembra idempotente de perfil al arranque. Un marcador booleano
`initial_profile_seeded.v1`, sin datos personales, vive en la raíz de soporte
fuera de `media/`, `staging/`, SQLite y preferencias. Si el marcador no
existe:

1. un perfil ya existente se conserva y solo se marca como inicializado;
2. una instalación limpia importa la foto empaquetada al almacenamiento
   administrado, guarda el perfil mediante el repositorio y confirma el
   adjunto;
3. cualquier fallo deja la app utilizable y permite reintentar en otro
   arranque.

Borrar Todo elimina base y medios, pero no el marcador booleano. Por tanto, el
perfil no se resiembra; Acerca de muestra un estado vacío accionable y Editar
perfil permite recrearlo. Desinstalar o borrar los datos de Android elimina
también el marcador y una instalación realmente limpia vuelve a sembrar.

## Foto

La ruta definitiva será `assets/profile/michael_heredia.webp`. Como esa ruta
no existía y el único retrato suministrado era `assets/profile/foto.jpeg`, se
convierte ese archivo a WebP sin recorte ni modificación visual. El asset se
declara en `pubspec.yaml` y se copia al espacio privado en la siembra.

## UI y textos

Acerca de renderiza los valores definitivos guardados. Si el perfil fue
borrado, no muestra placeholders de identidad: muestra un único estado
“Crea tu perfil para añadir tus datos” y mantiene el botón Editar perfil.
`CieloBrandLockup` usa 2024-0063 por defecto.

## Branding

El generador existente recibe `-StudentId 2024-0063` y produce iconos legacy
y adaptive en todas las densidades. Las fuentes SVG finales conservan la marca,
el nombre CieloRD y una franja legible con la matrícula. El splash conserva la
marca y no necesita matrícula.

## Verificación

- TDD para siembra, persistencia, asset offline, Acerca de y semántica tras
  Borrar Todo.
- Inspección visual del WebP y de los PNG finales.
- `flutter pub get`, `flutter analyze`, suite completa y build release.
- `apksigner`, tamaño y SHA-256.
- Instalación limpia en emulador si ADB está disponible.
