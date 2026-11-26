import 'dart:io';

import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/core/database/app_database.dart';
import 'package:cielo_rd/core/database/database_migrations.dart';
import 'package:cielo_rd/core/database/schema_v1.dart';
import 'package:cielo_rd/core/database/schema_v2.dart';
import 'package:cielo_rd/features/observations/data/sqlite_observation_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Persistencia C1 sobre SQLite real (FFI), con el esquema de producción.
void main() {
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase database;
  late SqliteObservationStore store;
  late DateTime now;
  int seq = 0;

  SqliteObservationStore makeStore(AppDatabase db) => SqliteObservationStore(
    database: db,
    clock: () => now,
    newId: () => 'id-${(seq++).toString().padLeft(4, '0')}',
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cielord_c1_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${dir.path}/c1.db',
    );
    now = DateTime.utc(2026, 11, 22, 12);
    seq = 0;
    store = makeStore(database);
  });

  tearDown(() async {
    await database.close();
    await dir.delete(recursive: true);
  });

  ObservationInput published(
    String title, {
    DateTime? at,
    ObservationCategory category = ObservationCategory.astronomy,
    String? place,
    String? description,
    List<ObservationMedia> media = const [],
  }) => ObservationInput(
    title: title,
    observedAt: at ?? DateTime.utc(2026, 11, 20, 2),
    utcOffsetMinutes: -240,
    category: category,
    description: description,
    location: place == null
        ? null
        : ObservationLocation(placeName: place, source: LocationSource.text),
    media: media,
  );

  ObservationMedia photo(String id) => ObservationMedia(
    id: id,
    kind: MediaKind.photo,
    relativePath: 'media/$id.jpg',
    mimeType: 'image/jpeg',
    byteSize: 1000,
  );

  T ok<T>(Result<T> r) => switch (r) {
    Success<T>(:final value) => value,
    Failure<T>(:final failure) => throw TestFailure(
      'Failure ${failure.code} ${failure.fieldErrors} ${failure.message}',
    ),
  };

  FailureCode code<T>(Result<T> r) => (r as Failure<T>).failure.code;

  group('CRUD', () {
    test('crear y leer conserva todos los campos', () async {
      final ObservationInput input = ObservationInput(
        title: '  Leónidas  ',
        observedAt: DateTime.utc(2026, 11, 17, 6, 30),
        utcOffsetMinutes: -240,
        category: ObservationCategory.astronomy,
        subtypeCode: 'meteor_shower',
        skyCondition: SkyCondition.saharanDust,
        description: 'Cuarenta por hora',
        durationSeconds: 5400,
        direction: CardinalDirection.northEast,
        elevationDegrees: 62.5,
        location: ObservationLocation(
          placeName: 'Valle Nuevo',
          latitude: 18.79,
          longitude: -70.6,
          source: LocationSource.gps,
          accuracyM: 12,
          capturedAt: DateTime.utc(2026, 11, 17, 6, 29, 58),
        ),
        media: [photo('p1'), photo('p2')],
      );
      final Observation created = ok(
        await store.create(input, status: ObservationStatus.published),
      );
      expect(created.revision, 1);
      expect(created.createdAt, now);

      final Observation read = ok(await store.getById(created.id));
      final ObservationInput i = read.input;
      expect(i.title, 'Leónidas');
      expect(i.observedAt, DateTime.utc(2026, 11, 17, 6, 30));
      expect(i.utcOffsetMinutes, -240);
      expect(i.subtypeCode, 'meteor_shower');
      expect(i.skyCondition, SkyCondition.saharanDust);
      expect(i.durationSeconds, 5400);
      expect(i.direction, CardinalDirection.northEast);
      expect(i.elevationDegrees, 62.5);
      expect(i.location!.placeName, 'Valle Nuevo');
      expect(i.location!.source, LocationSource.gps);
      expect(i.location!.accuracyM, 12);
      expect(i.location!.capturedAt, DateTime.utc(2026, 11, 17, 6, 29, 58));
      expect(i.media.map((m) => m.id), ['p1', 'p2']);
      expect(read.status, ObservationStatus.published);
    });

    test('publicar exige título, fecha y categoría; el validador responde antes que SQLite', () async {
      final Result<Observation> r = await store.create(
        ObservationInput(title: ' '),
        status: ObservationStatus.published,
      );
      final AppFailure f = (r as Failure<Observation>).failure;
      expect(f.code, FailureCode.validation);
      expect(
        f.fieldErrors.keys,
        containsAll(['title', 'observedAt', 'category']),
      );
      expect(ok(await store.count(filter: ObservationFilter(status: null))), 0);
    });

    test('actualizar incrementa la revisión y detecta conflictos', () async {
      final Observation a = ok(
        await store.create(
          published('Uno'),
          status: ObservationStatus.published,
        ),
      );
      now = now.add(const Duration(minutes: 5));
      final Observation b = ok(
        await store.update(
          a.id,
          published('Dos'),
          status: ObservationStatus.published,
          expectedRevision: 1,
        ),
      );
      expect(b.revision, 2);
      expect(b.input.title, 'Dos');
      expect(b.updatedAt, now);

      final Result<Observation> stale = await store.update(
        a.id,
        published('Tres'),
        status: ObservationStatus.published,
        expectedRevision: 1,
      );
      expect(code(stale), FailureCode.conflict);
      expect(
        ok(await store.getById(a.id)).input.title,
        'Dos',
        reason: 'nunca sobrescribe en silencio',
      );
      expect(
        code(
          await store.update(
            'no',
            published('x'),
            status: ObservationStatus.published,
            expectedRevision: 1,
          ),
        ),
        FailureCode.notFound,
      );
    });

    test('borrar exige la revisión vigente y encola los archivos', () async {
      final Observation a = ok(
        await store.create(
          published('Con foto', media: [photo('p9')]),
          status: ObservationStatus.published,
        ),
      );
      expect(
        code(await store.delete(a.id, expectedRevision: 7)),
        FailureCode.conflict,
      );
      expect(ok(await store.delete(a.id, expectedRevision: 1)), Unit.value);
      expect(code(await store.getById(a.id)), FailureCode.notFound);
      expect(
        code(await store.delete(a.id, expectedRevision: 1)),
        FailureCode.notFound,
      );

      final Database db = await database.open();
      expect(await db.query('media_files'), isEmpty);
      expect(
        (await db.query('pending_file_deletions')).single['relative_path'],
        'media/p9.jpg',
      );
    });

    test('quitar una foto al editar la libera y la encola', () async {
      final Observation a = ok(
        await store.create(
          published('Fotos', media: [photo('k1'), photo('k2')]),
          status: ObservationStatus.published,
        ),
      );
      final Observation b = ok(
        await store.update(
          a.id,
          published('Fotos', media: [photo('k2')]),
          status: ObservationStatus.published,
          expectedRevision: 1,
        ),
      );
      expect(b.input.media.map((m) => m.id), ['k2']);
      final Database db = await database.open();
      expect((await db.query('media_files')).map((r) => r['id']), ['k2']);
      expect(
        (await db.query('pending_file_deletions')).single['relative_path'],
        'media/k1.jpg',
      );
    });

    test('un medio no puede pertenecer a dos observaciones', () async {
      ok(
        await store.create(
          published('A', media: [photo('shared')]),
          status: ObservationStatus.published,
        ),
      );
      final Result<Observation> r = await store.create(
        published('B', media: [photo('shared')]),
        status: ObservationStatus.published,
      );
      expect(r, isA<Failure<Observation>>());
      expect(
        ok(await store.count(filter: ObservationFilter())),
        1,
        reason: 'la transacción se revierte entera',
      );
    });
  });

  group('Borradores', () {
    test('un borrador vacío es válido; se completa y se publica', () async {
      final Observation d = ok(await store.save(ObservationInput()));
      expect(d.status, ObservationStatus.draft);
      expect(
        code(await store.publish(d.id, expectedRevision: 1)),
        FailureCode.validation,
      );

      final Observation d2 = ok(
        await store.save(published('Bólido'), id: d.id, expectedRevision: 1),
      );
      expect(d2.revision, 2);
      final Observation p = ok(await store.publish(d.id, expectedRevision: 2));
      expect(p.status, ObservationStatus.published);
      expect(p.revision, 3);
      expect(
        code(await store.publish(d.id, expectedRevision: 3)),
        FailureCode.conflict,
      );
    });

    test('save exige id y revisión juntos y solo edita borradores', () async {
      expect(
        code(await store.save(ObservationInput(), id: 'x')),
        FailureCode.validation,
      );
      final Observation pub = ok(
        await store.create(
          published('Publicada'),
          status: ObservationStatus.published,
        ),
      );
      final Result<Observation> r = await store.save(
        ObservationInput(title: 'x'),
        id: pub.id,
        expectedRevision: 1,
      );
      expect(
        (r as Failure<Observation>).failure.fieldErrors['status'],
        'not_a_draft',
      );
    });

    test('los borradores sin fecha van al final del orden', () async {
      ok(await store.save(ObservationInput(title: 'sin fecha')));
      ok(
        await store.create(
          published('con fecha'),
          status: ObservationStatus.published,
        ),
      );
      final ObservationPage page = ok(
        await store.list(filter: ObservationFilter(status: null)),
      );
      expect(page.items.map((o) => o.input.title), ['con fecha', 'sin fecha']);
    });
  });

  group('Consultas', () {
    setUp(() async {
      final List<(String, DateTime, ObservationCategory, String?, String?)>
      data = [
        (
          'Leónidas en Valle Nuevo',
          DateTime.utc(2026, 11, 17, 6),
          ObservationCategory.astronomy,
          'Constanza',
          'Bólidos verdes',
        ),
        (
          'Halo solar',
          DateTime.utc(2026, 11, 10, 15),
          ObservationCategory.atmospheric,
          'Santiago',
          null,
        ),
        (
          'Garzas',
          DateTime.utc(2026, 10, 1, 22),
          ObservationCategory.birds,
          'Laguna de Oviedo',
          'Cerca de la orilla',
        ),
        (
          'Mismo instante',
          DateTime.utc(2026, 11, 17, 6),
          ObservationCategory.astronomy,
          null,
          null,
        ),
        (
          '100% nublado_raro',
          DateTime.utc(2026, 9, 1),
          ObservationCategory.other,
          'Baní',
          null,
        ),
      ];
      for (final d in data) {
        ok(
          await store.create(
            published(
              d.$1,
              at: d.$2,
              category: d.$3,
              place: d.$4,
              description: d.$5,
            ),
            status: ObservationStatus.published,
          ),
        );
      }
      ok(
        await store.save(
          ObservationInput(
            title: 'Borrador Constanza',
            location: const ObservationLocation(
              placeName: 'Constanza',
              source: LocationSource.text,
            ),
          ),
        ),
      );
    });

    Future<List<String>> titles(ObservationFilter f, {int limit = 30}) async =>
        ok(await store.list(filter: f, limit: limit)).items
            .map((o) => o.input.title)
            .toList();

    test(
      'orden: fecha DESC y luego id DESC; por defecto solo publicadas',
      () async {
        expect(await titles(ObservationFilter()), [
          'Mismo instante',
          'Leónidas en Valle Nuevo',
          'Halo solar',
          'Garzas',
          '100% nublado_raro',
        ]);
      },
    );

    test('búsqueda sin acentos ni mayúsculas, por palabras, en título, descripción y lugar', () async {
      expect(await titles(ObservationFilter(query: 'LEONIDAS')), [
        'Leónidas en Valle Nuevo',
      ]);
      expect(await titles(ObservationFilter(query: 'bolidos')), [
        'Leónidas en Valle Nuevo',
      ]);
      expect(await titles(ObservationFilter(query: 'oviedo orilla')), [
        'Garzas',
      ]);
      expect(
        await titles(ObservationFilter(query: 'oviedo santiago')),
        isEmpty,
      );
    });

    test('los comodines de LIKE se buscan literalmente', () async {
      expect(await titles(ObservationFilter(query: '100%')), [
        '100% nublado_raro',
      ]);
      expect(await titles(ObservationFilter(query: '_')), [
        '100% nublado_raro',
      ]);
      expect(await titles(ObservationFilter(query: '%')), [
        '100% nublado_raro',
      ]);
    });

    test(
      'filtros combinados: fecha [inicio, fin), categoría, lugar y estado',
      () async {
        final ObservationFilter nov = ObservationFilter(
          from: DateTime.utc(2026, 11),
          until: DateTime.utc(2026, 12),
        );
        expect(await titles(nov), [
          'Mismo instante',
          'Leónidas en Valle Nuevo',
          'Halo solar',
        ]);
        expect(
          await titles(ObservationFilter(until: DateTime.utc(2026, 11, 17, 6))),
          ['Halo solar', 'Garzas', '100% nublado_raro'],
        );
        expect(
          await titles(
            ObservationFilter(
              from: DateTime.utc(2026, 11),
              until: DateTime.utc(2026, 12),
              category: ObservationCategory.astronomy,
              place: 'constanza',
            ),
          ),
          ['Leónidas en Valle Nuevo'],
        );
        expect(
          await titles(
            ObservationFilter(
              place: 'CONSTANZA',
              status: ObservationStatus.draft,
            ),
          ),
          ['Borrador Constanza'],
        );
        expect(
          await titles(ObservationFilter(place: 'constanza', status: null)),
          hasLength(2),
        );
      },
    );

    test('conteos exactos con la misma semántica que list', () async {
      expect(ok(await store.count(filter: ObservationFilter())), 5);
      expect(ok(await store.count(filter: ObservationFilter(status: null))), 6);
      expect(
        ok(
          await store.count(
            filter: ObservationFilter(status: ObservationStatus.draft),
          ),
        ),
        1,
      );
      expect(
        ok(await store.count(filter: ObservationFilter(query: 'leonidas'))),
        1,
      );
    });

    test(
      'paginación estable aunque se inserten registros entre páginas',
      () async {
        final ObservationFilter f = ObservationFilter();
        final ObservationPage first = ok(await store.list(filter: f, limit: 2));
        expect(first.items.map((o) => o.input.title), [
          'Mismo instante',
          'Leónidas en Valle Nuevo',
        ]);
        // Un registro nuevo más reciente no desplaza la página siguiente.
        ok(
          await store.create(
            published('Nuevo', at: DateTime.utc(2026, 11, 21)),
            status: ObservationStatus.published,
          ),
        );
        final ObservationPage second = ok(
          await store.list(filter: f, cursor: first.nextCursor, limit: 2),
        );
        expect(second.items.map((o) => o.input.title), [
          'Halo solar',
          'Garzas',
        ]);
        final ObservationPage third = ok(
          await store.list(filter: f, cursor: second.nextCursor, limit: 2),
        );
        expect(third.items.map((o) => o.input.title), ['100% nublado_raro']);
        expect(third.nextCursor, isNull);
      },
    );

    test('el cursor solo vale para su filtro; el límite se valida', () async {
      final ObservationPage first = ok(
        await store.list(filter: ObservationFilter(), limit: 2),
      );
      expect(
        code(
          await store.list(
            filter: ObservationFilter(query: 'x'),
            cursor: first.nextCursor,
          ),
        ),
        FailureCode.validation,
      );
      expect(
        code(await store.list(filter: ObservationFilter(), cursor: 'basura')),
        FailureCode.validation,
      );
      expect(
        code(await store.list(filter: ObservationFilter(), limit: 0)),
        FailureCode.validation,
      );
      expect(
        code(await store.list(filter: ObservationFilter(), limit: 101)),
        FailureCode.validation,
      );
    });
  });

  group('Persistencia e integridad', () {
    test(
      'los datos sobreviven a cerrar y reabrir la base (reinicio de la app)',
      () async {
        final Observation a = ok(
          await store.create(
            published('Persistente', media: [photo('pp')]),
            status: ObservationStatus.published,
          ),
        );
        final Observation d = ok(
          await store.save(ObservationInput(title: 'Borrador persistente')),
        );
        await database.close();

        final AppDatabase reopened = AppDatabase(
          factory: databaseFactoryFfi,
          path: database.path,
        );
        addTearDown(reopened.close);
        final SqliteObservationStore again = makeStore(reopened);
        expect(ok(await again.getById(a.id)).input.media.single.id, 'pp');
        expect(ok(await again.getById(d.id)).status, ObservationStatus.draft);
        expect(
          ok(await again.count(filter: ObservationFilter(status: null))),
          2,
        );
      },
    );

    test(
      'migración 1 → 3 conserva datos, rellena búsqueda y añade captura GPS',
      () async {
        final String path = '${dir.path}/legacy.db';
        final Database v1 = await databaseFactoryFfi.openDatabase(path);
        for (final String statement in schemaV1Statements) {
          await v1.execute(statement);
        }
        await v1.insert('observations', {
          'id': 'legacy',
          'status': 'published',
          'title': 'Eclipse Lunar',
          'observed_at_utc_ms': DateTime.utc(2026, 3, 3).millisecondsSinceEpoch,
          'utc_offset_minutes': -240,
          'category_code': 'astronomy',
          'place_name': 'Higüey',
          'location_source': 'text',
          'created_at': 1,
          'updated_at': 1,
        });
        await v1.setVersion(1);
        await v1.close();

        final AppDatabase migrated = AppDatabase(
          factory: databaseFactoryFfi,
          path: path,
        );
        addTearDown(migrated.close);
        final SqliteObservationStore s = makeStore(migrated);
        final Database migratedDb = await migrated.open();
        expect(await migratedDb.getVersion(), DatabaseMigrations.currentVersion);
        final columns = await migratedDb.rawQuery(
          'PRAGMA table_info(observations)',
        );
        expect(
          columns.map((row) => row['name']),
          contains('location_captured_at'),
        );
        expect(
          (await migratedDb.query('observations'))
              .single['location_captured_at'],
          isNull,
        );
        expect(
          ok(await s.list(filter: ObservationFilter(query: 'eclipse')))
              .items
              .single
              .id,
          'legacy',
        );
        expect(
          ok(await s.list(filter: ObservationFilter(place: 'higuey')))
              .items
              .single
              .id,
          'legacy',
        );
      },
    );

    test('migración 2 → 3 conserva una ubicación GPS heredada sin inventar timestamp', () async {
      final String path = '${dir.path}/legacy-v2.db';
      final Database v2 = await databaseFactoryFfi.openDatabase(path);
      for (final statement in schemaV1Statements) {
        await v2.execute(statement);
      }
      for (final statement in schemaV2Statements) {
        await v2.execute(statement);
      }
      await v2.insert('observations', {
        'id': 'gps-v2',
        'status': 'published',
        'title': 'GPS anterior',
        'observed_at_utc_ms': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        'utc_offset_minutes': -240,
        'category_code': 'astronomy',
        'latitude': 18.4861,
        'longitude': -69.9312,
        'location_source': 'gps',
        'accuracy_m': 15.0,
        'created_at': 1,
        'updated_at': 1,
      });
      await v2.setVersion(2);
      await v2.close();

      final migrated = AppDatabase(factory: databaseFactoryFfi, path: path);
      addTearDown(migrated.close);
      final migratedStore = makeStore(migrated);
      expect(await (await migrated.open()).getVersion(), DatabaseMigrations.currentVersion);
      final observation = ok(await migratedStore.getById('gps-v2'));
      expect(observation.input.location!.latitude, 18.4861);
      expect(observation.input.location!.source, LocationSource.gps);
      expect(observation.input.location!.capturedAt, isNull);
    });

    test(
      'un código desconocido en la base se informa como datos dañados',
      () async {
        final Database db = await database.open();
        await db.execute('PRAGMA ignore_check_constraints = ON');
        await db.insert('observations', {
          'id': 'bad',
          'status': 'draft',
          'title': '',
          'category_code': 'unicorns',
          'created_at': 1,
          'updated_at': 1,
        });
        await db.execute('PRAGMA ignore_check_constraints = OFF');
        expect(code(await store.getById('bad')), FailureCode.corruptData);
      },
    );

    test(
      'una base cerrada por fuera no rompe el contrato: devuelve Failure',
      () async {
        final Database db = await database.open();
        await db.close();
        final Result<int> r = await store.count(filter: ObservationFilter());
        expect(r, isA<Failure<int>>());
      },
    );
  });
}
