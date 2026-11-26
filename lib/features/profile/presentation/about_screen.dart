import 'package:flutter/material.dart';

import '../../../app/app_info.dart';
import '../../../app/contracts.dart';
import '../../../design/design.dart';
import '../../../l10n/cielo_strings.dart';
import '../../../l10n/failure_messages.dart';
import '../../../ui_kit/ui_kit.dart';
import 'profile_avatar.dart';

/// Acerca de: quién observa, qué versión es y de dónde salen el mapa y las
/// fuentes. Un perfil borrado se presenta como estado vacío editable.
class AboutScreen extends StatefulWidget {
  const AboutScreen({
    super.key,
    required this.repository,
    this.resolveMediaPath,
    this.onEditProfile,
  });

  final ProfileRepository repository;
  final Future<Result<String>> Function(String mediaId)? resolveMediaPath;

  /// Abre la edición y devuelve el perfil guardado, o `null` si no cambió.
  final Future<ObserverProfile?> Function(BuildContext context)? onEditProfile;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  ObserverProfile? _profile;
  AppFailure? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final Result<ObserverProfile?> result = await widget.repository.get();
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case Success<ObserverProfile?>(:final ObserverProfile? value):
          _profile = value;
          _failure = null;
        case Failure<ObserverProfile?>(:final AppFailure failure):
          _failure = failure;
      }
    });
  }

  Future<void> _edit() async {
    final ObserverProfile? saved = await widget.onEditProfile!(context);
    if (saved == null || !mounted) return;
    setState(() => _profile = saved);
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text(CieloStrings.profileSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle? secondary = text.bodyMedium?.copyWith(
      color: c.textSecondary,
    );
    return Scaffold(
      appBar: AppBar(title: const Text(CieloStrings.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          CieloSpace.gutter,
          CieloSpace.sm,
          CieloSpace.gutter,
          CieloSpace.xxl,
        ),
        children: <Widget>[
          const CieloSectionHeader(title: CieloStrings.aboutObserver),
          if (_loading)
            const CieloSkeletonList(count: 1)
          else if (_failure != null)
            CieloBanner(
              tone: CieloTone.danger,
              message: FailureMessages.of(_failure!),
              actionLabel: CieloStrings.retry,
              onAction: _load,
            )
          else
            _ObserverCard(
              profile: _profile ?? const ObserverProfile(),
              resolve: widget.resolveMediaPath,
            ),
          if (widget.onEditProfile != null && !_loading) ...<Widget>[
            const SizedBox(height: CieloSpace.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text(CieloStrings.profileEdit),
              ),
            ),
          ],
          const SizedBox(height: CieloSpace.xl),
          MergeSemantics(
            child: Row(
              children: <Widget>[
                const CieloBrandMark(),
                const SizedBox(width: CieloSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(CieloStrings.appName, style: text.headlineMedium),
                      Text(
                        CieloStrings.aboutVersion(AppInfo.label),
                        style: secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CieloSpace.sm),
          Text(CieloStrings.offlinePromise, style: secondary),
          const CieloSectionHeader(title: CieloStrings.aboutMap),
          Text(CieloStrings.aboutMapCredit, style: text.bodyLarge),
          const SizedBox(height: CieloSpace.sm),
          Text(CieloStrings.aboutMapScope, style: secondary),
          const CieloSectionHeader(title: CieloStrings.aboutLicenses),
          Text(CieloStrings.aboutFonts, style: text.bodyLarge),
          const SizedBox(height: CieloSpace.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: CieloStrings.appName,
                applicationVersion: AppInfo.label,
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(CieloSpace.sm),
                  child: CieloBrandMark(),
                ),
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text(CieloStrings.aboutLicensesAll),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObserverCard extends StatelessWidget {
  const _ObserverCard({required this.profile, required this.resolve});

  final ObserverProfile profile;
  final Future<Result<String>> Function(String mediaId)? resolve;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final Widget details;
    if (profile.isEmpty) {
      details = Text(
        CieloStrings.profileEmpty,
        style: text.bodyLarge?.copyWith(color: c.textSecondary),
      );
    } else {
      final rows = <(String, TextStyle?, double)>[
        (profile.fullName.trim(), text.headlineSmall, CieloSpace.xs),
        (
          profile.studentId.trim(),
          text.titleSmall?.copyWith(color: c.textSecondary),
          CieloSpace.sm,
        ),
        (profile.motto.trim(), text.bodyLarge, 0),
      ].where((row) => row.$1.isNotEmpty).toList();
      details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var index = 0; index < rows.length; index++) ...<Widget>[
            Text(rows[index].$1, style: rows[index].$2),
            if (index < rows.length - 1)
              SizedBox(height: rows[index].$3),
          ],
        ],
      );
    }
    final Widget avatar = ProfileAvatar(
      photoMediaId: profile.photoMediaId,
      resolve: resolve,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CieloSpace.lg),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Con texto grande, la foto va encima para no estrujar el nombre.
            final bool stacked =
                MediaQuery.textScalerOf(context).scale(1) > 1.4 ||
                constraints.maxWidth < 280;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  avatar,
                  const SizedBox(height: CieloSpace.md),
                  details,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                avatar,
                const SizedBox(width: CieloSpace.lg),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }
}
