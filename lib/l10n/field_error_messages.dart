import 'cielo_strings.dart';

/// Traduce los códigos de `AppFailure.fieldErrors` del `ObservationValidator`
/// (ver docs/C0_CONTRACTS.md, "Códigos de validación") a mensajes por campo.
abstract final class FieldErrorMessages {
  static String forField(String field, String code) {
    switch (code) {
      case 'required':
        if (field == 'location.placeName') return CieloStrings.fieldPlaceRequired;
        if (field == 'location.coordinates') return CieloStrings.fieldCoordinatesPair;
        return CieloStrings.fieldRequired;
      case 'out_of_range':
        if (field == 'location.latitude') return CieloStrings.fieldLatitudeRange;
        if (field == 'location.longitude') return CieloStrings.fieldLongitudeRange;
        return CieloStrings.fieldOutOfRange;
      case 'non_negative':
        return CieloStrings.fieldNonNegative;
      case 'pair_required':
      case 'coordinate_source_required':
        return CieloStrings.fieldCoordinatesPair;
      case 'max_5':
        return CieloStrings.fieldTooManyPhotos;
      case 'max_3':
        return CieloStrings.fieldTooManyAudios;
      default:
        return CieloStrings.fieldInvalid;
    }
  }
}
