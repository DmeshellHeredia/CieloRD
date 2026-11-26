import 'package:flutter/material.dart';

import '../../../design/design.dart';
import 'design_gallery_page.dart';

/// Punto de entrada aislado para revisar el sistema de diseño sin SQLite,
/// controladores ni plugins:
///
/// ```
/// flutter run -t lib/features/design_gallery/presentation/main_design_gallery.dart
/// ```
///
/// No se importa desde `main.dart`, así que no forma parte de la app final.
class DesignGalleryApp extends StatefulWidget {
  const DesignGalleryApp({
    super.key,
    this.initialVariant = CieloTheme.defaultVariant,
    this.initialTextScale = 1.0,
  });

  final CieloThemeVariant initialVariant;
  final double initialTextScale;

  @override
  State<DesignGalleryApp> createState() => _DesignGalleryAppState();
}

class _DesignGalleryAppState extends State<DesignGalleryApp> {
  late CieloThemeVariant _variant = widget.initialVariant;
  late double _textScale = widget.initialTextScale;
  bool _reduceMotion = false;
  bool _leftHanded = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CieloRD · Galería de diseño',
      debugShowCheckedModeBanner: false,
      theme: CieloTheme.build(_variant),
      // Sin interpolación al cambiar de tema: evita colores intermedios no
      // rojos al entrar o salir del modo astrónomo.
      themeAnimationDuration: Duration.zero,
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(_textScale),
            disableAnimations: media.disableAnimations || _reduceMotion,
          ),
          child: child!,
        );
      },
      home: DesignGalleryPage(
        variant: _variant,
        onVariantChanged: (CieloThemeVariant v) => setState(() => _variant = v),
        textScale: _textScale,
        onTextScaleChanged: (double v) => setState(() => _textScale = v),
        reduceMotion: _reduceMotion,
        onReduceMotionChanged: (bool v) => setState(() => _reduceMotion = v),
        leftHanded: _leftHanded,
        onLeftHandedChanged: (bool v) => setState(() => _leftHanded = v),
      ),
    );
  }
}
