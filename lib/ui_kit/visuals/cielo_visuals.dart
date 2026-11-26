import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../l10n/cielo_strings.dart';
import '../glyphs/cielo_glyph.dart';

// Tablas de apariencia (etiqueta, glifo/icono y color) indexadas por el
// código estable que se guarda en la base de datos.
//
// No son modelos de dominio ni contratos: la UI traduce el código que entregue
// el modelo de Codex a su apariencia. Códigos alineados con
// `lib/features/observations/domain/observation_types.dart`:
// `ObservationCategory.name`, `SkyCondition.code` y `CardinalDirection.code`.
// Una prueba de widgets verifica que cubren todos los valores.

/// Apariencia de una categoría raíz.
@immutable
class CategoryVisual {
  const CategoryVisual._({
    required this.code,
    required this.label,
    required this.shortLabel,
    required this.glyph,
  });

  final String code;

  /// Nombre completo (lectores de pantalla, detalle, filtros).
  final String label;

  /// Nombre corto para cuadrículas y tarjetas.
  final String shortLabel;
  final CieloGlyph glyph;

  Color tint(CieloColors c) => switch (glyph) {
        CieloGlyph.astronomy => c.categoryAstronomy,
        CieloGlyph.atmospheric => c.categoryAtmospheric,
        CieloGlyph.birds => c.categoryBirds,
        CieloGlyph.artificial => c.categoryArtificial,
        _ => c.categoryOther,
      };

  static const CategoryVisual astronomy = CategoryVisual._(
    code: 'astronomy',
    label: CieloStrings.categoryAstronomy,
    shortLabel: CieloStrings.categoryAstronomy,
    glyph: CieloGlyph.astronomy,
  );
  static const CategoryVisual atmospheric = CategoryVisual._(
    code: 'atmospheric',
    label: CieloStrings.categoryAtmospheric,
    shortLabel: CieloStrings.categoryAtmosphericShort,
    glyph: CieloGlyph.atmospheric,
  );
  static const CategoryVisual birds = CategoryVisual._(
    code: 'birds',
    label: CieloStrings.categoryBirds,
    shortLabel: CieloStrings.categoryBirds,
    glyph: CieloGlyph.birds,
  );
  static const CategoryVisual artificial = CategoryVisual._(
    code: 'artificial',
    label: CieloStrings.categoryArtificial,
    shortLabel: CieloStrings.categoryArtificialShort,
    glyph: CieloGlyph.artificial,
  );
  static const CategoryVisual other = CategoryVisual._(
    code: 'other',
    label: CieloStrings.categoryOther,
    shortLabel: CieloStrings.categoryOther,
    glyph: CieloGlyph.other,
  );

  static const List<CategoryVisual> all = <CategoryVisual>[
    astronomy,
    atmospheric,
    birds,
    artificial,
    other,
  ];

  /// Código desconocido o nulo → [other], para no romper la UI con datos
  /// importados de versiones futuras.
  static CategoryVisual fromCode(String? code) =>
      all.firstWhere((CategoryVisual v) => v.code == code, orElse: () => other);
}

/// Apariencia de una condición del cielo.
@immutable
class SkyConditionVisual {
  const SkyConditionVisual._(this.code, this.label, this.icon, {this.hint});

  final String code;
  final String label;
  final IconData icon;

  /// Aclaración breve para lectores de pantalla (p. ej., "Polvo del Sahara").
  final String? hint;

  static const SkyConditionVisual clear =
      SkyConditionVisual._('clear', CieloStrings.skyClear, Icons.auto_awesome_rounded);
  static const SkyConditionVisual partlyCloudy =
      SkyConditionVisual._('partly_cloudy', CieloStrings.skyPartlyCloudy, Icons.filter_drama_rounded);
  static const SkyConditionVisual cloudy =
      SkyConditionVisual._('cloudy', CieloStrings.skyCloudy, Icons.cloud_rounded);
  static const SkyConditionVisual mist =
      SkyConditionVisual._('mist', CieloStrings.skyHaze, Icons.dehaze_rounded);
  static const SkyConditionVisual saharanDust = SkyConditionVisual._(
    'saharan_dust',
    CieloStrings.skySaharanDust,
    Icons.grain_rounded,
    hint: CieloStrings.skySaharanDustHint,
  );
  static const SkyConditionVisual lightRain =
      SkyConditionVisual._('light_rain', CieloStrings.skyLightRain, Icons.water_drop_rounded);
  static const SkyConditionVisual other =
      SkyConditionVisual._('other', CieloStrings.skyOther, Icons.more_horiz_rounded);
  static const SkyConditionVisual unknown =
      SkyConditionVisual._('unknown', CieloStrings.skyUnknown, Icons.help_outline_rounded);

  static const List<SkyConditionVisual> all = <SkyConditionVisual>[
    clear,
    partlyCloudy,
    cloudy,
    mist,
    saharanDust,
    lightRain,
    other,
    unknown,
  ];

  static SkyConditionVisual fromCode(String? code) =>
      all.firstWhere((SkyConditionVisual v) => v.code == code, orElse: () => unknown);
}

/// Apariencia de una dirección cardinal (rosa de 8 puntos).
@immutable
class DirectionVisual {
  const DirectionVisual._(this.code, this.label, this.abbreviation);

  final String code;

  /// "Noroeste"
  final String label;

  /// "NO" — en español, Oeste se abrevia "O".
  final String abbreviation;

  static const DirectionVisual n = DirectionVisual._('n', CieloStrings.directionN, 'N');
  static const DirectionVisual ne = DirectionVisual._('ne', CieloStrings.directionNE, 'NE');
  static const DirectionVisual e = DirectionVisual._('e', CieloStrings.directionE, 'E');
  static const DirectionVisual se = DirectionVisual._('se', CieloStrings.directionSE, 'SE');
  static const DirectionVisual s = DirectionVisual._('s', CieloStrings.directionS, 'S');
  static const DirectionVisual sw = DirectionVisual._('sw', CieloStrings.directionSW, 'SO');
  static const DirectionVisual w = DirectionVisual._('w', CieloStrings.directionW, 'O');
  static const DirectionVisual nw = DirectionVisual._('nw', CieloStrings.directionNW, 'NO');

  static const List<DirectionVisual> all = <DirectionVisual>[n, ne, e, se, s, sw, w, nw];

  static DirectionVisual? fromCode(String? code) {
    for (final DirectionVisual v in all) {
      if (v.code == code) return v;
    }
    return null;
  }
}
