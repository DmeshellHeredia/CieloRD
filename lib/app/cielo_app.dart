import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../design/design.dart';
import '../features/backup/presentation/export_screen.dart';
import '../features/backup/presentation/import_screen.dart';
import '../features/maintenance/presentation/erase_all_screen.dart';
import '../features/observations/presentation/detail/observation_detail_screen.dart';
import '../features/observations/presentation/diary/diary_screen.dart';
import '../features/observations/presentation/form/observation_form_screen.dart';
import '../features/observations/presentation/form/quick_record_sheet.dart';
import '../features/map/domain/offline_province_map.dart';
import '../features/map/presentation/observation_map_screen.dart';
import '../features/profile/presentation/about_screen.dart';
import '../features/profile/presentation/profile_edit_screen.dart';
import '../features/security/application/app_lock_controller.dart';
import '../features/security/presentation/lock_screen.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/statistics/presentation/stats_screen.dart';
import '../l10n/cielo_strings.dart';
import '../ui_kit/ui_kit.dart';
import 'contracts.dart';

/// Rutas de la app. Los nombres de ruta están en español porque forman parte
/// de la experiencia (aparecen en registros de errores y enlaces internos).
abstract final class CieloRoutes {
  static const String diary = '/';
  static const String newObservation = '/registro';
  static const String map = '/mapa';
  static const String stats = '/estadisticas';
  static const String settings = '/ajustes';
  static const String export = '/ajustes/exportar';
  static const String import = '/ajustes/importar';
  static const String eraseAll = '/ajustes/borrar';
  static const String about = '/acerca';
  static const String profile = '/perfil';
  static String detail(String id) => '/observacion/$id';
  static String edit(String id) => '/observacion/$id/editar';
}

/// Raíz de la app: tema, localización en español y navegación.
///
/// Recibe los colaboradores por constructor (C0 §Integración 2). En
/// producción los aporta `main.dart` con SQLite; en pruebas y vista previa,
/// implementaciones en memoria de los mismos contratos.
class CieloApp extends StatefulWidget {
  const CieloApp({
    super.key,
    required this.observations,
    required this.observationService,
    required this.drafts,
    this.validator = const ObservationValidator(),
    this.initialVariant = CieloTheme.defaultVariant,
    this.clock,
    this.locationService,
    this.mediaService,
    this.recorder,
    this.player,
    this.provinceMap,
    this.maintenance,
    this.settings,
    this.lock,
    this.profile,
    this.stats,
    this.backup,
    this.documents,
    this.eraseAll,
    this.pendingErase = false,
  });

  final ObservationRepository observations;
  final ObservationService observationService;
  final DraftService drafts;
  final ObservationValidator validator;
  final CieloThemeVariant initialVariant;
  final DateTime Function()? clock;
  final LocationService? locationService;
  final MediaService? mediaService;
  final VoiceRecorder? recorder;
  final AudioPlayerService? player;
  final OfflineProvinceMap? provinceMap;
  final MediaMaintenance? maintenance;

  /// Hito C. Sin ellos, la app funciona como en el Hito B.
  final SettingsController? settings;
  final AppLockController? lock;
  final ProfileRepository? profile;
  final StatsService? stats;
  final BackupService? backup;
  final DocumentGateway? documents;
  final EraseAllService? eraseAll;

  /// Un borrado anterior no se completó ni al reintentarlo en el arranque.
  final bool pendingErase;

  @override
  State<CieloApp> createState() => _CieloAppState();
}

class _CieloAppState extends State<CieloApp> {
  // Tema sin persistencia: solo se usa si no hay [SettingsController].
  late CieloThemeVariant _variant = widget.initialVariant;
  late final GoRouter _router = _buildRouter();
  late final BackButtonDispatcher _backDispatcher = _LockAwareBackDispatcher(
    () => _isCovered,
  );
  final _DataReset _dataReset = _DataReset();

  /// El bloqueo o un fallo de arranque tapan la app por completo.
  bool get _isCovered =>
      widget.settings?.loadFailure != null || (widget.lock?.isLocked ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.lock?.attach();
      widget.lock?.unlock();
      if (widget.pendingErase && widget.eraseAll != null) {
        _router.push(CieloRoutes.eraseAll);
      }
    });
  }

  @override
  void dispose() {
    _router.dispose();
    _dataReset.dispose();
    super.dispose();
  }

  void _onDataErased() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    widget.settings?.resetToDefaults();
    _dataReset.notify();
  }

  GoRouter _buildRouter() => GoRouter(
    initialLocation: CieloRoutes.diary,
    routes: <RouteBase>[
      GoRoute(
        path: CieloRoutes.diary,
        builder: (BuildContext context, GoRouterState state) => DiaryScreen(
          observations: widget.observations,
          clock: widget.clock,
          onOpenObservation: (BuildContext c, Observation o) =>
              c.push<bool>(CieloRoutes.detail(o.id), extra: o),
          onCreateObservation: _create,
          resolveMediaPath: widget.mediaService?.resolveThumbnailPath,
          dataReset: _dataReset,
          appBarActions: <Widget>[
            if (widget.provinceMap != null)
              IconButton(
                tooltip: CieloStrings.offlineMap,
                onPressed: () => context.push(CieloRoutes.map),
                icon: const Icon(Icons.map_rounded),
              ),
            if (widget.stats != null)
              IconButton(
                tooltip: CieloStrings.statsTitle,
                onPressed: () => context.push(CieloRoutes.stats),
                icon: const Icon(Icons.insights_rounded),
              ),
            _ThemeMenu(settings: widget.settings, onSelected: _setTheme),
            if (widget.settings != null)
              IconButton(
                tooltip: CieloStrings.settingsTitle,
                onPressed: () => context.push(CieloRoutes.settings),
                icon: const Icon(Icons.settings_rounded),
              ),
          ],
        ),
      ),
      GoRoute(
        path: CieloRoutes.newObservation,
        builder: (BuildContext context, GoRouterState state) =>
            ObservationFormScreen(
              service: widget.observationService,
              drafts: widget.drafts,
              validator: widget.validator,
              prefill: state.extra is ObservationInput
                  ? state.extra! as ObservationInput
                  : null,
              clock: widget.clock,
              locationService: widget.locationService,
              mediaService: widget.mediaService,
              recorder: widget.recorder,
              provinceMap: widget.provinceMap,
              maintenance: widget.maintenance,
            ),
      ),
      GoRoute(
        path: '/observacion/:id',
        builder: (BuildContext context, GoRouterState state) =>
            ObservationDetailScreen(
              observationId: state.pathParameters['id']!,
              observations: widget.observations,
              initial: state.extra is Observation
                  ? state.extra! as Observation
                  : null,
              service: widget.observationService,
              resolveMediaPath: widget.mediaService?.resolveLocalPath,
              mediaService: widget.mediaService,
              player: widget.player,
              provinceMap: widget.provinceMap,
              maintenance: widget.maintenance,
              onEdit: (BuildContext c, Observation o) =>
                  c.push<Observation>(CieloRoutes.edit(o.id), extra: o),
            ),
      ),
      if (widget.provinceMap != null)
        GoRoute(
          path: CieloRoutes.map,
          builder: (context, state) => ObservationMapScreen(
            map: widget.provinceMap!,
            observations: widget.observations,
          ),
        ),
      ..._hitoCRoutes(),
      GoRoute(
        path: '/observacion/:id/editar',
        builder: (BuildContext context, GoRouterState state) => _EditRoute(
          id: state.pathParameters['id']!,
          initial: state.extra is Observation
              ? state.extra! as Observation
              : null,
          app: widget,
        ),
      ),
    ],
  );

  List<RouteBase> _hitoCRoutes() {
    final SettingsController? settings = widget.settings;
    final ProfileRepository? profile = widget.profile;
    final StatsService? stats = widget.stats;
    final BackupService? backup = widget.backup;
    final DocumentGateway? documents = widget.documents;
    final EraseAllService? eraseAll = widget.eraseAll;
    final bool canBackup = backup != null && documents != null;
    return <RouteBase>[
      if (stats != null)
        GoRoute(
          path: CieloRoutes.stats,
          builder: (BuildContext context, GoRouterState state) =>
              StatsScreen(stats: stats, clock: widget.clock),
        ),
      if (settings != null)
        GoRoute(
          path: CieloRoutes.settings,
          builder: (BuildContext context, GoRouterState state) =>
              SettingsScreen(
                settings: settings,
                lock: widget.lock,
                onExport: canBackup
                    ? (BuildContext c) => c.push(CieloRoutes.export)
                    : null,
                onImport: canBackup
                    ? (BuildContext c) => c.push(CieloRoutes.import)
                    : null,
                onEraseAll: eraseAll != null
                    ? (BuildContext c) => c.push(CieloRoutes.eraseAll)
                    : null,
                onEditProfile: profile != null ? _editProfile : null,
                onAbout: profile != null
                    ? (BuildContext c) => c.push(CieloRoutes.about)
                    : null,
              ),
        ),
      if (backup != null && documents != null) ...<RouteBase>[
        GoRoute(
          path: CieloRoutes.export,
          builder: (BuildContext context, GoRouterState state) => ExportScreen(
            backup: backup,
            documents: documents,
            clock: widget.clock,
          ),
        ),
        GoRoute(
          path: CieloRoutes.import,
          builder: (BuildContext context, GoRouterState state) => ImportScreen(
            backup: backup,
            documents: documents,
            onImported: _dataReset.notify,
          ),
        ),
      ],
      if (eraseAll != null)
        GoRoute(
          path: CieloRoutes.eraseAll,
          builder: (BuildContext context, GoRouterState state) =>
              EraseAllScreen(
                service: eraseAll,
                interrupted: widget.pendingErase,
                onDataErased: _onDataErased,
                onGoToDiary: () => _router.go(CieloRoutes.diary),
                onExportFirst: canBackup
                    ? (BuildContext c) => c.push(CieloRoutes.export)
                    : null,
              ),
        ),
      if (profile != null) ...<RouteBase>[
        GoRoute(
          path: CieloRoutes.about,
          builder: (BuildContext context, GoRouterState state) => AboutScreen(
            repository: profile,
            resolveMediaPath: widget.mediaService?.resolveLocalPath,
            onEditProfile: (BuildContext c) =>
                c.push<ObserverProfile>(CieloRoutes.profile),
          ),
        ),
        GoRoute(
          path: CieloRoutes.profile,
          builder: (BuildContext context, GoRouterState state) =>
              ProfileEditScreen(
                repository: profile,
                media: widget.mediaService,
                maintenance: widget.maintenance,
              ),
        ),
      ],
    ];
  }

  Future<void> _editProfile(BuildContext context) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final ObserverProfile? saved = await context.push<ObserverProfile>(
      CieloRoutes.profile,
    );
    if (saved == null) return;
    messenger?.showSnackBar(
      const SnackBar(content: Text(CieloStrings.profileSaved)),
    );
  }

  Future<void> _setTheme(AppTheme theme) async {
    final SettingsController? settings = widget.settings;
    if (settings == null) {
      setState(() => _variant = _variantOf(theme));
    } else {
      await settings.update((AppSettings s) => s.copyWith(theme: theme));
    }
  }

  static CieloThemeVariant _variantOf(AppTheme theme) => switch (theme) {
    AppTheme.system || AppTheme.night => CieloThemeVariant.night,
    AppTheme.day => CieloThemeVariant.day,
    AppTheme.astronomer => CieloThemeVariant.astro,
  };

  /// Botón "Registrar": registro rápido; desde ahí, formulario completo.
  Future<bool?> _create(BuildContext context) async {
    final QuickRecordResult? result = await showQuickRecordSheet(
      context,
      drafts: widget.drafts,
      clock: widget.clock,
      locationService: widget.locationService,
    );
    if (!context.mounted) return false;
    switch (result) {
      case QuickRecordSaved():
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text(CieloStrings.draftSaved)));
        return true;
      case QuickRecordOpenFullForm(:final ObservationInput prefill):
        final Observation? saved = await context.push<Observation>(
          CieloRoutes.newObservation,
          extra: prefill,
        );
        return saved != null;
      case null:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(<Listenable?>[widget.settings, widget.lock]),
    builder: (BuildContext context, _) => _app(),
  );

  ThemeData _theme(CieloThemeVariant variant) {
    final ThemeData theme = CieloTheme.build(variant);
    return widget.settings?.settings.reducedMotion ?? false
        ? theme.copyWith(pageTransitionsTheme: _noTransitions)
        : theme;
  }

  static final PageTransitionsTheme _noTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      for (final TargetPlatform platform in TargetPlatform.values)
        platform: const _NoTransitionBuilder(),
    },
  );

  Widget _app() {
    final AppSettings? settings = widget.settings?.settings;
    final bool system = settings?.theme == AppTheme.system;
    return MaterialApp.router(
      title: CieloStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: _theme(
        system
            ? CieloThemeVariant.day
            : settings == null
            ? _variant
            : _variantOf(settings.theme),
      ),
      darkTheme: system ? _theme(CieloThemeVariant.night) : null,
      themeMode: system ? ThemeMode.system : ThemeMode.light,
      // Sin interpolación entre temas: evita colores no rojos al entrar o
      // salir del modo astrónomo.
      themeAnimationDuration: Duration.zero,
      locale: const Locale('es', 'DO'),
      supportedLocales: const <Locale>[Locale('es', 'DO'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerDelegate: _router.routerDelegate,
      routeInformationParser: _router.routeInformationParser,
      routeInformationProvider: _router.routeInformationProvider,
      backButtonDispatcher: _backDispatcher,
      builder: (BuildContext context, Widget? child) => _AppShell(
        settings: widget.settings,
        lock: widget.lock,
        covered: _isCovered,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

final class _DataReset extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Con la app tapada, "atrás" sale de la app en lugar de navegar por debajo.
class _LockAwareBackDispatcher extends RootBackButtonDispatcher {
  _LockAwareBackDispatcher(this._covered);
  final bool Function() _covered;

  @override
  Future<bool> didPopRoute() async {
    if (_covered()) {
      await SystemNavigator.pop();
      return true;
    }
    return super.didPopRoute();
  }
}

class _NoTransitionBuilder extends PageTransitionsBuilder {
  const _NoTransitionBuilder();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Aplica el movimiento reducido y tapa la app mientras esté bloqueada. El
/// contenido se conserva debajo, sin pintarse, sin foco y fuera del árbol de
/// accesibilidad.
class _AppShell extends StatelessWidget {
  const _AppShell({
    required this.settings,
    required this.lock,
    required this.covered,
    required this.child,
  });

  final SettingsController? settings;
  final AppLockController? lock;
  final bool covered;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final SettingsController? settings = this.settings;
    return MediaQuery(
      data: media.copyWith(
        disableAnimations:
            media.disableAnimations ||
            (settings?.settings.reducedMotion ?? false),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Offstage(
            offstage: covered,
            child: TickerMode(
              enabled: !covered,
              child: ExcludeFocus(excluding: covered, child: child),
            ),
          ),
          if (settings?.loadFailure != null)
            Scaffold(
              body: SafeArea(
                child: CieloErrorState(
                  title: CieloStrings.startupFailureTitle,
                  message: CieloStrings.startupFailureMessage,
                  onRetry: settings!.load,
                ),
              ),
            )
          else if (lock?.isLocked ?? false)
            LockScreen(controller: lock!),
        ],
      ),
    );
  }
}

/// Edición: usa la observación recibida o la carga si se llegó sin ella.
class _EditRoute extends StatelessWidget {
  const _EditRoute({
    required this.id,
    required this.initial,
    required this.app,
  });

  final String id;
  final Observation? initial;
  final CieloApp app;

  @override
  Widget build(BuildContext context) {
    final Observation? ready = initial;
    if (ready != null) return _form(ready);
    return FutureBuilder<Result<Observation>>(
      future: app.observations.getById(id),
      builder: (BuildContext context, AsyncSnapshot<Result<Observation>> snap) {
        final Result<Observation>? r = snap.data;
        if (r is Success<Observation>) return _form(r.value);
        return Scaffold(
          appBar: AppBar(title: const Text(CieloStrings.editObservation)),
          body: r is Failure<Observation>
              ? CieloErrorState(message: CieloStrings.errorNotFound)
              : const Padding(
                  padding: EdgeInsets.all(CieloSpace.gutter),
                  child: CieloSkeletonList(count: 1),
                ),
        );
      },
    );
  }

  Widget _form(Observation o) => ObservationFormScreen(
    service: app.observationService,
    drafts: app.drafts,
    validator: app.validator,
    initial: o,
    clock: app.clock,
    locationService: app.locationService,
    mediaService: app.mediaService,
    recorder: app.recorder,
    provinceMap: app.provinceMap,
    maintenance: app.maintenance,
  );
}

/// Cambio rápido de tema desde la barra del Diario.
class _ThemeMenu extends StatelessWidget {
  const _ThemeMenu({required this.settings, required this.onSelected});

  final SettingsController? settings;
  final ValueChanged<AppTheme> onSelected;

  @override
  Widget build(BuildContext context) {
    // Se lee del tema vigente: la ruta no se reconstruye al cambiar de tema.
    final AppTheme current =
        settings?.settings.theme ??
        switch (CieloColors.of(context).variant) {
          CieloThemeVariant.night => AppTheme.night,
          CieloThemeVariant.day => AppTheme.day,
          CieloThemeVariant.astro => AppTheme.astronomer,
        };
    return PopupMenuButton<AppTheme>(
      tooltip: CieloStrings.themeMenu,
      icon: Icon(SettingsScreen.themes[current]!.$2),
      initialValue: current,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<AppTheme>>[
        for (final MapEntry<AppTheme, (String, IconData)> e
            in SettingsScreen.themes.entries)
          // "Sistema" necesita preferencias persistentes.
          if (settings != null || e.key != AppTheme.system)
            CheckedPopupMenuItem<AppTheme>(
              value: e.key,
              checked: e.key == current,
              child: Text(e.value.$1),
            ),
      ],
    );
  }
}
