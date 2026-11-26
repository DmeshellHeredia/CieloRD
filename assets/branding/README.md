# Marca final de CieloRD

Todos los recursos de esta carpeta son **diseño original del proyecto**. No usan imágenes, iconos ni
datos de terceros.

| Archivo | Qué es |
|---|---|
| `cielord_mark.svg` | Marca: media luna sobre la silueta de la cordillera Central y un destello. Retícula de 24. |
| `icon_foreground_final.svg` | Primer plano final del icono adaptativo (432 × 432 px = 108 dp), con `CieloRD` y `2024-0063`. |
| `icon_legacy_final.svg` | Composición final para launchers anteriores a Android 8, con fondo Abismo. |

La misma geometría está dibujada en código en `CieloGlyphPainter` (`CieloGlyph.brandMark`), dentro de
`lib/ui_kit/glyphs/cielo_glyph.dart`. Así la app puede mostrar la marca, por ejemplo en "Acerca de" o
en la pantalla de inicio, sin depender de un lector de SVG.

## Generación de recursos Android

El generador produce los PNG legado y adaptativos en todas las densidades Android:

```powershell
.\tool\generate_android_branding.ps1 -StudentId '2024-0063'
```

El script valida el formato de la matrícula y mantiene las capas adaptativas,
monocromas y el splash ya conectados en `android/app/src/main/res`.

En el icono legado de 48 px la matrícula conserva su presencia académica, aunque
la legibilidad plena se obtiene en densidades superiores. La etiqueta del
lanzador es `CieloRD`.

Colores: Abismo `#0A0F1F` (fondo), Ámbar Lucero `#F4B860` (marca), `#E8ECF8` (nombre), `#123F3C` /
`#A6F0E7` (franja de la matrícula). Todos salen de `CieloColors.night`.
