import '../../../core/domain/result.dart';

/// `system` sigue el modo claro/oscuro del teléfono (Día/Noche).
enum AppTheme { system, night, day, astronomer }

final class AppSettings {
  AppSettings({
    this.theme = AppTheme.night,
    this.textScale,
    this.reducedMotion = false,
    this.authenticationEnabled = false,
  }) {
    if (textScale != null &&
        (!textScale!.isFinite || textScale! <= 0 || textScale! > 3)) {
      throw ArgumentError.value(
        textScale,
        'textScale',
        'Expected (0, 3] or null for system setting.',
      );
    }
  }
  final AppTheme theme;

  /// Null follows the system. UI must still respect accessibility scaling.
  final double? textScale;
  final bool reducedMotion;
  final bool authenticationEnabled;

  AppSettings copyWith({
    AppTheme? theme,
    bool? reducedMotion,
    bool? authenticationEnabled,
  }) => AppSettings(
    theme: theme ?? this.theme,
    textScale: textScale,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    authenticationEnabled: authenticationEnabled ?? this.authenticationEnabled,
  );
}

abstract interface class SettingsRepository {
  /// Returns defaults when no settings have been stored.
  Future<Result<AppSettings>> get();
  Future<Result<AppSettings>> save(AppSettings settings);
}
