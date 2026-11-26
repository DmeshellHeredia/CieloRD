import 'package:flutter/material.dart';

import '../../../../app/contracts.dart';
import '../../../../ui_kit/ui_kit.dart';
import '../observation_display.dart';
import 'observation_thumbnail.dart';

/// Tarjeta del Diario a partir de un [Observation] del contrato C0.
class DiaryObservationCard extends StatelessWidget {
  const DiaryObservationCard({
    super.key,
    required this.observation,
    required this.onTap,
    this.resolveMediaPath,
    this.now,
  });

  final Observation observation;
  final VoidCallback onTap;
  final MediaPathResolver? resolveMediaPath;

  /// Referencia para decidir si se muestra el año (inyectable en pruebas).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final Observation o = observation;
    final ObservationMedia? photo = o.firstPhoto;
    final MediaPathResolver? resolve = resolveMediaPath;
    return ObservationCard(
      title: o.displayTitle,
      category: o.categoryVisual,
      whenLabel: o.whenLabel(now: now),
      semanticWhen: o.whenSpoken,
      placeLabel: o.placeLabel,
      isDraft: o.isDraft,
      photoCount: o.photoCount,
      audioCount: o.audioCount,
      location: o.cardLocation,
      heroTag: o.heroTag,
      thumbnail: photo != null && resolve != null
          ? ObservationThumbnail(mediaId: photo.id, category: o.categoryVisual, resolve: resolve)
          : null,
      onTap: onTap,
    );
  }
}
