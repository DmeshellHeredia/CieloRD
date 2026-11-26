import 'package:cielo_rd/app/contracts.dart';
import 'package:cielo_rd/features/observations/presentation/form/observation_form_screen.dart';
import 'package:cielo_rd/features/observations/presentation/form/quick_record_sheet.dart';
import 'package:cielo_rd/features/observations/presentation/preview/in_memory_observation_repository.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';
import 'diary_fixtures.dart';

/// Pantalla alta: el formulario es una lista perezosa y estas pruebas
/// verifican comportamiento; el diseño a 360 dp se cubre en accesibilidad.
const Size _tall = Size(400, 2600);

class FormLauncher {
  Object? result;
  bool returned = false;
}

Future<FormLauncher> pumpForm(
  WidgetTester tester,
  InMemoryObservationRepository store, {
  Observation? initial,
  ObservationInput? prefill,
  Size size = _tall,
  double textScale = 1.0,
}) async {
  final FormLauncher launcher = FormLauncher();
  await pumpCielo(
    tester,
    Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async {
              launcher.result = await Navigator.of(context).push<Object?>(
                MaterialPageRoute<Object?>(
                  builder: (_) => ObservationFormScreen(
                    service: store,
                    drafts: store,
                    initial: initial,
                    prefill: prefill,
                    clock: () => kNow,
                  ),
                ),
              );
              launcher.returned = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
    wrapInScaffold: false,
    size: size,
    textScale: textScale,
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return launcher;
}

Finder _titleField() => find.widgetWithText(TextField, CieloStrings.titleHint);

Future<void> _publish(WidgetTester tester) async {
  await tester.tap(find.text(CieloStrings.publish));
  await tester.pumpAndSettle();
}

void main() {
  group('Registro completo', () {
    testWidgets('publicar sin datos obligatorios muestra errores y no guarda', (
      WidgetTester tester,
    ) async {
      final InMemoryObservationRepository store =
          InMemoryObservationRepository();
      await pumpForm(tester, store);
      expect(find.text(CieloStrings.newObservation), findsOneWidget);
      await _publish(tester);
      expect(find.text(CieloStrings.fixErrors), findsOneWidget);
      expect(
        find.text(CieloStrings.fieldRequired),
        findsNWidgets(2),
        reason: 'título y categoría',
      );
      expect(store.length, 0);
    });

    testWidgets(
      'con título, fecha y categoría publica y devuelve la observación',
      (WidgetTester tester) async {
        final InMemoryObservationRepository store =
            InMemoryObservationRepository();
        final FormLauncher launcher = await pumpForm(tester, store);
        await tester.enterText(_titleField(), 'Leónidas en Valle Nuevo');
        await tester.tap(find.text(CieloStrings.categoryAstronomy));
        await tester.tap(find.text(CieloStrings.skyClear));
        await tester.enterText(
          find.widgetWithText(TextField, CieloStrings.placeHint),
          'Constanza',
        );
        await tester.pump();
        await _publish(tester);

        expect(launcher.returned, isTrue);
        final Observation saved = launcher.result! as Observation;
        expect(saved.status, ObservationStatus.published);
        expect(saved.input.title, 'Leónidas en Valle Nuevo');
        expect(saved.input.category, ObservationCategory.astronomy);
        expect(saved.input.skyCondition, SkyCondition.clear);
        expect(saved.input.location!.placeName, 'Constanza');
        expect(saved.input.location!.source, LocationSource.text);
        // Fecha por defecto: ahora, con el desplazamiento del dispositivo.
        expect(saved.input.observedAt, kNow.toUtc());
        expect(saved.input.utcOffsetMinutes, kNow.timeZoneOffset.inMinutes);
        expect(
          find.text(CieloStrings.published),
          findsOneWidget,
          reason: 'snackbar',
        );
      },
    );

    testWidgets('guardar borrador acepta datos incompletos', (
      WidgetTester tester,
    ) async {
      final InMemoryObservationRepository store =
          InMemoryObservationRepository();
      final FormLauncher launcher = await pumpForm(tester, store);
      await tester.tap(find.text(CieloStrings.categoryBirds));
      await tester.pump();
      await tester.tap(find.text(CieloStrings.saveDraft));
      await tester.pumpAndSettle();
      final Observation saved = launcher.result! as Observation;
      expect(saved.status, ObservationStatus.draft);
      expect(saved.input.title, isEmpty);
      expect(find.text(CieloStrings.draftSaved), findsOneWidget);
    });

    testWidgets(
      'dirección, duración, altura y descripción opcionales se guardan',
      (WidgetTester tester) async {
        final InMemoryObservationRepository store =
            InMemoryObservationRepository();
        final FormLauncher launcher = await pumpForm(tester, store);
        await tester.enterText(_titleField(), 'Estación Espacial');
        await tester.tap(find.text(CieloStrings.categoryArtificialShort));
        await tester.enterText(
          find.widgetWithText(TextField, CieloStrings.descriptionHint),
          'Paso brillante',
        );
        await tester.tap(find.text('5 min'));
        await tester.tap(find.text('NE'));
        await tester.tap(find.text(CieloStrings.elevationToggle));
        await tester.pump();
        await _publish(tester);
        final ObservationInput i = (launcher.result! as Observation).input;
        expect(i.description, 'Paso brillante');
        expect(i.durationSeconds, 300);
        expect(i.direction, CardinalDirection.northEast);
        expect(i.elevationDegrees, 45);
      },
    );
  });

  group('Ubicación manual', () {
    testWidgets('número inválido y coordenada sola muestran errores', (
      WidgetTester tester,
    ) async {
      final InMemoryObservationRepository store =
          InMemoryObservationRepository();
      await pumpForm(tester, store);
      await tester.enterText(_titleField(), 'Venus');
      await tester.tap(find.text(CieloStrings.categoryAstronomy));
      await tester.tap(find.text(CieloStrings.addCoordinates));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, CieloStrings.latitudeLabel),
        'abc',
      );
      await _publish(tester);
      expect(find.text(CieloStrings.fieldInvalidNumber), findsOneWidget);
      expect(store.length, 0);

      await tester.enterText(
        find.widgetWithText(TextField, CieloStrings.latitudeLabel),
        '18,48',
      );
      await _publish(tester);
      expect(find.text(CieloStrings.fieldCoordinatesPair), findsOneWidget);
      expect(store.length, 0);
    });

    testWidgets('coordenadas válidas se guardan como manuales', (
      WidgetTester tester,
    ) async {
      final InMemoryObservationRepository store =
          InMemoryObservationRepository();
      final FormLauncher launcher = await pumpForm(tester, store);
      await tester.enterText(_titleField(), 'Venus');
      await tester.tap(find.text(CieloStrings.categoryAstronomy));
      await tester.tap(find.text(CieloStrings.addCoordinates));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, CieloStrings.latitudeLabel),
        '18,4861',
      );
      await tester.enterText(
        find.widgetWithText(TextField, CieloStrings.longitudeLabel),
        '-69.9312',
      );
      await _publish(tester);
      final ObservationLocation loc =
          (launcher.result! as Observation).input.location!;
      expect(loc.latitude, 18.4861);
      expect(loc.longitude, -69.9312);
      expect(loc.source, LocationSource.manual);
    });

    testWidgets('latitud fuera de rango usa el mensaje del validador', (
      WidgetTester tester,
    ) async {
      final InMemoryObservationRepository store =
          InMemoryObservationRepository();
      await pumpForm(tester, store);
      await tester.enterText(_titleField(), 'X');
      await tester.tap(find.text(CieloStrings.categoryOther));
      await tester.tap(find.text(CieloStrings.addCoordinates));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, CieloStrings.latitudeLabel),
        '95',
      );
      await tester.enterText(
        find.widgetWithText(TextField, CieloStrings.longitudeLabel),
        '-70',
      );
      await _publish(tester);
      expect(find.text(CieloStrings.fieldLatitudeRange), findsOneWidget);
    });
  });

  group('Edición', () {
    testWidgets(
      'editar una publicada incrementa la revisión y conserva la hora original',
      (WidgetTester tester) async {
        final Observation original = obs(
          'e1',
          title: 'Halo',
          place: 'Santiago',
          offset: -300,
        );
        final InMemoryObservationRepository store =
            InMemoryObservationRepository(observations: [original]);
        final FormLauncher launcher = await pumpForm(
          tester,
          store,
          initial: original,
        );
        expect(find.text(CieloStrings.editObservation), findsOneWidget);
        expect(
          find.text(CieloStrings.saveDraft),
          findsNothing,
          reason: 'una publicada no vuelve a borrador',
        );
        await tester.enterText(_titleField(), 'Halo solar de 22°');
        await tester.tap(find.text(CieloStrings.saveChanges));
        await tester.pumpAndSettle();
        final Observation saved = launcher.result! as Observation;
        expect(saved.revision, 2);
        expect(saved.input.title, 'Halo solar de 22°');
        expect(saved.input.observedAt, original.input.observedAt);
        expect(saved.input.utcOffsetMinutes, -300);
        expect(find.text(CieloStrings.changesSaved), findsOneWidget);
      },
    );

    testWidgets(
      'si otro cambio llegó antes, informa el conflicto y no sobrescribe',
      (WidgetTester tester) async {
        final Observation original = obs('e2', title: 'Halo');
        final InMemoryObservationRepository store =
            InMemoryObservationRepository(observations: [original]);
        await pumpForm(tester, store, initial: original);
        // Otra edición (revisión 2) ocurre mientras el formulario está abierto.
        await store.update(
          'e2',
          original.input.copyWith(title: 'Otro'),
          status: ObservationStatus.published,
          expectedRevision: 1,
        );
        await tester.enterText(_titleField(), 'Mío');
        await tester.tap(find.text(CieloStrings.saveChanges));
        await tester.pumpAndSettle();
        expect(find.text(CieloStrings.failureConflict), findsOneWidget);
        expect(
          (await store.getById('e2') as Success<Observation>).value.input.title,
          'Otro',
        );
      },
    );

    testWidgets('completar un borrador y publicarlo', (
      WidgetTester tester,
    ) async {
      final Observation draft = obs(
        'd1',
        title: '',
        status: ObservationStatus.draft,
      );
      final InMemoryObservationRepository store = InMemoryObservationRepository(
        observations: [draft],
      );
      final FormLauncher launcher = await pumpForm(
        tester,
        store,
        initial: draft,
      );
      expect(find.text(CieloStrings.completeDraft), findsOneWidget);
      await tester.enterText(_titleField(), 'Bólido verde');
      await _publish(tester);
      final Observation saved = launcher.result! as Observation;
      expect(saved.status, ObservationStatus.published);
      expect(saved.revision, 2);
    });
  });

  group('Cambios sin guardar', () {
    testWidgets('salir sin cambios no pregunta', (WidgetTester tester) async {
      final FormLauncher launcher = await pumpForm(
        tester,
        InMemoryObservationRepository(),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(launcher.returned, isTrue);
      expect(launcher.result, isNull);
    });

    testWidgets('con cambios ofrece guardar borrador, descartar o seguir', (
      WidgetTester tester,
    ) async {
      final InMemoryObservationRepository store =
          InMemoryObservationRepository();
      final FormLauncher launcher = await pumpForm(tester, store);
      await tester.enterText(_titleField(), 'A medias');
      await tester
          .pump(); // la pantalla se reconstruye antes del siguiente toque
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(CieloStrings.unsavedTitle), findsOneWidget);

      await tester.tap(find.text(CieloStrings.keepEditing));
      await tester.pumpAndSettle();
      expect(launcher.returned, isFalse);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, CieloStrings.saveDraft),
      );
      await tester.pumpAndSettle();
      expect(launcher.returned, isTrue);
      expect((launcher.result! as Observation).status, ObservationStatus.draft);
      expect(store.length, 1);
    });

    testWidgets('descartar sale sin guardar', (WidgetTester tester) async {
      final InMemoryObservationRepository store =
          InMemoryObservationRepository();
      final FormLauncher launcher = await pumpForm(tester, store);
      await tester.enterText(_titleField(), 'Descartable');
      await tester
          .pump(); // la pantalla se reconstruye antes del siguiente toque
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(CieloStrings.discardChanges));
      await tester.pumpAndSettle();
      expect(launcher.returned, isTrue);
      expect(store.length, 0);
    });

    testWidgets('en una publicada pide confirmar el descarte', (
      WidgetTester tester,
    ) async {
      final Observation original = obs('p1', title: 'Halo');
      final FormLauncher launcher = await pumpForm(
        tester,
        InMemoryObservationRepository(observations: [original]),
        initial: original,
      );
      await tester.enterText(_titleField(), 'Cambio');
      await tester
          .pump(); // la pantalla se reconstruye antes del siguiente toque
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(CieloStrings.discardTitle), findsOneWidget);
      await tester.tap(find.text(CieloStrings.discardChanges));
      await tester.pumpAndSettle();
      expect(launcher.returned, isTrue);
    });
  });

  group('Registro rápido', () {
    Future<QuickRecordResult?> openQuick(
      WidgetTester tester,
      InMemoryObservationRepository store,
    ) async {
      QuickRecordResult? result;
      await pumpCielo(
        tester,
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async => result = await showQuickRecordSheet(
                  context,
                  drafts: store,
                  clock: () => kNow,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
        wrapInScaffold: false,
        size: const Size(400, 1400),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets(
      'exige categoría y guarda un borrador con la hora de apertura',
      (WidgetTester tester) async {
        final InMemoryObservationRepository store =
            InMemoryObservationRepository();
        await openQuick(tester, store);
        expect(find.text(CieloStrings.chooseCategoryFirst), findsOneWidget);
        final FilledButton save = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, CieloStrings.saveDraft),
        );
        expect(save.onPressed, isNull);

        await tester.tap(find.text(CieloStrings.categoryAstronomy));
        await tester.tap(find.text(CieloStrings.skySaharanDust));
        await tester.enterText(
          find.widgetWithText(TextField, CieloStrings.quickPlaceHint),
          'Higüey',
        );
        await tester.tap(
          find.widgetWithText(FilledButton, CieloStrings.saveDraft),
        );
        await tester.pumpAndSettle();

        expect(store.length, 1);
        final Observation draft = (await store.list(
          filter: ObservationFilter(status: ObservationStatus.draft),
        ) as Success<ObservationPage>).value.items.single;
        expect(draft.input.category, ObservationCategory.astronomy);
        expect(draft.input.skyCondition, SkyCondition.saharanDust);
        expect(draft.input.observedAt, kNow.toUtc());
        expect(draft.input.location!.placeName, 'Higüey');
      },
    );

    testWidgets('"Formulario completo" lleva lo elegido sin guardar', (
      WidgetTester tester,
    ) async {
      final InMemoryObservationRepository store =
          InMemoryObservationRepository();
      QuickRecordResult? result;
      await pumpCielo(
        tester,
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async => result = await showQuickRecordSheet(
                  context,
                  drafts: store,
                  clock: () => kNow,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
        wrapInScaffold: false,
        size: const Size(400, 1400),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CieloStrings.categoryBirds));
      await tester.tap(find.text(CieloStrings.fullForm));
      await tester.pumpAndSettle();
      expect(result, isA<QuickRecordOpenFullForm>());
      expect(
        (result! as QuickRecordOpenFullForm).prefill.category,
        ObservationCategory.birds,
      );
      expect(store.length, 0);
    });
  });

  forEachThemeAndScale('formulario sin desbordes', (
    WidgetTester t,
    v,
    double s,
  ) async {
    await pumpCielo(
      t,
      ObservationFormScreen(
        service: InMemoryObservationRepository(),
        drafts: InMemoryObservationRepository(),
        clock: () => kNow,
      ),
      wrapInScaffold: false,
      variant: v,
      textScale: s,
    );
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text(CieloStrings.newObservation), findsOneWidget);
  });
}
