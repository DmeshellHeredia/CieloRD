import 'dart:async';
import 'dart:io';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/design/design.dart';
import 'package:cielo_rd/features/backup/presentation/export_screen.dart';
import 'package:cielo_rd/features/backup/presentation/import_screen.dart';
import 'package:cielo_rd/features/maintenance/presentation/erase_all_screen.dart';
import 'package:cielo_rd/features/profile/presentation/about_screen.dart';
import 'package:cielo_rd/features/profile/presentation/profile_edit_screen.dart';
import 'package:cielo_rd/features/security/application/app_lock_controller.dart';
import 'package:cielo_rd/features/security/presentation/lock_screen.dart';
import 'package:cielo_rd/features/settings/application/settings_controller.dart';
import 'package:cielo_rd/features/settings/presentation/settings_screen.dart';
import 'package:cielo_rd/features/statistics/presentation/stats_screen.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:cielo_rd/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/hito_c_fakes.dart';
import '../helpers/pump_cielo.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  CieloThemeVariant variant = CieloThemeVariant.night,
  double scale = 1,
  Size size = kPhoneSize,
}) async {
  await pumpCielo(
    tester,
    screen,
    variant: variant,
    textScale: scale,
    size: size,
    wrapInScaffold: false,
  );
  await tester.pumpAndSettle();
}

/// Recorre toda la pantalla para que cualquier desborde aparezca.
Future<void> _scrollThrough(WidgetTester tester) async {
  final Finder lists = find.byType(Scrollable);
  if (lists.evaluate().isEmpty) return;
  for (int i = 0; i < 12; i++) {
    await tester.drag(lists.first, const Offset(0, -400), warnIfMissed: false);
    await tester.pump();
  }
  expect(tester.takeException(), isNull);
}

final DateTime _now = DateTime(2026, 11, 23, 20);

BackupInspection _inspection({int fresh = 3, int copies = 1}) =>
    BackupInspection(
      token: 'token-1',
      formatVersion: 1,
      observationCount: 6,
      draftCount: 1,
      mediaCount: 9,
      photoCount: 7,
      audioCount: 2,
      uncompressedBytes: 1000,
      appVersion: '1.0.0',
      createdAt: DateTime.utc(2026, 11, 20, 16),
      newCount: fresh,
      copyCount: copies,
      identicalCount: 2,
      hasProfile: true,
      warnings: const ['missing_media:2'],
    );

SettingsController _settings([AppSettings? initial]) {
  final controller = SettingsController(
    repository: MemorySettings(initial),
    initial: initial,
  );
  addTearDown(controller.dispose);
  return controller;
}

AppLockController _lock(SettingsController settings, FakeAuth auth) {
  final controller = AppLockController(
    settings: settings,
    auth: auth,
    unlockReason: CieloStrings.lockReasonOpen,
  );
  addTearDown(controller.dispose);
  return controller;
}

Widget _erase(FakeErase service, {VoidCallback? onErased}) => EraseAllScreen(
  service: service,
  onDataErased: onErased ?? () {},
  onGoToDiary: () {},
  onExportFirst: (_) {},
);

void main() {
  group('3 temas × 200 %, sin desbordes y accesibles', () {
    final screens = <String, Widget Function()>{
      'estadísticas': () => StatsScreen(
        stats: FakeStats(Success(sampleStats())),
        clock: () => _now,
      ),
      'estadísticas vacías': () => StatsScreen(
        stats: FakeStats(
          Success(
            ObservationStats(
              total: 0,
              knownDurationSeconds: 0,
              withKnownDuration: 0,
              byCategory: const {},
              byLocalDate: const {},
              byLocalHour: const {},
              byProvince: const {},
            ),
          ),
        ),
      ),
      'estadísticas con error': () => StatsScreen(
        stats: FakeStats(Failure(AppFailure(FailureCode.persistence))),
      ),
      'ajustes': () {
        final settings = _settings();
        return SettingsScreen(
          settings: settings,
          lock: _lock(settings, FakeAuth()),
          onExport: (_) {},
          onImport: (_) {},
          onEraseAll: (_) {},
          onEditProfile: (_) {},
          onAbout: (_) {},
        );
      },
      'perfil': () => ProfileEditScreen(
        repository: MemoryProfile(
          const ObserverProfile(firstName: 'Persona', motto: 'Mirar arriba'),
        ),
        media: FakeMediaService(),
      ),
      'acerca de vacío': () => AboutScreen(
        repository: MemoryProfile(),
        onEditProfile: (_) async => null,
      ),
      'acerca de completo': () => AboutScreen(
        repository: MemoryProfile(
          ObserverProfile(
            firstName: 'Nombre' * 6,
            lastName: 'Apellido Compuesto',
            studentId: '00-PRUEBA',
            motto: 'Una frase de prueba bastante larga ' * 4,
          ),
        ),
      ),
      'exportar': () =>
          ExportScreen(backup: FakeBackup(), documents: FakeDocuments()),
      'importar': () =>
          ImportScreen(backup: FakeBackup(), documents: FakeDocuments()),
      'borrar todo': () => _erase(FakeErase()),
      'bloqueo': () {
        final settings = _settings(AppSettings(authenticationEnabled: true));
        return LockScreen(controller: _lock(settings, FakeAuth()));
      },
    };
    for (final entry in screens.entries) {
      forEachThemeAndScale(entry.key, (tester, variant, scale) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        await _pump(tester, entry.value(), variant: variant, scale: scale);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await _scrollThrough(tester);
        semantics.dispose();
      }, scales: const [1, 2]);
    }
  });

  group('Estadísticas', () {
    testWidgets('cifras, categorías con texto y exclusión de borradores', (
      tester,
    ) async {
      final stats = FakeStats(Success(sampleStats()));
      await _pump(
        tester,
        StatsScreen(stats: stats, clock: () => _now),
        size: const Size(400, 3000),
      );
      expect(stats.lastFilter!.status, ObservationStatus.published);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('13'), findsOneWidget, reason: 'noviembre: 5 + 8');
      expect(find.text('Noviembre de 2026'), findsOneWidget);
      expect(find.textContaining('1'), findsWidgets);
      expect(find.text(CieloStrings.statsDraftsExcluded), findsOneWidget);
      expect(find.text(CieloStrings.categoryAstronomy), findsOneWidget);
      expect(find.text('La Vega'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          '${CieloStrings.categoryAstronomy}: 14 observaciones',
        ),
        findsOneWidget,
      );
      // Categoría sin registros: se muestra con 0, no se oculta.
      expect(
        find.bySemanticsLabel('${CieloStrings.categoryOther}: 0 observaciones'),
        findsOneWidget,
      );
    });

    testWidgets('el gráfico se lee, se toca y tiene tabla equivalente', (
      tester,
    ) async {
      await _pump(
        tester,
        StatsScreen(
          stats: FakeStats(Success(sampleStats())),
          clock: () => _now,
        ),
        size: const Size(400, 3000),
      );
      final Finder chart = find.bySemanticsLabel(
        RegExp('^${CieloStrings.statsByMonth}\\. Máximo: Noviembre de 2026'),
      );
      expect(chart, findsOneWidget);
      final Rect box = tester.getRect(chart);
      await tester.tapAt(Offset(box.left + 4, box.center.dy));
      await tester.pump();
      expect(find.text('Diciembre de 2025: 0 observaciones'), findsOneWidget);
      await tester.tap(find.text(CieloStrings.statsShowTable).first);
      await tester.pump();
      expect(find.text('Septiembre de 2026'), findsOneWidget);
      expect(find.text('Diciembre de 2025'), findsOneWidget);
      expect(find.text(CieloStrings.statsShowChart), findsOneWidget);
    });

    testWidgets('error con reintento', (tester) async {
      final stats = FakeStats(Failure(AppFailure(FailureCode.persistence)));
      await _pump(tester, StatsScreen(stats: stats));
      stats.result = Success(sampleStats());
      await tester.tap(find.text(CieloStrings.retry));
      await tester.pumpAndSettle();
      expect(stats.calls, 2);
      expect(find.text('24'), findsOneWidget);
    });
  });

  group('Perfil y Acerca de', () {
    testWidgets('sin datos muestra una acción para recrear el perfil', (
      tester,
    ) async {
      await _pump(
        tester,
        AboutScreen(
          repository: MemoryProfile(),
          onEditProfile: (_) async => null,
        ),
        size: const Size(400, 1400),
      );
      expect(find.text(CieloStrings.profileEmpty), findsOneWidget);
      expect(find.text(CieloStrings.profileEdit), findsOneWidget);
      expect(
        find.bySemanticsLabel(CieloStrings.profilePhotoEmpty),
        findsOneWidget,
      );
      expect(find.textContaining('pendiente'), findsNothing);
      expect(find.textContaining('1.0.0'), findsOneWidget);
      expect(find.textContaining('Natural Earth'), findsOneWidget);
      expect(find.textContaining('SIL Open Font License'), findsOneWidget);
      expect(find.text(CieloStrings.aboutLicensesAll), findsOneWidget);
    });

    testWidgets('Acerca de muestra la identidad y foto definitivas', (
      tester,
    ) async {
      await _pump(
        tester,
        AboutScreen(
          repository: MemoryProfile(
            const ObserverProfile(
              firstName: 'Michael Dmeshell',
              lastName: 'Sanchez Heredia',
              studentId: '2024-0063',
              motto: '«¡Quiero vivir!» — Nico Robin',
              photoMediaId: 'perfil-final',
            ),
          ),
          resolveMediaPath: (_) async => Success(
            File('assets/profile/michael_heredia.webp').absolute.path,
          ),
        ),
        size: const Size(400, 1400),
      );
      expect(
        find.text('Michael Dmeshell Sanchez Heredia'),
        findsOneWidget,
      );
      expect(find.text('2024-0063'), findsOneWidget);
      expect(find.text('«¡Quiero vivir!» — Nico Robin'), findsOneWidget);
      expect(
        find.bySemanticsLabel(CieloStrings.profilePhoto),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('editar, guardar con foto y confirmar el adjunto', (
      tester,
    ) async {
      final repository = MemoryProfile();
      final media = FakeMediaService();
      ObserverProfile? returned;
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                returned = await Navigator.of(context).push<ObserverProfile>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfileEditScreen(repository: repository, media: media),
                  ),
                ),
            child: const Text('abrir'),
          ),
        ),
        size: const Size(400, 1400),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, CieloStrings.profileFirstName),
        'Persona',
      );
      await tester.enterText(
        find.widgetWithText(TextField, CieloStrings.profileStudentId),
        '00-PRUEBA',
      );
      // Elegir dos veces: la primera foto se descarta.
      await tester.tap(find.text(CieloStrings.profilePhotoGallery));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CieloStrings.profilePhotoGallery));
      await tester.pumpAndSettle();
      expect(media.discarded, ['photo-1']);
      await tester.tap(find.text(CieloStrings.save));
      await tester.pumpAndSettle();
      expect(repository.value!.firstName, 'Persona');
      expect(repository.value!.studentId, '00-PRUEBA');
      expect(repository.lastPhoto!.id, 'photo-2');
      expect(media.committed, ['photo-2']);
      expect(returned, isNotNull);
      expect(media.discarded, ['photo-1']);
    });

    testWidgets('salir con cambios pide confirmación y descarta la foto', (
      tester,
    ) async {
      final repository = MemoryProfile();
      final media = FakeMediaService();
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ProfileEditScreen(repository: repository, media: media),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CieloStrings.profilePhotoGallery));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CieloStrings.keepEditing));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CieloStrings.discardChanges));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditScreen), findsNothing);
      expect(media.discarded, ['photo-1']);
      expect(repository.value, isNull);
    });

    testWidgets('errores por campo y general', (tester) async {
      final repository = MemoryProfile();
      await _pump(
        tester,
        ProfileEditScreen(repository: repository),
        size: const Size(400, 1400),
      );
      await tester.enterText(
        find.widgetWithText(TextField, CieloStrings.profileMotto),
        'x',
      );
      repository.failure = AppFailure(
        FailureCode.validation,
        fieldErrors: {'motto': 'too_long'},
      );
      await tester.pump();
      await tester.tap(find.text(CieloStrings.save));
      await tester.pumpAndSettle();
      expect(find.text(CieloStrings.profileTooLong), findsOneWidget);
      repository.failure = AppFailure(FailureCode.storageFull);
      await tester.tap(find.text(CieloStrings.save));
      await tester.pumpAndSettle();
      expect(find.text(CieloStrings.errorStorageFull), findsOneWidget);
    });
  });

  group('Ajustes', () {
    testWidgets('los cuatro temas se guardan', (tester) async {
      final repository = MemorySettings();
      final settings = SettingsController(repository: repository);
      addTearDown(settings.dispose);
      await _pump(
        tester,
        SettingsScreen(settings: settings),
        size: const Size(400, 1400),
      );
      for (final entry in SettingsScreen.themes.entries) {
        await tester.tap(find.text(entry.value.$1));
        await tester.pumpAndSettle();
        expect(repository.value.theme, entry.key);
      }
      await tester.tap(find.text(CieloStrings.settingsReducedMotion));
      await tester.pumpAndSettle();
      expect(repository.value.reducedMotion, isTrue);
    });

    testWidgets('si no se puede guardar se avisa y se revierte', (
      tester,
    ) async {
      final repository = MemorySettings()
        ..saveFailure = AppFailure(FailureCode.storageFull);
      final settings = SettingsController(repository: repository);
      addTearDown(settings.dispose);
      await _pump(
        tester,
        SettingsScreen(settings: settings),
        size: const Size(400, 1400),
      );
      await tester.tap(find.text(CieloStrings.themeDay));
      await tester.pump();
      expect(find.text(CieloStrings.settingsSaveFailed), findsOneWidget);
      expect(settings.settings.theme, AppTheme.night);
      await tester.pumpAndSettle();
    });

    testWidgets('bloqueo: sin credenciales, cancelado y activado', (
      tester,
    ) async {
      final settings = _settings();
      final auth = FakeAuth(available: AuthAvailability.noCredentials);
      await _pump(
        tester,
        SettingsScreen(settings: settings, lock: _lock(settings, auth)),
        size: const Size(400, 1400),
      );
      expect(find.text(CieloStrings.settingsLockScope), findsOneWidget);
      Future<void> tapLock() async {
        await tester.tap(find.text(CieloStrings.settingsLock));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await tapLock();
      expect(find.text(CieloStrings.settingsLockNoCredentials), findsOneWidget);
      auth
        ..available = AuthAvailability.available
        ..outcome = AuthOutcome.cancelled;
      await tapLock();
      await tester.pumpAndSettle();
      expect(settings.settings.authenticationEnabled, isFalse);
      auth.outcome = AuthOutcome.success;
      await tapLock();
      expect(settings.settings.authenticationEnabled, isTrue);
      await tester.pumpAndSettle();
    });
  });

  group('Exportar', () {
    testWidgets('ZIP por defecto, incluye borradores y muestra el resultado', (
      tester,
    ) async {
      final backup = FakeBackup()
        ..exportResult = Success(
          BackupReceipt(
            destination: Uri.parse('content://x'),
            observationCount: 6,
            includesMedia: true,
            mediaCount: 9,
            missingMedia: 1,
          ),
        );
      final documents = FakeDocuments();
      await _pump(
        tester,
        ExportScreen(backup: backup, documents: documents, clock: () => _now),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.exportTitle),
      );
      await tester.pumpAndSettle();
      expect(documents.suggestedName, 'CieloRD-copia-2026-11-23-2000.zip');
      expect(backup.lastFormat, BackupFormat.zipComplete);
      expect(backup.lastFilter!.status, isNull);
      expect(backup.lastIncludeProfile, isTrue);
      expect(find.text(CieloStrings.exportDone), findsOneWidget);
      expect(
        find.textContaining('6 observaciones y 9 adjuntos'),
        findsOneWidget,
      );
      expect(
        find.textContaining(CieloStrings.exportMissing(1)),
        findsOneWidget,
      );
    });

    testWidgets('JSON sin perfil', (tester) async {
      final backup = FakeBackup()
        ..exportResult = Success(
          BackupReceipt(
            destination: Uri.parse('content://x'),
            observationCount: 6,
            includesMedia: false,
          ),
        );
      final documents = FakeDocuments();
      await _pump(
        tester,
        ExportScreen(backup: backup, documents: documents, clock: () => _now),
      );
      await tester.tap(find.text(CieloStrings.exportJson));
      await tester.tap(find.text(CieloStrings.exportIncludeProfile));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.exportTitle),
      );
      await tester.pumpAndSettle();
      expect(documents.suggestedName, endsWith('.json'));
      expect(backup.lastFormat, BackupFormat.jsonMetadata);
      expect(backup.lastIncludeProfile, isFalse);
    });

    testWidgets('cancelar no exporta; fallo se explica', (tester) async {
      final backup = FakeBackup();
      final documents = FakeDocuments()..created = null;
      await _pump(tester, ExportScreen(backup: backup, documents: documents));
      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.exportTitle),
      );
      await tester.pumpAndSettle();
      expect(backup.lastFormat, isNull);
      expect(find.text(CieloStrings.exportFailed), findsNothing);
      documents.created = Uri.parse('content://x');
      backup.exportResult = Failure(AppFailure(FailureCode.storageFull));
      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.exportTitle),
      );
      await tester.pumpAndSettle();
      expect(find.text(CieloStrings.exportFailed), findsOneWidget);
      documents.error = StateError('sin selector');
      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.exportTitle),
      );
      await tester.pumpAndSettle();
      expect(find.text(CieloStrings.failureIo), findsOneWidget);
    });

    testWidgets('mientras exporta no se puede salir', (tester) async {
      final backup = FakeBackup()
        ..hold = Completer<void>()
        ..exportResult = Failure(AppFailure(FailureCode.io));
      await _pump(
        tester,
        ExportScreen(backup: backup, documents: FakeDocuments()),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.exportTitle),
      );
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>)).canPop,
        isFalse,
      );
      backup.hold!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('Importar', () {
    testWidgets('revisa, muestra el contenido y solo entonces importa', (
      tester,
    ) async {
      var notified = 0;
      final backup = FakeBackup()
        ..inspectResult = Success(_inspection())
        ..importResult = const Success(
          ImportReport(
            importedObservations: 4,
            importedMedia: 7,
            importedAsCopies: 1,
            skippedIdentical: 2,
          ),
        );
      await _pump(
        tester,
        ImportScreen(
          backup: backup,
          documents: FakeDocuments(),
          onImported: () => notified++,
        ),
        size: const Size(400, 1600),
      );
      await tester.tap(find.text(CieloStrings.importChoose));
      await tester.pumpAndSettle();
      expect(backup.imports, 0);
      for (final text in [
        '6',
        '7',
        '1.0.0',
        CieloStrings.importNew(3),
        CieloStrings.importCopies(1),
        CieloStrings.importIdentical(2),
        CieloStrings.importProfileNo,
        CieloStrings.importMissing(2),
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.importTitle),
      );
      await tester.pumpAndSettle();
      expect(backup.imports, 1);
      expect(notified, 1);
      expect(find.text(CieloStrings.importDone), findsOneWidget);
      expect(backup.discarded, isEmpty);
    });

    testWidgets('nada nuevo: el botón queda deshabilitado', (tester) async {
      final backup = FakeBackup()
        ..inspectResult = Success(_inspection(fresh: 0, copies: 0));
      await _pump(
        tester,
        ImportScreen(backup: backup, documents: FakeDocuments()),
        size: const Size(400, 1600),
      );
      await tester.tap(find.text(CieloStrings.importChoose));
      await tester.pumpAndSettle();
      expect(find.text(CieloStrings.importNothing), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, CieloStrings.importTitle),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('cada motivo de rechazo tiene su explicación', (tester) async {
      final messages = {
        BackupErrors.notAZip: CieloStrings.importNotAZip,
        BackupErrors.unsafePath: CieloStrings.importUnsafe,
        BackupErrors.unexpectedEntry: CieloStrings.importUnexpected,
        BackupErrors.tooLarge: CieloStrings.importTooLarge,
        BackupErrors.hash: CieloStrings.importHash,
        BackupErrors.type: CieloStrings.importWrongType,
        BackupErrors.version: CieloStrings.errorImportNewer,
        BackupErrors.structure: CieloStrings.errorImportInvalid,
      };
      final backup = FakeBackup();
      await _pump(
        tester,
        ImportScreen(backup: backup, documents: FakeDocuments()),
        size: const Size(400, 1600),
      );
      for (final entry in messages.entries) {
        backup.inspectResult = Failure(
          AppFailure(
            FailureCode.corruptData,
            fieldErrors: {'backup': entry.key},
          ),
        );
        await tester.tap(find.text(CieloStrings.importChoose));
        await tester.pumpAndSettle();
        expect(find.textContaining(entry.value), findsOneWidget);
        expect(find.text(CieloStrings.importFailed), findsOneWidget);
      }
    });

    testWidgets('salir sin importar descarta la copia temporal', (
      tester,
    ) async {
      final backup = FakeBackup()..inspectResult = Success(_inspection());
      await _pump(
        tester,
        ImportScreen(backup: backup, documents: FakeDocuments()),
      );
      await tester.tap(find.text(CieloStrings.importChoose));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(backup.discarded, ['token-1']);
    });
  });

  group('Borrar todo', () {
    testWidgets('conteos, casilla obligatoria y éxito', (tester) async {
      final service = FakeErase();
      var erased = 0;
      await _pump(
        tester,
        _erase(service, onErased: () => erased++),
        size: const Size(400, 1600),
      );
      for (final text in [
        CieloStrings.erasePublished(12),
        CieloStrings.eraseDrafts(1),
        CieloStrings.eraseAllPhotos(30),
        CieloStrings.eraseAllAudios(4),
        CieloStrings.eraseProfileWithPhoto,
        CieloStrings.eraseTemporary(3),
        CieloStrings.eraseKeepOriginals,
        CieloStrings.eraseKeepExports,
        CieloStrings.eraseNotForensic,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.eraseAllAction),
      );
      await tester.pumpAndSettle();
      final Finder confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(
          FilledButton,
          CieloStrings.eraseAllAction,
        ),
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(find.text(CieloStrings.cancel));
      await tester.pumpAndSettle();
      expect(service.calls, 0);

      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.eraseAllAction),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(erased, 1);
      expect(find.text(CieloStrings.eraseAllDone), findsOneWidget);
      expect(find.text(CieloStrings.goToDiary), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('fallo parcial: no dice "borrados" y permite reintentar', (
      tester,
    ) async {
      final service = FakeErase()
        ..results.addAll([
          const Success(
            EraseAllReport(pendingFiles: 2, preferencesCleared: false),
          ),
          Failure(AppFailure(FailureCode.busy)),
          const Success(EraseAllReport(pendingFiles: 0)),
        ]);
      await _pump(tester, _erase(service), size: const Size(400, 1600));
      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.eraseAllAction),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
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
      expect(find.text(CieloStrings.eraseAllDone), findsNothing);
      expect(find.text(CieloStrings.erasePartialTitle), findsOneWidget);
      expect(
        find.textContaining(CieloStrings.erasePartialFiles(2)),
        findsOneWidget,
      );
      expect(
        find.textContaining(CieloStrings.erasePartialPreferences),
        findsOneWidget,
      );
      await tester.tap(find.text(CieloStrings.retry));
      await tester.pumpAndSettle();
      expect(find.textContaining(CieloStrings.failureBusy), findsOneWidget);
      await tester.tap(find.text(CieloStrings.retry));
      await tester.pumpAndSettle();
      expect(find.text(CieloStrings.eraseAllDone), findsOneWidget);
      expect(service.calls, 3);
    });

    testWidgets('datos ilegibles: igualmente se puede borrar', (tester) async {
      final service = FakeErase()
        ..previewResult = Failure(AppFailure(FailureCode.persistence));
      await _pump(tester, _erase(service), size: const Size(400, 1600));
      expect(find.byType(CieloBanner), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, CieloStrings.eraseAllAction),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('diálogo final legible al 200 %', (tester) async {
      await _pump(tester, _erase(FakeErase()), scale: 2);
      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.eraseAllAction),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('Pantalla de bloqueo', () {
    testWidgets('muestra el motivo y la salida sin credenciales', (
      tester,
    ) async {
      final settings = _settings(AppSettings(authenticationEnabled: true));
      final auth = FakeAuth()..outcome = AuthOutcome.temporarilyLocked;
      final lock = _lock(settings, auth);
      await _pump(tester, LockScreen(controller: lock));
      await tester.tap(find.text(CieloStrings.lockUnlock));
      await tester.pumpAndSettle();
      expect(find.text(CieloStrings.lockTemporarily), findsOneWidget);
      auth
        ..outcome = AuthOutcome.noCredentials
        ..available = AuthAvailability.noCredentials;
      await tester.tap(find.text(CieloStrings.lockUnlock));
      await tester.pumpAndSettle();
      expect(find.text(CieloStrings.lockCredentialsMissing), findsOneWidget);
      await tester.tap(find.text(CieloStrings.lockOpenWithout));
      await tester.pumpAndSettle();
      expect(lock.isLocked, isFalse);
    });
  });
}
