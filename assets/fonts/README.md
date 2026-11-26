# Fuentes de CieloRD

Empaquetadas en el APK para funcionar sin conexión. No se descargan en tiempo de ejecución.

| Archivo | Familia (`fontFamily`) | Uso | Licencia | Origen |
|---|---|---|---|---|
| `AtkinsonHyperlegible-Regular.ttf` (400) | `AtkinsonHyperlegible` | Texto e interfaz | SIL OFL 1.1 — `OFL-AtkinsonHyperlegible.txt` | github.com/google/fonts, `ofl/atkinsonhyperlegible` |
| `AtkinsonHyperlegible-Bold.ttf` (700) | `AtkinsonHyperlegible` | Texto e interfaz | SIL OFL 1.1 | ídem |
| `SpaceGrotesk-Variable.ttf` (eje `wght` 300–700) | `SpaceGrotesk` | Títulos y cifras | SIL OFL 1.1 — `OFL-SpaceGrotesk.txt` | github.com/google/fonts, `ofl/spacegrotesk` (`SpaceGrotesk[wght].ttf`) |

- Atkinson Hyperlegible © 2020 Braille Institute of America, Inc.
- Space Grotesk © 2020 The Space Grotesk Project Authors.
- Descargadas el 22 nov 2026 sin modificar. La OFL permite incluirlas en la app. Los textos de licencia
  deben acompañar la distribución (se citan en "Acerca de" y en el listado de licencias de la entrega).

## Registro en `pubspec.yaml` (pendiente de Codex)

Hasta que estén registradas, Flutter usa la fuente del sistema como respaldo, sin errores.

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: AtkinsonHyperlegible
      fonts:
        - asset: assets/fonts/AtkinsonHyperlegible-Regular.ttf
          weight: 400
        - asset: assets/fonts/AtkinsonHyperlegible-Bold.ttf
          weight: 700
    - family: SpaceGrotesk
      fonts:
        - asset: assets/fonts/SpaceGrotesk-Variable.ttf
```

Space Grotesk es variable. `CieloTypography` fija el peso con `FontVariation('wght', …)`, además de
`fontWeight`, para que el peso sea exacto.

Para incluir las licencias en `showLicensePage`, registrar en el arranque:

```dart
LicenseRegistry.addLicense(() async* {
  for (final String f in <String>['OFL-AtkinsonHyperlegible.txt', 'OFL-SpaceGrotesk.txt']) {
    yield LicenseEntryWithLineBreaks(<String>[f.split('-').last.split('.').first],
        await rootBundle.loadString('assets/fonts/$f'));
  }
});
```

Para eso, los `.txt` deben declararse como assets.
