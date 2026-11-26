import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/contracts.dart';
import '../../../../design/design.dart';
import '../../../../ui_kit/ui_kit.dart';

/// Resuelve la ruta local de un medio. Coincide con la firma de
/// `MediaService.resolveLocalPath` (C0): se pasa como tear-off,
/// `media.resolveLocalPath`, sin exigir un `MediaService` completo.
typedef MediaPathResolver = Future<Result<String>> Function(String mediaId);

/// Miniatura de la primera foto. Mientras resuelve o si falla (archivo
/// borrado, servicio no disponible) muestra el glifo de la categoría.
class ObservationThumbnail extends StatefulWidget {
  const ObservationThumbnail({
    super.key,
    required this.mediaId,
    required this.category,
    required this.resolve,
    this.cacheWidth = 168,
  });

  final String mediaId;
  final CategoryVisual category;
  final MediaPathResolver resolve;

  /// Ancho de decodificación en píxeles: limita memoria en listas largas.
  final int cacheWidth;

  @override
  State<ObservationThumbnail> createState() => _ObservationThumbnailState();
}

class _ObservationThumbnailState extends State<ObservationThumbnail> {
  late Future<Result<String>> _path = widget.resolve(widget.mediaId);

  @override
  void didUpdateWidget(ObservationThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) _path = widget.resolve(widget.mediaId);
  }

  @override
  Widget build(BuildContext context) {
    final Widget fallback = CategoryTile(category: widget.category);
    return FutureBuilder<Result<String>>(
      future: _path,
      builder: (BuildContext context, AsyncSnapshot<Result<String>> snapshot) {
        final Result<String>? result = snapshot.data;
        if (result is! Success<String>) return fallback;
        return Image.file(
          File(result.value),
          fit: BoxFit.cover,
          cacheWidth: widget.cacheWidth,
          gaplessPlayback: true,
          errorBuilder: (BuildContext context, Object error, StackTrace? stack) => fallback,
        );
      },
    );
  }
}

/// Casilla con el glifo de la categoría sobre su tinta.
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, this.glyphSize = 30});

  final CategoryVisual category;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    return ColoredBox(
      color: Color.alphaBlend(category.tint(c).withValues(alpha: 0.14), c.surface2),
      child: Center(child: CieloGlyphIcon(category.glyph, size: glyphSize, color: category.tint(c))),
    );
  }
}
