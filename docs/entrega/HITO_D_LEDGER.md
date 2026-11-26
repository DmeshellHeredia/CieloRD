# Ledger de cierre técnico y de identidad

Fecha final: 25-11-2026.

- El icono provisional fue sustituido por arte final con `CieloRD` y
  `2024-0063`. Una prueba de píxeles detectó y evitó que la banda de matrícula
  se generara como un cuadrado.
- La identidad final es Michael Dmeshell Sanchez Heredia, matrícula 2024-0063,
  frase «¡Quiero vivir!» — Nico Robin y foto WebP empaquetada.
- La foto solicitada se obtuvo del retrato fuente existente sin recorte ni
  cambio de composición. Se generan derivados JPEG de foto y miniatura para
  que el primer arranque solo copie bytes.
- La primera implementación decodificaba WebP y codificaba dos JPEG antes de
  `runApp`; en un emulador degradado produjo un ANR. El arreglo preprocesa esos
  derivados, conserva backups JPEG y redujo el arranque COLD final a 7.213 s.
- `Borrar Todo` elimina perfil y foto. Solo sobrevive un marcador booleano sin
  PII que evita resiembra; Editar perfil permite recrearlo.
- `key.properties` nunca se leyó. La firma se validó exclusivamente sobre el
  APK con `apksigner`.
- Puerta final: analyze 0; 577 pruebas aprobadas, 6 omitidas, 0 fallidas;
  release 66,484,844 bytes; hash
  `1F77A0762E133141E1A51BD13179FBC89E453847A46A8404A55BEB9CDA1E339B`.
- QA final: instalación limpia offline, identidad/Acerca de, mapa, launcher,
  temas, reapertura y crash buffer aprobados; red y Noche restaurados.

Publicación completada en `DmeshellHeredia/CieloRD`: commit inicial `8cdef94`,
tag/Release `v1.0.0` y APK final. Las rutas públicas y la descarga de rango se
verificaron sin autenticación. QR y PDF permanecen fuera de este cierre.
