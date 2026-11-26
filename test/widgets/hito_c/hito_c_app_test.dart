import 'package:cielo_rd/app/cielo_app.dart';
import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/design/design.dart';
import 'package:cielo_rd/features/observations/presentation/diary/diary_screen.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:cielo_rd/features/security/application/app_lock_controller.dart';
import 'package:cielo_rd/features/security/presentation/lock_screen.dart';
import 'package:cielo_rd/features/settings/application/settings_controller.dart';
import 'package:cielo_rd/features/settings/presentation/settings_screen.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/hito_c_fakes.dart';

final class _Harness {
  _Harness({AppSettings? initial, AppFailure? getFailure})
    : repository = MemorySettings(initial)..getFailure = getFailure;

  final MemorySettings repository;
  final auth = FakeAuth();
  final erase = FakeErase();
  final backup = FakeBackup();
  final store = InMemoryObservationRepository(
    clock: () => DateTime.utc(2026, 11, 23, 22),
  );
  late final SettingsController settings = SettingsController(
    repository: repository,
  );
  late final AppLockController lock;

  Future<void> pump(WidgetTester tester, {bool pendingErase = false}) async {
    tester.view
      ..physicalSize = const Size(400, 900) * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await settings.load();
    lock = AppLockController(
      settings: settings,
      auth: auth,
      unlockReason: CieloStrings.lockReasonOpen,
    );
    addTearDown(() {
      lock.dispose();
      settings.dispose();
    });
    await tester.pumpWidget(
      CieloApp(
        observations: store,
        observationService: store,
        drafts: store,
        clock: () => DateTime(2026, 11, 23, 18),
        settings: settings,
        lock: lock,
        profile: MemoryProfile(),
        stats: FakeStats(Success(sampleStats())),
        backup: backup,
        documents: FakeDocuments(),
        eraseAll: erase,
        pendingErase: pendingErase,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> publish(String title) async {
    await store.create(
      ObservationInput(
        title: title,
        observedAt: DateTime.utc(2026, 11, 22, 2),
        utcOffsetMinutes: -240,
        category: ObservationCategory.astronomy,
      ),
      status: ObservationStatus.published,
    );
  }
}

CieloThemeVariant _variant(WidgetTester tester) =>
    CieloColors.of(tester.element(find.byType(Scaffold).last)).variant;

void main() {
  testWidgets('Diario → Estadísticas, Ajustes y Acerca de', (tester) async {
    final app = _Harness();
    await app.pump(tester);
    await tester.tap(find.byTooltip(CieloStrings.statsTitle));
    await tester.pumpAndSettle();
    expect(find.text('24'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(CieloStrings.settingsTitle));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(CieloStrings.aboutTitle), 200);
    await tester.tap(find.text(CieloStrings.aboutTitle));
    await tester.pumpAndSettle();
    expect(find.text(CieloStrings.profileEmpty), findsOneWidget);
    await tester.tap(find.text(CieloStrings.profileEdit));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, CieloStrings.profileStudentId),
      '00-PRUEBA',
    );
    await tester.pump();
    await tester.tap(find.text(CieloStrings.save));
    await tester.pumpAndSettle();
    expect(find.text('00-PRUEBA'), findsOneWidget);
    expect(find.text(CieloStrings.profileEmpty), findsNothing);
  });

  testWidgets('tema desde el menú del Diario: se aplica y se guarda', (
    tester,
  ) async {
    final app = _Harness();
    await app.pump(tester);
    expect(_variant(tester), CieloThemeVariant.night);
    await tester.tap(find.byTooltip(CieloStrings.themeMenu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        CheckedPopupMenuItem<AppTheme>,
        CieloStrings.themeAstro,
      ),
    );
    await tester.pumpAndSettle();
    expect(_variant(tester), CieloThemeVariant.astro);
    expect(app.repository.value.theme, AppTheme.astronomer);
  });

  testWidgets('tema Sistema sigue el brillo del teléfono', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final app = _Harness(initial: AppSettings(theme: AppTheme.system));
    await app.pump(tester);
    expect(_variant(tester), CieloThemeVariant.night);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(_variant(tester), CieloThemeVariant.day);
  });

  testWidgets('el tema guardado se aplica al abrir', (tester) async {
    final app = _Harness(initial: AppSettings(theme: AppTheme.day));
    await app.pump(tester);
    expect(_variant(tester), CieloThemeVariant.day);
  });

  testWidgets('movimiento reducido llega a MediaQuery y a las rutas', (
    tester,
  ) async {
    final app = _Harness(initial: AppSettings(reducedMotion: true));
    await app.pump(tester);
    expect(
      CieloMotion.isReduced(tester.element(find.byType(DiaryScreen))),
      isTrue,
    );
    await tester.tap(find.byTooltip(CieloStrings.settingsTitle));
    await tester.pump();
    await tester.pump();
    final double x = tester.getTopLeft(find.byType(SettingsScreen)).dx;
    expect(x, 0, reason: 'sin transición: ya está en su sitio');
    await app.settings.update((s) => s.copyWith(reducedMotion: false));
    await tester.pumpAndSettle();
    expect(
      CieloMotion.isReduced(tester.element(find.byType(SettingsScreen))),
      isFalse,
    );
  });

  testWidgets('bloqueada al abrir: no se ve ni se lee el Diario', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final app = _Harness(initial: AppSettings(authenticationEnabled: true));
    app.auth.outcome = AuthOutcome.cancelled;
    await app.publish('Observación secreta');
    await app.pump(tester);
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('Observación secreta'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Observación secreta')), findsNothing);
    expect(app.auth.reasons, [CieloStrings.lockReasonOpen]);
    app.auth.outcome = AuthOutcome.success;
    await tester.tap(find.text(CieloStrings.lockUnlock));
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsNothing);
    expect(find.text('Observación secreta'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'al volver de segundo plano se bloquea y conserva el formulario',
    (tester) async {
      final app = _Harness(initial: AppSettings(authenticationEnabled: true));
      await app.pump(tester);
      await tester.tap(find.byTooltip(CieloStrings.settingsTitle));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(CieloStrings.profileTitle),
        200,
      );
      await tester.tap(find.text(CieloStrings.profileTitle));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, CieloStrings.profileFirstName),
        'A medias',
      );
      app.auth.outcome = AuthOutcome.cancelled;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.text('A medias'), findsNothing);

      // "Atrás" no navega por debajo del bloqueo.
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(calls, contains('SystemNavigator.pop'));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );

      app.auth.outcome = AuthOutcome.success;
      await tester.tap(find.text(CieloStrings.lockUnlock));
      await tester.pumpAndSettle();
      expect(find.text('A medias'), findsOneWidget);
    },
  );

  testWidgets('preferencias ilegibles: no se abre hasta poder leerlas', (
    tester,
  ) async {
    final app = _Harness(
      initial: AppSettings(authenticationEnabled: true),
      getFailure: AppFailure(FailureCode.persistence),
    );
    await app.publish('Observación secreta');
    await app.pump(tester);
    expect(find.text(CieloStrings.startupFailureTitle), findsOneWidget);
    expect(find.text('Observación secreta'), findsNothing);
    app.repository.getFailure = null;
    app.auth.outcome = AuthOutcome.cancelled;
    await tester.tap(find.text(CieloStrings.retry));
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsOneWidget);
  });

  testWidgets('Borrar todo: preferencias y Diario vuelven al inicio', (
    tester,
  ) async {
    final app = _Harness(initial: AppSettings(theme: AppTheme.day));
    await app.publish('Se borrará');
    await app.pump(tester);
    expect(find.text('Se borrará'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Se bor');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(CieloStrings.settingsTitle));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(CieloStrings.eraseAllAction),
      200,
    );
    await tester.tap(find.text(CieloStrings.eraseAllAction));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, CieloStrings.eraseAllAction),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    final page = (await app.store.list(
      filter: ObservationFilter(status: null),
    ) as Success<ObservationPage>).value;
    for (final o in page.items) {
      await app.store.delete(o.id, expectedRevision: o.revision);
    }
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(
          FilledButton,
          CieloStrings.eraseAllAction,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(app.settings.settings.theme, AppTheme.night);
    await tester.tap(find.text(CieloStrings.goToDiary));
    await tester.pumpAndSettle();
    expect(find.text(CieloStrings.emptyDiaryTitle), findsOneWidget);
    expect(find.text('Se bor'), findsNothing, reason: 'la búsqueda se limpia');
    expect(_variant(tester), CieloThemeVariant.night);
  });

  testWidgets('importar recarga el Diario', (tester) async {
    final app = _Harness();
    app.backup
      ..inspectResult = Success(
        BackupInspection(
          token: 't',
          formatVersion: 1,
          observationCount: 1,
          mediaCount: 0,
          uncompressedBytes: 1,
          newCount: 1,
        ),
      )
      ..importResult = const Success(
        ImportReport(importedObservations: 1, importedMedia: 0),
      );
    await app.pump(tester);
    expect(find.text(CieloStrings.emptyDiaryTitle), findsOneWidget);
    await tester.tap(find.byTooltip(CieloStrings.settingsTitle));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(CieloStrings.importTitle), 200);
    await tester.tap(find.text(CieloStrings.importTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CieloStrings.importChoose));
    await tester.pumpAndSettle();
    await app.publish('Recuperada');
    await tester.tap(
      find.widgetWithText(FilledButton, CieloStrings.importTitle),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(CieloStrings.done));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Recuperada'), findsOneWidget);
  });

  testWidgets('borrado interrumpido: se ofrece terminarlo al abrir', (
    tester,
  ) async {
    final app = _Harness();
    await app.pump(tester, pendingErase: true);
    expect(find.text(CieloStrings.erasePendingMessage), findsOneWidget);
    expect(find.text(CieloStrings.eraseFinish), findsOneWidget);
  });
}
