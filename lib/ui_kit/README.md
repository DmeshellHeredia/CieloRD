# Sistema de diseño y componentes de CieloRD (Fase U0)

Importaciones: `package:cielo_rd/design/design.dart` y `package:cielo_rd/ui_kit/ui_kit.dart`.
Textos: `package:cielo_rd/l10n/cielo_strings.dart`. Formatos: `package:cielo_rd/l10n/cielo_format.dart`.

Los componentes **no dependen** de SQLite, de los repositorios, de los controladores ni de plugins.
Reciben valores ya preparados y callbacks.

## Temas

| API | Descripción |
|---|---|
| `CieloTheme.build(CieloThemeVariant)` / `.night()` `.day()` `.astro()` | `ThemeData` completo, M3 |
| `CieloTheme.defaultVariant` | `night` |
| `CieloColors.of(context)` | `ThemeExtension` con los tokens semánticos y las tintas de categoría |
| `CieloColors.mediaFilter` | Filtro rojo monocromo para fotos y mapa en modo astrónomo (`null` en los demás temas) |
| `CieloSpace` · `CieloRadius` · `CieloSize` · `CieloMotion` | Espaciado de 4 pt, radios por jerarquía, áreas táctiles de 48/56/64 y duraciones |
| `CieloMotion.resolve(context, d)` | Devuelve `Duration.zero` con movimiento reducido |
| `CieloTypography.tabular(style)` | Cifras de ancho fijo (horas, coordenadas) |
| `contrastRatio(a, b)`, `isRedOnly(c)` | Utilidades verificadas en pruebas |

Recomendación para `MaterialApp`: `themeAnimationDuration: Duration.zero`. La interpolación entre
Noche y Astrónomo mostraría colores intermedios que no son rojos. Para un ajuste propio de
"movimiento reducido", envolver la app en `MediaQuery(disableAnimations: true)`.

## Componentes

| Componente | Propiedades públicas |
|---|---|
| `ObservationCard` | `title`, `category: CategoryVisual`, `whenLabel`, `semanticWhen?`, `placeLabel?`, `isDraft`, `photoCount`, `audioCount`, `location: ObservationCardLocation {none, gps, manual}`, `thumbnail: Widget?`, `heroTag?`, `onTap?`, `onLongPress?` |
| `CategoryGrid` | `selectedCode: String?`, `onSelected(CategoryVisual)`, `categories` |
| `CategoryChip` | `category`, `selected`, `onSelected(bool)?`, `multiSelect = true` |
| `SkyConditionSelector` | `selectedCode: String?`, `onChanged(String?)`, `options`, `allowDeselect = true` |
| `DirectionSelector` | `selectedCode: String?`, `onChanged(String?)` (el centro quita la dirección) |
| `DurationPicker` | `value: Duration?`, `onChanged(Duration?)`, `presets`, `maxMinutes = 999` |
| `CieloChoiceChip` | `label`, `selected`, `onSelected(bool)?`, `leading?`, `semanticLabel?`, `mutuallyExclusive = true` |
| `CieloBadge` | `label`, `tone: CieloTone`, `icon?`, `semanticLabel?` |
| `CieloBanner` | `message`, `title?`, `tone`, `icon?`, `actionLabel?`/`onAction?`, `secondaryActionLabel?`/`onSecondaryAction?`, `onDismiss?` (región viva) |
| `CieloEmptyState` | `title`, `message`, `glyph`, `icon?`, `actionLabel?`/`onAction?`, `actionIcon?`, `secondaryActionLabel?`/`onSecondaryAction?` |
| `CieloErrorState` | `message`, `title`, `onRetry?`, `retryLabel`, acción secundaria opcional |
| `CieloSkeletonList` | `count = 3`, `semanticLabel` |
| `showCieloConfirmDialog(...)` → `Future<bool>` | `title`, `message`, `confirmLabel`, `cancelLabel`, `destructive` |
| `showCieloDangerConfirmDialog(...)` → `Future<bool>` | `title`, `message`, `confirmLabel`, `consequences: List<String>`, `footnote?`, `acknowledgement`, `cancelLabel` |
| `showUnsavedChangesSheet(context)` → `Future<UnsavedChangesDecision>` | `saveDraft` · `discard` · `keepEditing` (cerrar la hoja = seguir editando) |
| `CieloActionBar` | `primaryLabel`, `onPrimary?`, `primaryIcon?`, `secondaryLabel?`/`onSecondary?`, `busy`, `busyLabel`, `destructive`, `prominent` (64 dp), `leftHanded` |
| `CieloSectionHeader` | `title`, `subtitle?`, `trailing?` |
| `CieloSearchField` (U1) | `value`, `onChanged`, `onSubmitted?`, `hint`, `label`. Controlado; 56 dp; botón para borrar |
| `CieloFilterButton` (U1) | `activeCount`, `onPressed`. Muestra "Filtros (n)" y cambia de estilo |
| `CieloRemovableChip` (U1) | `label`, `onRemove`, `icon?`. TalkBack: "Quitar filtro …" |
| `CieloGlyphIcon` / `CieloGlyphPainter` | `glyph: CieloGlyph`, `size`, `color?`, `semanticLabel?` (sin etiqueta, el glifo es decorativo) |
| `CieloBrandLockup` / `CieloBrandMark` | `studentId` (por defecto `2024-0063`), `markSize` |

`CategoryVisual`, `SkyConditionVisual` y `DirectionVisual` son **tablas de apariencia** (etiqueta,
glifo o icono, tinta) indexadas por los códigos de Codex: `ObservationCategory.name`,
`SkyCondition.code` y `CardinalDirection.code`. No son modelos. Un código desconocido se muestra como
"Otro" o "No sé".

## Integración prevista con los contratos de Codex

La pantalla, en `features/*/presentation`, adapta el modelo al componente:

```dart
ObservationCard(
  title: obs.title,
  category: CategoryVisual.fromCode(obs.category.name),
  whenLabel: CieloFormat.dateTime(obs.observedAtLocal),
  semanticWhen: CieloFormat.dateLong(obs.observedAtLocal),
  placeLabel: obs.placeName,
  isDraft: obs.status == ObservationStatus.draft,
  photoCount: obs.photoCount, audioCount: obs.audioCount,
  location: /* LocationSource.gps → gps, manual → manual, text/null → none */,
  onTap: () => /* navegación de go_router */,
);
```

## Galería aislada

```
flutter run -t lib/features/design_gallery/presentation/main_design_gallery.dart
```

Permite cambiar el tema, el tamaño de texto (100/130/200 %), el movimiento reducido y la mano
dominante. No se importa desde `main.dart`.
