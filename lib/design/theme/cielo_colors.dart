import 'package:flutter/material.dart';

/// Variantes visuales de CieloRD. Noche es la predeterminada.
enum CieloThemeVariant {
  night,
  day,
  astro;

  bool get isDark => this != CieloThemeVariant.day;
}

/// Tokens semánticos de color. Los widgets leen colores de aquí o del
/// `ColorScheme`, nunca valores hexadecimales sueltos.
///
/// Reglas verificadas por pruebas (`test/widgets/design/contrast_test.dart`):
/// * texto ≥ 4.5:1 sobre las superficies donde se usa;
/// * bordes de controles y glifos ≥ 3:1;
/// * en [CieloThemeVariant.astro] todos los colores tienen verde y azul en 0.
@immutable
class CieloColors extends ThemeExtension<CieloColors> {
  const CieloColors({
    required this.variant,
    required this.background,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.outline,
    required this.outlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.success,
    required this.warning,
    required this.categoryAstronomy,
    required this.categoryAtmospheric,
    required this.categoryBirds,
    required this.categoryArtificial,
    required this.categoryOther,
    required this.scrim,
  });

  final CieloThemeVariant variant;

  /// Fondo de pantalla.
  final Color background;

  /// Tarjetas y barras.
  final Color surface1;

  /// Campos, contenedores secundarios.
  final Color surface2;

  /// Elementos elevados (snackbar, menús).
  final Color surface3;

  /// Separadores decorativos (no identifican controles).
  final Color outline;

  /// Bordes que delimitan controles: ≥ 3:1 contra superficies.
  final Color outlineStrong;

  final Color textPrimary;
  final Color textSecondary;

  /// Turquesa Samaná (Noche/Día) — acción principal.
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Ámbar Lucero — borradores, avisos y realces.
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;

  final Color success;
  final Color warning;

  final Color categoryAstronomy;
  final Color categoryAtmospheric;
  final Color categoryBirds;
  final Color categoryArtificial;
  final Color categoryOther;

  final Color scrim;

  bool get isAstro => variant == CieloThemeVariant.astro;

  /// Fondo y texto de los botones rellenos. En modo astrónomo un bloque rojo
  /// brillante deslumbra y rompe la adaptación a la oscuridad, así que la
  /// acción se marca con fondo oscuro, texto rojo y borde de 2 dp.
  Color get filledBackground => isAstro ? primaryContainer : primary;
  Color get onFilled => isAstro ? onPrimaryContainer : onPrimary;
  Color get dangerFilledBackground => isAstro ? dangerContainer : danger;
  Color get onDangerFilled => isAstro ? onDangerContainer : onDanger;

  /// Filtro para fotos y mapas: en modo astrónomo convierte la imagen a
  /// rojo monocromo; en los demás temas no se aplica filtro.
  ColorFilter? get mediaFilter => isAstro ? redMonochromeFilter : null;

  static const ColorFilter redMonochromeFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  /// Todos los colores, para verificaciones y para la galería de diseño.
  Map<String, Color> get tokens => <String, Color>{
        'background': background,
        'surface1': surface1,
        'surface2': surface2,
        'surface3': surface3,
        'outline': outline,
        'outlineStrong': outlineStrong,
        'textPrimary': textPrimary,
        'textSecondary': textSecondary,
        'primary': primary,
        'onPrimary': onPrimary,
        'primaryContainer': primaryContainer,
        'onPrimaryContainer': onPrimaryContainer,
        'accent': accent,
        'onAccent': onAccent,
        'accentContainer': accentContainer,
        'onAccentContainer': onAccentContainer,
        'danger': danger,
        'onDanger': onDanger,
        'dangerContainer': dangerContainer,
        'onDangerContainer': onDangerContainer,
        'success': success,
        'warning': warning,
        'categoryAstronomy': categoryAstronomy,
        'categoryAtmospheric': categoryAtmospheric,
        'categoryBirds': categoryBirds,
        'categoryArtificial': categoryArtificial,
        'categoryOther': categoryOther,
        'scrim': scrim,
      };

  /// Noche — índigo profundo "Abismo", turquesa Samaná y ámbar lucero.
  static const CieloColors night = CieloColors(
    variant: CieloThemeVariant.night,
    background: Color(0xFF0A0F1F),
    surface1: Color(0xFF121933),
    surface2: Color(0xFF1B2445),
    surface3: Color(0xFF253058),
    outline: Color(0xFF2E3A63),
    outlineStrong: Color(0xFF7684B4),
    textPrimary: Color(0xFFE8ECF8),
    textSecondary: Color(0xFFA9B3D1),
    primary: Color(0xFF5ED3C7),
    onPrimary: Color(0xFF04211E),
    primaryContainer: Color(0xFF123F3C),
    onPrimaryContainer: Color(0xFFA6F0E7),
    accent: Color(0xFFF4B860),
    onAccent: Color(0xFF2A1A00),
    accentContainer: Color(0xFF3D2C0E),
    onAccentContainer: Color(0xFFFFD99C),
    danger: Color(0xFFFF8A80),
    onDanger: Color(0xFF2A0505),
    dangerContainer: Color(0xFF4A1616),
    onDangerContainer: Color(0xFFFFD2CC),
    success: Color(0xFF6FD39A),
    warning: Color(0xFFF2C14E),
    categoryAstronomy: Color(0xFFC7B8FF),
    categoryAtmospheric: Color(0xFF7FD4F0),
    categoryBirds: Color(0xFF9BDC8C),
    categoryArtificial: Color(0xFFFFB38A),
    categoryOther: Color(0xFFB9C2DD),
    scrim: Color(0x99000000),
  );

  /// Día — cielo de mañana, mismos roles con tonos profundos para contraste.
  static const CieloColors day = CieloColors(
    variant: CieloThemeVariant.day,
    background: Color(0xFFF4F6FB),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFEBEFF8),
    surface3: Color(0xFFDEE4F2),
    outline: Color(0xFFCBD3E6),
    outlineStrong: Color(0xFF6E7894),
    textPrimary: Color(0xFF0E1530),
    textSecondary: Color(0xFF46506E),
    primary: Color(0xFF0A6B66),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCDEFEB),
    onPrimaryContainer: Color(0xFF00312E),
    accent: Color(0xFF8F5200),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFFE3B8),
    onAccentContainer: Color(0xFF3A2200),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    dangerContainer: Color(0xFFFCDAD6),
    onDangerContainer: Color(0xFF410E0B),
    success: Color(0xFF1E7A4C),
    warning: Color(0xFF8F5200),
    categoryAstronomy: Color(0xFF5B4BB7),
    categoryAtmospheric: Color(0xFF0B6A8F),
    categoryBirds: Color(0xFF2F7A2A),
    categoryArtificial: Color(0xFFA44A12),
    categoryOther: Color(0xFF55607E),
    scrim: Color(0x660E1530),
  );

  /// Astrónomo — solo canal rojo para preservar la adaptación a la oscuridad.
  /// La jerarquía se expresa con peso y tamaño, no atenuando el texto, porque
  /// un rojo más tenue que #F20000 ya no cumple 4.5:1.
  static const CieloColors astro = CieloColors(
    variant: CieloThemeVariant.astro,
    background: Color(0xFF000000),
    surface1: Color(0xFF0D0000),
    surface2: Color(0xFF160000),
    surface3: Color(0xFF220000),
    outline: Color(0xFF3A0000),
    outlineStrong: Color(0xFFC40000),
    textPrimary: Color(0xFFFF0000),
    textSecondary: Color(0xFFF20000),
    primary: Color(0xFFF20000),
    onPrimary: Color(0xFF000000),
    primaryContainer: Color(0xFF2A0000),
    onPrimaryContainer: Color(0xFFFF0000),
    accent: Color(0xFFFF0000),
    onAccent: Color(0xFF000000),
    accentContainer: Color(0xFF2A0000),
    onAccentContainer: Color(0xFFFF0000),
    danger: Color(0xFFFF0000),
    onDanger: Color(0xFF000000),
    dangerContainer: Color(0xFF2A0000),
    onDangerContainer: Color(0xFFFF0000),
    success: Color(0xFFF20000),
    warning: Color(0xFFFF0000),
    categoryAstronomy: Color(0xFFF20000),
    categoryAtmospheric: Color(0xFFF20000),
    categoryBirds: Color(0xFFF20000),
    categoryArtificial: Color(0xFFF20000),
    categoryOther: Color(0xFFF20000),
    scrim: Color(0xB3000000),
  );

  static CieloColors forVariant(CieloThemeVariant variant) => switch (variant) {
        CieloThemeVariant.night => night,
        CieloThemeVariant.day => day,
        CieloThemeVariant.astro => astro,
      };

  /// Lee los tokens del tema actual. Si el tema no los define (por ejemplo,
  /// en una prueba aislada), devuelve Noche.
  static CieloColors of(BuildContext context) =>
      Theme.of(context).extension<CieloColors>() ?? night;

  @override
  CieloColors copyWith({
    CieloThemeVariant? variant,
    Color? background,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? outline,
    Color? outlineStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? onAccentContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? success,
    Color? warning,
    Color? categoryAstronomy,
    Color? categoryAtmospheric,
    Color? categoryBirds,
    Color? categoryArtificial,
    Color? categoryOther,
    Color? scrim,
  }) {
    return CieloColors(
      variant: variant ?? this.variant,
      background: background ?? this.background,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      outline: outline ?? this.outline,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentContainer: accentContainer ?? this.accentContainer,
      onAccentContainer: onAccentContainer ?? this.onAccentContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      categoryAstronomy: categoryAstronomy ?? this.categoryAstronomy,
      categoryAtmospheric: categoryAtmospheric ?? this.categoryAtmospheric,
      categoryBirds: categoryBirds ?? this.categoryBirds,
      categoryArtificial: categoryArtificial ?? this.categoryArtificial,
      categoryOther: categoryOther ?? this.categoryOther,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  CieloColors lerp(covariant CieloColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return CieloColors(
      variant: t < 0.5 ? variant : other.variant,
      background: l(background, other.background),
      surface1: l(surface1, other.surface1),
      surface2: l(surface2, other.surface2),
      surface3: l(surface3, other.surface3),
      outline: l(outline, other.outline),
      outlineStrong: l(outlineStrong, other.outlineStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentContainer: l(accentContainer, other.accentContainer),
      onAccentContainer: l(onAccentContainer, other.onAccentContainer),
      danger: l(danger, other.danger),
      onDanger: l(onDanger, other.onDanger),
      dangerContainer: l(dangerContainer, other.dangerContainer),
      onDangerContainer: l(onDangerContainer, other.onDangerContainer),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      categoryAstronomy: l(categoryAstronomy, other.categoryAstronomy),
      categoryAtmospheric: l(categoryAtmospheric, other.categoryAtmospheric),
      categoryBirds: l(categoryBirds, other.categoryBirds),
      categoryArtificial: l(categoryArtificial, other.categoryArtificial),
      categoryOther: l(categoryOther, other.categoryOther),
      scrim: l(scrim, other.scrim),
    );
  }
}
