import 'dart:io';

import 'package:cielo_rd/app/cielo_app.dart';
import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/core/database/app_database.dart';
import 'package:cielo_rd/features/observations/data/sqlite_observation_store.dart';
import 'package:cielo_rd/features/observations/presentation/form/quick_record_sheet.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

T _ok<T>(Result<T> result) => switch (result) {
  Success<T>(:final T value) => value,
  Failure<T>(:final AppFailure failure) => throw TestFailure(
    'Failure ${failure.code}: ${failure.message}',
  ),
};

void main() {
  sqfliteFfiInit();

  testWidgets('Diario → registro → detalle → edición → búsqueda → borrado', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(400, 900) * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final DateTime now = DateTime(2026, 11, 22, 20, 30);
    final InMemoryObservationRepository store = InMemoryObservationRepository(
      clock: () => now.toUtc(),
    );
    await tester.pumpWidget(
      CieloApp(
        observations: store,
        observationService: store,
        drafts: store,
        clock: () => now,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(QuickRecordSheet),
        matching: find.text(CieloStrings.categoryAstronomy),
      ),
    );
    await tester.tap(find.text(CieloStrings.fullForm));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, CieloStrings.titleHint),
      'Leónidas sobre Constanza',
    );
    await tester.tap(find.text(CieloStrings.publish));
    await tester.pumpAndSettle();
    expect(find.text('Leónidas sobre Constanza'), findsOneWidget);

    await tester.tap(find.text('Leónidas sobre Constanza'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(CieloStrings.edit));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, CieloStrings.titleHint),
      'Leónidas editadas',
    );
    await tester.tap(find.text(CieloStrings.saveChanges));
    await tester.pumpAndSettle();
    expect(find.text('Leónidas editadas'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'editadas');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Leónidas editadas'), findsOneWidget);

    await tester.tap(find.text('Leónidas editadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(CieloStrings.delete));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, CieloStrings.delete),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(CieloStrings.noResultsTitle), findsOneWidget);
    expect(store.length, 0);
  });

  test(
    'SQLite real: CRUD, reapertura, filtros y búsqueda normalizada',
    () async {
      final Directory directory = Directory.systemTemp.createTempSync(
        'cielord_functional_',
      );
      final String path = '${directory.path}/functional.db';
      final DateTime now = DateTime.utc(2026, 11, 22, 20, 30);
      int sequence = 0;
      AppDatabase database = AppDatabase(
        factory: databaseFactoryFfi,
        path: path,
      );
      SqliteObservationStore store = SqliteObservationStore(
        database: database,
        clock: () => now,
        newId: () => 'functional-${++sequence}',
      );

      try {
        final Observation created = _ok(
          await store.create(
            ObservationInput(
              title: 'Leónidas sobre Constanza',
              observedAt: DateTime.utc(2026, 11, 22, 2),
              utcOffsetMinutes: -240,
              category: ObservationCategory.astronomy,
              description: 'Lluvia de meteoros visible',
              location: ObservationLocation(
                placeName: 'Valle Nuevo',
                source: LocationSource.text,
              ),
            ),
            status: ObservationStatus.published,
          ),
        );
        final Observation read = _ok(await store.getById(created.id));
        expect(read.id, created.id);
        expect(read.input.title, created.input.title);
        expect(read.input.description, created.input.description);
        expect(read.input.location?.placeName, 'Valle Nuevo');
        expect(read.revision, 1);

        final Observation updated = _ok(
          await store.update(
            created.id,
            created.input.copyWith(title: 'Leónidas editadas'),
            status: ObservationStatus.published,
            expectedRevision: created.revision,
          ),
        );
        expect(updated.revision, 2);

        await database.close();
        database = AppDatabase(factory: databaseFactoryFfi, path: path);
        store = SqliteObservationStore(database: database, clock: () => now);
        final Observation reopened = _ok(await store.getById(created.id));
        expect(reopened.input.title, 'Leónidas editadas');
        expect(reopened.revision, 2);

        final ObservationPage filtered = _ok(
          await store.list(
            filter: ObservationFilter(
              query: 'LEONIDAS meteoros',
              category: ObservationCategory.astronomy,
              place: 'valle nuevo',
              status: ObservationStatus.published,
            ),
          ),
        );
        expect(filtered.items.single.id, created.id);
        expect(
          _ok(await store.count(filter: ObservationFilter(query: 'leonidas'))),
          1,
        );

        _ok(
          await store.delete(created.id, expectedRevision: reopened.revision),
        );
        await database.close();
        database = AppDatabase(factory: databaseFactoryFfi, path: path);
        store = SqliteObservationStore(database: database);
        final Result<Observation> missing = await store.getById(created.id);
        expect(missing, isA<Failure<Observation>>());
        expect(
          (missing as Failure<Observation>).failure.code,
          FailureCode.notFound,
        );
      } finally {
        await database.close();
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      }
    },
  );
}
