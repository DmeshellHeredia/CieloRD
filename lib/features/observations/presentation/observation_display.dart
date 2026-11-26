import '../../../app/contracts.dart';
import '../../../l10n/cielo_format.dart';
import '../../../l10n/cielo_strings.dart';
import '../../../ui_kit/ui_kit.dart';

/// Traducción de un [Observation] del contrato C0 a valores de presentación.
///
/// No es un modelo paralelo: solo lee `observation.input` y aplica las reglas
/// de visualización (hora local con el desplazamiento original, etiquetas en
/// español, apariencias de categoría).
extension ObservationDisplay on Observation {
  /// Hora de pared en el lugar de la observación: UTC + desplazamiento
  /// original. El resultado se usa solo para mostrar (sus campos year/hour…
  /// son los locales); no se debe volver a convertir a UTC.
  DateTime? get localObservedAt {
    final DateTime? utc = input.observedAt;
    final int? offset = input.utcOffsetMinutes;
    if (utc == null) return null;
    return utc.toUtc().add(Duration(minutes: offset ?? 0));
  }

  String get displayTitle => input.title.trim().isEmpty ? CieloStrings.untitled : input.title.trim();

  CategoryVisual get categoryVisual => CategoryVisual.fromCode(input.category?.name);

  bool get isDraft => status == ObservationStatus.draft;

  String whenLabel({DateTime? now}) {
    final DateTime? local = localObservedAt;
    return local == null ? CieloStrings.noDate : CieloFormat.dateTime(local, now: now);
  }

  String get whenSpoken {
    final DateTime? local = localObservedAt;
    return local == null ? CieloStrings.noDate : '${CieloFormat.dateLong(local)}, ${CieloFormat.time(local)}';
  }

  /// Lugar escrito; si solo hay coordenadas, las coordenadas formateadas.
  String? get placeLabel {
    final ObservationLocation? loc = input.location;
    if (loc == null) return null;
    final String? name = loc.placeName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (loc.hasCoordinates) return CieloFormat.coordinates(loc.latitude!, loc.longitude!);
    return null;
  }

  ObservationCardLocation get cardLocation => switch (input.location?.source) {
        LocationSource.gps when input.location!.hasCoordinates => ObservationCardLocation.gps,
        LocationSource.manual when input.location!.hasCoordinates => ObservationCardLocation.manual,
        _ => ObservationCardLocation.none,
      };

  int get photoCount => input.media.where((ObservationMedia m) => m.kind == MediaKind.photo).length;
  int get audioCount => input.media.where((ObservationMedia m) => m.kind == MediaKind.audio).length;

  ObservationMedia? get firstPhoto {
    for (final ObservationMedia m in input.media) {
      if (m.kind == MediaKind.photo) return m;
    }
    return null;
  }

  /// Etiqueta Hero compartida entre la tarjeta y el detalle.
  String get heroTag => 'observation-$id';
}
