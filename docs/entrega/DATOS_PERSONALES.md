# Datos personales definitivos

| Campo | Valor | Estado |
|---|---|---|
| Nombre | Michael | Resuelto |
| Segundo nombre | Dmeshell | Resuelto; se almacena junto al nombre por el modelo actual |
| Apellidos | Sanchez Heredia | Resuelto |
| Nombre completo | Michael Dmeshell Sanchez Heredia | Resuelto |
| Matrícula | 2024-0063 | Resuelto |
| Frase | «¡Quiero vivir!» — Nico Robin | Resuelto |
| Foto fuente definitiva | `assets/profile/michael_heredia.webp` | Resuelto y disponible offline |
| Icono académico | `CieloRD` + `2024-0063` | Resuelto |

El perfil se crea una vez en una instalación limpia y sigue siendo editable.
La foto se copia al almacenamiento privado mediante derivados JPEG
preprocesados del WebP definitivo, evitando trabajo pesado durante el primer
arranque.

`Borrar Todo` elimina identidad y fotografía administrada. Solo conserva el
marcador booleano `initial_profile_seeded.v1`, que no contiene PII y evita una
resiembra automática; el usuario puede crear un perfil nuevo desde Editar
perfil.

APK final: `CieloRD_2024-0063_v1.0.apk`.

## Publicación resuelta

- Repositorio: <https://github.com/DmeshellHeredia/CieloRD>
- Release: <https://github.com/DmeshellHeredia/CieloRD/releases/tag/v1.0.0>
- APK directo: <https://github.com/DmeshellHeredia/CieloRD/releases/download/v1.0.0/CieloRD_2024-0063_v1.0.apk>
