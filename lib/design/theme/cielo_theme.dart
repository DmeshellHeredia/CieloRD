import 'package:flutter/material.dart';

import '../tokens/cielo_tokens.dart';
import '../tokens/cielo_typography.dart';
import 'cielo_colors.dart';

/// Construye los `ThemeData` de CieloRD a partir de [CieloColors].
///
/// Todos los colores del `ColorScheme` y los colores sueltos de `ThemeData`
/// se asignan explícitamente para que ningún valor por defecto de Material
/// (azules, grises o blancos) aparezca en el modo astrónomo.
abstract final class CieloTheme {
  static const CieloThemeVariant defaultVariant = CieloThemeVariant.night;

  static ThemeData night() => build(CieloThemeVariant.night);
  static ThemeData day() => build(CieloThemeVariant.day);
  static ThemeData astro() => build(CieloThemeVariant.astro);

  static ColorScheme colorScheme(CieloColors c) {
    final bool dark = c.variant.isDark;
    // Snackbars y tooltips no deben ser bloques claros de noche.
    final Color inverseSurface = dark ? c.surface3 : const Color(0xFF1B2445);
    final Color onInverseSurface = dark ? c.textPrimary : const Color(0xFFF4F6FB);
    final Color inversePrimary = dark ? c.primary : const Color(0xFF5ED3C7);
    return ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      primaryFixed: c.primaryContainer,
      primaryFixedDim: c.primaryContainer,
      onPrimaryFixed: c.onPrimaryContainer,
      onPrimaryFixedVariant: c.onPrimaryContainer,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.accentContainer,
      onSecondaryContainer: c.onAccentContainer,
      secondaryFixed: c.accentContainer,
      secondaryFixedDim: c.accentContainer,
      onSecondaryFixed: c.onAccentContainer,
      onSecondaryFixedVariant: c.onAccentContainer,
      tertiary: c.accent,
      onTertiary: c.onAccent,
      tertiaryContainer: c.accentContainer,
      onTertiaryContainer: c.onAccentContainer,
      tertiaryFixed: c.accentContainer,
      tertiaryFixedDim: c.accentContainer,
      onTertiaryFixed: c.onAccentContainer,
      onTertiaryFixedVariant: c.onAccentContainer,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.dangerContainer,
      onErrorContainer: c.onDangerContainer,
      surface: c.background,
      onSurface: c.textPrimary,
      surfaceDim: c.background,
      surfaceBright: c.surface3,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface1,
      surfaceContainer: c.surface1,
      surfaceContainerHigh: c.surface2,
      surfaceContainerHighest: c.surface3,
      onSurfaceVariant: c.textSecondary,
      outline: c.outlineStrong,
      outlineVariant: c.outline,
      shadow: const Color(0xFF000000),
      scrim: c.scrim,
      inverseSurface: inverseSurface,
      onInverseSurface: onInverseSurface,
      inversePrimary: inversePrimary,
      surfaceTint: const Color(0x00000000),
    );
  }

  static ThemeData build(CieloThemeVariant variant) {
    final CieloColors c = CieloColors.forVariant(variant);
    final ColorScheme scheme = colorScheme(c);
    final TextTheme text = CieloTypography.textTheme().apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
      decorationColor: c.textPrimary,
    );

    const Size minButton = Size(64, CieloSize.minTouch);
    const OutlinedBorder pill = StadiumBorder();
    final EdgeInsets buttonPadding =
        const EdgeInsets.symmetric(horizontal: CieloSpace.xl, vertical: CieloSpace.md);

    final OutlineInputBorder fieldBorder = OutlineInputBorder(
      borderRadius: CieloRadius.fieldAll,
      borderSide: BorderSide(color: c.outlineStrong),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[c],
      fontFamily: CieloFonts.body,
      textTheme: text,
      primaryTextTheme: text,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      cardColor: c.surface1,
      dividerColor: c.outline,
      disabledColor: c.textSecondary.withValues(alpha: 0.38),
      hintColor: c.textSecondary,
      focusColor: c.primary.withValues(alpha: 0.18),
      hoverColor: c.primary.withValues(alpha: 0.08),
      highlightColor: c.primary.withValues(alpha: 0.10),
      splashColor: c.primary.withValues(alpha: 0.14),
      unselectedWidgetColor: c.textSecondary,
      shadowColor: const Color(0xFF000000),
      primaryColor: c.primary,
      primaryColorDark: c.primaryContainer,
      primaryColorLight: c.primaryContainer,
      secondaryHeaderColor: c.surface2,
      iconTheme: IconThemeData(color: c.textPrimary, size: CieloSize.iconMd),
      primaryIconTheme: IconThemeData(color: c.onPrimary, size: CieloSize.iconMd),
      appBarTheme: AppBarThemeData(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: c.surface1,
        surfaceTintColor: const Color(0x00000000),
        elevation: variant == CieloThemeVariant.day ? 1 : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: CieloRadius.cardAll,
          side: BorderSide(color: c.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.filledBackground,
          foregroundColor: c.onFilled,
          minimumSize: minButton,
          padding: buttonPadding,
          shape: c.isAstro ? StadiumBorder(side: BorderSide(color: c.primary, width: 2)) : pill,
          textStyle: text.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.surface2,
          foregroundColor: c.textPrimary,
          minimumSize: minButton,
          padding: buttonPadding,
          shape: pill,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: minButton,
          padding: buttonPadding,
          shape: pill,
          side: BorderSide(color: c.outlineStrong),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: minButton,
          padding: const EdgeInsets.symmetric(horizontal: CieloSpace.lg),
          shape: pill,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size.square(CieloSize.minTouch),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.filledBackground,
        foregroundColor: c.onFilled,
        elevation: variant == CieloThemeVariant.day ? 3 : 0,
        extendedTextStyle: text.labelLarge,
        shape: c.isAstro ? StadiumBorder(side: BorderSide(color: c.primary, width: 2)) : const StadiumBorder(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: c.textPrimary,
          selectedForegroundColor: c.onPrimaryContainer,
          selectedBackgroundColor: c.primaryContainer,
          side: BorderSide(color: c.outlineStrong),
          minimumSize: const Size(0, CieloSize.minTouch),
          textStyle: text.labelMedium,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface1,
        selectedColor: c.primaryContainer,
        disabledColor: c.surface2,
        labelStyle: text.labelMedium?.copyWith(color: c.textPrimary),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: c.onPrimaryContainer),
        side: BorderSide(color: c.outlineStrong),
        shape: const RoundedRectangleBorder(borderRadius: CieloRadius.chipAll),
        checkmarkColor: c.onPrimaryContainer,
        iconTheme: IconThemeData(color: c.textPrimary, size: CieloSize.iconSm),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.surface2,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: c.danger, width: 2),
        ),
        labelStyle: text.bodyLarge?.copyWith(color: c.textSecondary),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: c.primary),
        hintStyle: text.bodyLarge?.copyWith(color: c.textSecondary),
        helperStyle: text.bodySmall?.copyWith(color: c.textSecondary),
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CieloSpace.lg,
          vertical: CieloSpace.lg,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primary.withValues(alpha: 0.32),
        selectionHandleColor: c.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
          if (s.contains(WidgetState.disabled)) return c.textSecondary.withValues(alpha: 0.38);
          return s.contains(WidgetState.selected) ? c.primary : const Color(0x00000000);
        }),
        checkColor: WidgetStatePropertyAll<Color>(c.onPrimary),
        side: BorderSide(color: c.outlineStrong, width: 2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? c.onPrimary : c.outlineStrong),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? c.primary : c.surface2),
        trackOutlineColor: WidgetStatePropertyAll<Color>(c.outlineStrong),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? c.primary : c.outlineStrong),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surface2,
        circularTrackColor: const Color(0x00000000),
      ),
      dividerTheme: DividerThemeData(color: c.outline, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        minTileHeight: CieloSize.fieldTouch,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: c.textSecondary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface1,
        surfaceTintColor: const Color(0x00000000),
        barrierColor: c.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CieloRadius.sheet)),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyLarge?.copyWith(color: c.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface1,
        modalBackgroundColor: c.surface1,
        surfaceTintColor: const Color(0x00000000),
        modalBarrierColor: c.scrim,
        showDragHandle: true,
        dragHandleColor: c.outlineStrong,
        shape: const RoundedRectangleBorder(borderRadius: CieloRadius.sheetTop),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: CieloRadius.tileAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface1,
        surfaceTintColor: const Color(0x00000000),
        indicatorColor: c.primaryContainer,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
            text.labelMedium?.copyWith(
              color: s.contains(WidgetState.selected) ? c.textPrimary : c.textSecondary,
            )),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? c.onPrimaryContainer : c.textSecondary,
            )),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: CieloRadius.chipAll,
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface2,
        surfaceTintColor: const Color(0x00000000),
        textStyle: text.bodyLarge,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surface3,
        thumbColor: c.primary,
        overlayColor: c.primary.withValues(alpha: 0.14),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(c.outlineStrong.withValues(alpha: 0.6)),
      ),
    );
  }
}
