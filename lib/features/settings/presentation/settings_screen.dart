import 'package:flutter/material.dart';

import '../../../app/app_info.dart';
import '../../../app/contracts.dart';
import '../../../design/design.dart';
import '../../../l10n/cielo_strings.dart';
import '../../../ui_kit/ui_kit.dart';
import '../../security/application/app_lock_controller.dart';
import '../../security/presentation/auth_messages.dart';
import '../application/settings_controller.dart';

/// Ajustes: apariencia, seguridad, datos e información. Las secciones sin
/// colaborador no se muestran.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    this.lock,
    this.onExport,
    this.onImport,
    this.onEraseAll,
    this.onEditProfile,
    this.onAbout,
  });

  final SettingsController settings;
  final AppLockController? lock;
  final void Function(BuildContext context)? onExport;
  final void Function(BuildContext context)? onImport;
  final void Function(BuildContext context)? onEraseAll;
  final void Function(BuildContext context)? onEditProfile;
  final void Function(BuildContext context)? onAbout;

  static const Map<AppTheme, (String, IconData)>
  themes = <AppTheme, (String, IconData)>{
    AppTheme.system: (CieloStrings.themeSystem, Icons.brightness_auto_rounded),
    AppTheme.day: (CieloStrings.themeDay, Icons.light_mode_rounded),
    AppTheme.night: (CieloStrings.themeNight, Icons.dark_mode_rounded),
    AppTheme.astronomer: (CieloStrings.themeAstro, Icons.visibility_rounded),
  };

  Future<void> _update(
    BuildContext context,
    AppSettings Function(AppSettings) change,
  ) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final AppFailure? failure = await settings.update(change);
    if (failure != null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text(CieloStrings.settingsSaveFailed)),
      );
    }
  }

  Future<void> _toggleLock(BuildContext context, bool enable) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final ({AuthOutcome outcome, AppFailure? failure}) result = enable
        ? await lock!.enable(CieloStrings.lockReasonEnable)
        : await lock!.disable(CieloStrings.lockReasonDisable);
    final String message;
    if (result.failure != null) {
      message = CieloStrings.settingsSaveFailed;
    } else if (result.outcome == AuthOutcome.success) {
      message = enable ? CieloStrings.lockEnabled : CieloStrings.lockDisabled;
    } else if (result.outcome == AuthOutcome.noCredentials) {
      message = CieloStrings.settingsLockNoCredentials;
    } else {
      message = AuthMessages.of(result.outcome);
    }
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle? secondary = text.bodyMedium?.copyWith(
      color: c.textSecondary,
    );
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable?>[settings, lock]),
      builder: (BuildContext context, _) {
        final AppSettings value = settings.settings;
        final bool systemReduced = View.of(context)
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
        return Scaffold(
          appBar: AppBar(title: const Text(CieloStrings.settingsTitle)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              CieloSpace.gutter,
              0,
              CieloSpace.gutter,
              CieloSpace.xxl,
            ),
            children: <Widget>[
              const CieloSectionHeader(title: CieloStrings.settingsAppearance),
              Text(CieloStrings.settingsTheme, style: text.titleSmall),
              const SizedBox(height: CieloSpace.sm),
              Wrap(
                spacing: CieloSpace.sm,
                runSpacing: CieloSpace.sm,
                children: <Widget>[
                  for (final MapEntry<AppTheme, (String, IconData)> e
                      in themes.entries)
                    CieloChoiceChip(
                      label: e.value.$1,
                      leading: Icon(e.value.$2),
                      selected: value.theme == e.key,
                      onSelected: (_) => _update(
                        context,
                        (AppSettings s) => s.copyWith(theme: e.key),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: CieloSpace.sm),
              Text(CieloStrings.themeSystemHint, style: secondary),
              const SizedBox(height: CieloSpace.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(CieloStrings.settingsReducedMotion),
                subtitle: Text(
                  systemReduced
                      ? CieloStrings.settingsReducedMotionSystem
                      : CieloStrings.settingsReducedMotionHint,
                ),
                value: systemReduced || value.reducedMotion,
                onChanged: systemReduced
                    ? null
                    : (bool on) => _update(
                        context,
                        (AppSettings s) => s.copyWith(reducedMotion: on),
                      ),
              ),
              if (lock != null) ...<Widget>[
                const CieloSectionHeader(title: CieloStrings.settingsSecurity),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(CieloStrings.settingsLock),
                  subtitle: const Text(CieloStrings.settingsLockHint),
                  value: value.authenticationEnabled,
                  onChanged: lock!.isAuthenticating
                      ? null
                      : (bool on) => _toggleLock(context, on),
                ),
                const SizedBox(height: CieloSpace.sm),
                Text(CieloStrings.settingsLockScope, style: secondary),
              ],
              const CieloSectionHeader(title: CieloStrings.settingsData),
              if (onExport != null)
                _Row(
                  icon: Icons.ios_share_rounded,
                  title: CieloStrings.exportTitle,
                  subtitle: CieloStrings.exportHint,
                  onTap: () => onExport!(context),
                ),
              if (onImport != null)
                _Row(
                  icon: Icons.file_open_rounded,
                  title: CieloStrings.importTitle,
                  subtitle: CieloStrings.importHint,
                  onTap: () => onImport!(context),
                ),
              if (onEraseAll != null)
                _Row(
                  icon: Icons.delete_forever_rounded,
                  title: CieloStrings.eraseAllAction,
                  subtitle: CieloStrings.eraseHint,
                  color: c.danger,
                  onTap: () => onEraseAll!(context),
                ),
              const CieloSectionHeader(title: CieloStrings.settingsAbout),
              if (onEditProfile != null)
                _Row(
                  icon: Icons.badge_outlined,
                  title: CieloStrings.profileTitle,
                  subtitle: CieloStrings.profilePrivacy,
                  onTap: () => onEditProfile!(context),
                ),
              if (onAbout != null)
                _Row(
                  icon: Icons.info_outline_rounded,
                  title: CieloStrings.aboutTitle,
                  subtitle: CieloStrings.aboutVersion(AppInfo.label),
                  onTap: () => onAbout!(context),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: color),
    title: Text(
      title,
      style: color == null
          ? null
          : Theme.of(context).textTheme.bodyLarge?.copyWith(color: color),
    ),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
