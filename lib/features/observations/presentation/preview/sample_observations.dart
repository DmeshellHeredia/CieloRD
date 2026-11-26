import '../../../../app/contracts.dart';

/// Observaciones de ejemplo para la vista previa y las capturas.
/// Lugares reales de República Dominicana; datos ficticios. Hora local UTC−4.
List<Observation> sampleObservations({required DateTime now}) {
  const int offset = -240;
  int seq = 0;

  Observation make({
    required String title,
    required ObservationCategory category,
    required Duration ago,
    String? place,
    double? lat,
    double? lon,
    LocationSource? source,
    SkyCondition? sky,
    String? description,
    int? durationSeconds,
    CardinalDirection? direction,
    double? elevation,
    int photos = 0,
    int audios = 0,
    ObservationStatus status = ObservationStatus.published,
    bool withDate = true,
  }) {
    seq++;
    final String id = 'obs-${seq.toString().padLeft(3, '0')}';
    final DateTime observed = now.toUtc().subtract(ago);
    return Observation(
      id: id,
      status: status,
      revision: 1,
      createdAt: observed,
      updatedAt: observed,
      input: ObservationInput(
        title: title,
        observedAt: withDate ? observed : null,
        utcOffsetMinutes: withDate ? offset : null,
        category: category,
        skyCondition: sky,
        description: description,
        durationSeconds: durationSeconds,
        direction: direction,
        elevationDegrees: elevation,
        location: place == null && lat == null
            ? null
            : ObservationLocation(
                placeName: place,
                latitude: lat,
                longitude: lon,
                source: source ?? (lat != null ? LocationSource.manual : LocationSource.text),
                accuracyM: source == LocationSource.gps ? 12 : null,
              ),
        media: <ObservationMedia>[
          for (int i = 0; i < photos; i++)
            ObservationMedia(
              id: '$id-p$i',
              kind: MediaKind.photo,
              relativePath: 'media/$id/p$i.jpg',
              mimeType: 'image/jpeg',
              byteSize: 240000,
            ),
          for (int i = 0; i < audios; i++)
            ObservationMedia(
              id: '$id-a$i',
              kind: MediaKind.audio,
              relativePath: 'media/$id/a$i.m4a',
              mimeType: 'audio/mp4',
              byteSize: 80000,
              durationMs: 42000,
            ),
        ],
      ),
    );
  }

  return <Observation>[
    make(
      title: 'Estación Espacial cruzando hacia el noreste',
      category: ObservationCategory.artificial,
      ago: const Duration(hours: 2),
      place: 'Malecón de Santo Domingo',
      lat: 18.4637, lon: -69.8939, source: LocationSource.gps,
      sky: SkyCondition.partlyCloudy,
      description: 'Paso brillante de unos cuatro minutos, sin destellos. Se perdió entre nubes bajas al final.',
      durationSeconds: 240, direction: CardinalDirection.northEast, elevation: 55, audios: 1,
    ),
    make(
      title: 'Lluvia de Leónidas sobre Valle Nuevo',
      category: ObservationCategory.astronomy,
      ago: const Duration(days: 5, hours: 3),
      place: 'Valle Nuevo, Constanza',
      lat: 18.7928, lon: -70.6036, source: LocationSource.gps,
      sky: SkyCondition.clear,
      description: 'Más de cuarenta meteoros por hora con cielo despejado y sin luna. Dos bólidos verdes hacia el este.',
      durationSeconds: 5400, direction: CardinalDirection.east, elevation: 70, photos: 3, audios: 1,
    ),
    make(
      title: 'Calima espesa al atardecer',
      category: ObservationCategory.atmospheric,
      ago: const Duration(days: 6, hours: 1),
      place: 'Santo Domingo Este',
      sky: SkyCondition.saharanDust,
      description: 'El sol se volvió naranja pálido una hora antes de ponerse. Visibilidad muy reducida.',
      photos: 1,
    ),
    make(
      title: 'Bandada de garzas hacia el oeste',
      category: ObservationCategory.birds,
      ago: const Duration(days: 9),
      place: 'Laguna de Oviedo, Pedernales',
      sky: SkyCondition.clear,
      direction: CardinalDirection.west, photos: 2,
    ),
    make(
      title: 'Halo solar de 22°',
      category: ObservationCategory.atmospheric,
      ago: const Duration(days: 14, hours: 6),
      place: 'Santiago de los Caballeros',
      sky: SkyCondition.partlyCloudy,
      description: 'Anillo completo alrededor del sol durante casi media hora, con cirros altos.',
      durationSeconds: 1800, elevation: 60,
    ),
    make(
      title: 'Júpiter y la Luna en conjunción',
      category: ObservationCategory.astronomy,
      ago: const Duration(days: 21, hours: 2),
      place: 'Jarabacoa',
      lat: 19.1170, lon: -70.6362, source: LocationSource.manual,
      sky: SkyCondition.clear, direction: CardinalDirection.southEast, elevation: 40, photos: 1,
    ),
    make(
      title: 'Avión con estela doble',
      category: ObservationCategory.artificial,
      ago: const Duration(days: 33),
      place: 'Punta Cana',
      sky: SkyCondition.mist, direction: CardinalDirection.north,
    ),
    make(
      title: 'Saturno con los anillos casi de canto',
      category: ObservationCategory.astronomy,
      ago: const Duration(days: 38, hours: 4),
      place: 'Observatorio de Cabrera, María Trinidad Sánchez',
      sky: SkyCondition.clear, photos: 2,
    ),
    make(
      title: 'Lluvia ligera con arcoíris lunar',
      category: ObservationCategory.atmospheric,
      ago: const Duration(days: 45, hours: 5),
      place: 'Samaná',
      sky: SkyCondition.lightRain,
      description: 'Arco blanquecino, muy tenue, frente a la luna casi llena.',
    ),
    make(
      title: 'Cotorras de La Española en el parque',
      category: ObservationCategory.birds,
      ago: const Duration(days: 52),
      place: 'Parque Mirador Sur, Santo Domingo',
      audios: 1,
    ),
    make(
      title: 'Venus muy brillante al oeste',
      category: ObservationCategory.astronomy,
      ago: const Duration(days: 60, hours: 2),
      place: 'Baní',
      sky: SkyCondition.clear, direction: CardinalDirection.west, elevation: 20,
    ),
    make(
      title: 'Luz desconocida inmóvil',
      category: ObservationCategory.other,
      ago: const Duration(days: 64, hours: 3),
      place: 'Monte Cristi',
      sky: SkyCondition.unknown,
      description: 'Punto anaranjado fijo durante diez minutos; probablemente un globo de luz.',
      durationSeconds: 600,
    ),
    make(
      title: 'Bruma matinal en el valle',
      category: ObservationCategory.atmospheric,
      ago: const Duration(days: 71),
      place: 'Constanza',
      sky: SkyCondition.mist,
    ),
    make(
      title: 'Starlink en fila',
      category: ObservationCategory.artificial,
      ago: const Duration(days: 80, hours: 1),
      place: 'Barahona',
      lat: 18.2085, lon: -71.1008, source: LocationSource.gps,
      sky: SkyCondition.clear, durationSeconds: 150, direction: CardinalDirection.southWest, photos: 1,
    ),
    // Borradores (registro rápido sin completar).
    make(
      title: 'Bólido verde',
      category: ObservationCategory.astronomy,
      ago: const Duration(hours: 20),
      place: 'Higüey',
      status: ObservationStatus.draft,
    ),
    make(
      title: '',
      category: ObservationCategory.birds,
      ago: const Duration(days: 2),
      status: ObservationStatus.draft,
      withDate: false,
    ),
  ];
}
