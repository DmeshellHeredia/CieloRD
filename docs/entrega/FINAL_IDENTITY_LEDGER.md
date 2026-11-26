# Ledger de identidad final

Fecha: 25-11-2026.

La identidad alimenta seeder, Acerca de, branding, documentación y APK:

- Michael Dmeshell Sanchez Heredia;
- 2024-0063;
- «¡Quiero vivir!» — Nico Robin;
- `assets/profile/michael_heredia.webp`.

La ruta WebP solicitada no existía al iniciar el cierre. Se convirtió el único
retrato disponible, `assets/profile/foto.jpeg`, sin alterar composición ni
recorte. El resultado fue inspeccionado en Acerca de y coincide con la foto
proporcionada.

Para evitar ANR en primera apertura, el generador produce además
`michael_heredia_seed.jpg` y `michael_heredia_seed_thumb.jpg`. Son derivados
verificados del WebP definitivo; el teléfono solo los copia al almacenamiento
privado. El WebP sigue empaquetado como fuente académica definitiva.

La semántica de Borrar Todo prevalece: el perfil y la foto se eliminan; solo
sobrevive un marcador booleano sin PII y nunca se resiembran datos después del
borrado. El perfil puede recrearse manualmente.
