import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:cielo_rd/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';

/// Botón que abre [open] y guarda el resultado.
Widget _launcher<T>(Future<T> Function(BuildContext) open, void Function(T) onResult) => Builder(
      builder: (BuildContext context) => FilledButton(
        onPressed: () async => onResult(await open(context)),
        child: const Text('abrir'),
      ),
    );

void main() {
  group('showCieloConfirmDialog', () {
    for (final (String label, bool expected) in <(String, bool)>[
      (CieloStrings.delete, true),
      (CieloStrings.cancel, false),
    ]) {
      testWidgets('"$label" devuelve $expected', (WidgetTester tester) async {
        bool? result;
        await pumpCielo(
          tester,
          _launcher<bool>(
            (BuildContext c) => showCieloConfirmDialog(
              c,
              title: CieloStrings.deleteObservationTitle,
              message: CieloStrings.deleteObservationMessage,
              confirmLabel: CieloStrings.delete,
              destructive: true,
            ),
            (bool r) => result = r,
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        expect(find.text(CieloStrings.deleteObservationTitle), findsOneWidget);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(result, expected);
      });
    }

    testWidgets('cerrar tocando fuera equivale a cancelar', (WidgetTester tester) async {
      bool? result;
      await pumpCielo(
        tester,
        _launcher<bool>(
          (BuildContext c) => showCieloConfirmDialog(c, title: 't', message: 'm', confirmLabel: 'ok'),
          (bool r) => result = r,
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('showCieloDangerConfirmDialog (Borrar todo)', () {
    Future<void> open(WidgetTester tester, void Function(bool) onResult) async {
      await pumpCielo(
        tester,
        _launcher<bool>(
          (BuildContext c) => showCieloDangerConfirmDialog(
            c,
            title: CieloStrings.eraseAllTitle,
            message: CieloStrings.eraseAllMessage,
            confirmLabel: CieloStrings.eraseAllAction,
            consequences: <String>[
              CieloStrings.eraseAllObservations(37),
              CieloStrings.eraseAllPhotos(52),
              CieloStrings.eraseAllProfile,
            ],
            footnote: CieloStrings.eraseAllKeepsExternal,
          ),
          onResult,
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    FilledButton confirmButton(WidgetTester tester) => tester.widget<FilledButton>(
          find.ancestor(of: find.text(CieloStrings.eraseAllAction), matching: find.byType(FilledButton)),
        );

    testWidgets('lista exactamente lo que se borrará', (WidgetTester tester) async {
      await open(tester, (_) {});
      expect(find.text('37 observaciones y sus borradores'), findsOneWidget);
      expect(find.text('52 fotos guardadas'), findsOneWidget);
      expect(find.text(CieloStrings.eraseAllProfile), findsOneWidget);
      expect(find.text(CieloStrings.eraseAllKeepsExternal), findsOneWidget);
    });

    testWidgets('el botón está deshabilitado hasta marcar la casilla', (WidgetTester tester) async {
      bool? result;
      await open(tester, (bool r) => result = r);
      expect(confirmButton(tester).onPressed, isNull);

      await tester.ensureVisible(find.text(CieloStrings.eraseAllAcknowledge));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CieloStrings.eraseAllAcknowledge));
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNotNull);

      await tester.tap(find.text(CieloStrings.eraseAllAction));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('cancelar no borra', (WidgetTester tester) async {
      bool? result;
      await open(tester, (bool r) => result = r);
      await tester.tap(find.text(CieloStrings.eraseAllAcknowledge));
      await tester.pump();
      await tester.tap(find.text(CieloStrings.cancel));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('showUnsavedChangesSheet', () {
    for (final (String label, UnsavedChangesDecision expected) in <(String, UnsavedChangesDecision)>[
      (CieloStrings.saveDraft, UnsavedChangesDecision.saveDraft),
      (CieloStrings.discardChanges, UnsavedChangesDecision.discard),
      (CieloStrings.keepEditing, UnsavedChangesDecision.keepEditing),
    ]) {
      testWidgets('"$label" → ${expected.name}', (WidgetTester tester) async {
        UnsavedChangesDecision? result;
        await pumpCielo(
          tester,
          _launcher<UnsavedChangesDecision>(showUnsavedChangesSheet, (UnsavedChangesDecision d) => result = d),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(result, expected);
      });
    }

    testWidgets('"Guardar borrador" queda abajo, al alcance del pulgar', (WidgetTester tester) async {
      await pumpCielo(
        tester,
        _launcher<UnsavedChangesDecision>(showUnsavedChangesSheet, (_) {}),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      final double save = tester.getCenter(find.text(CieloStrings.saveDraft)).dy;
      final double keep = tester.getCenter(find.text(CieloStrings.keepEditing)).dy;
      expect(save, greaterThan(keep));
      expect(save, greaterThan(kPhoneSize.height * 0.66));
    });
  });

  group('CieloActionBar', () {
    Widget bar({bool busy = false, VoidCallback? onPrimary, VoidCallback? onSecondary, bool leftHanded = false}) =>
        Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: CieloActionBar(
            primaryLabel: CieloStrings.save,
            onPrimary: onPrimary ?? () {},
            secondaryLabel: CieloStrings.saveDraft,
            onSecondary: onSecondary ?? () {},
            busy: busy,
            leftHanded: leftHanded,
          ),
        );

    // La fuente de pruebas dibuja cada letra de 1 em de ancho (más ancha que
    // Atkinson), por eso la disposición en fila se prueba en 600 dp.
    const Size wide = Size(600, 780);

    testWidgets('acción principal de 56 dp a la derecha', (WidgetTester tester) async {
      int saves = 0;
      await pumpCielo(tester, bar(onPrimary: () => saves++), wrapInScaffold: false, size: wide);
      final Rect primary = tester.getRect(find.widgetWithText(FilledButton, CieloStrings.save));
      final Rect secondary = tester.getRect(find.widgetWithText(OutlinedButton, CieloStrings.saveDraft));
      expect(primary.height, greaterThanOrEqualTo(56));
      expect(primary.left, greaterThan(secondary.left));
      await tester.tap(find.text(CieloStrings.save));
      expect(saves, 1);
    });

    testWidgets('modo zurdo invierte el orden', (WidgetTester tester) async {
      await pumpCielo(tester, bar(leftHanded: true), wrapInScaffold: false, size: wide);
      final Rect primary = tester.getRect(find.widgetWithText(FilledButton, CieloStrings.save));
      final Rect secondary = tester.getRect(find.widgetWithText(OutlinedButton, CieloStrings.saveDraft));
      expect(primary.left, lessThan(secondary.left));
    });

    testWidgets('si las etiquetas no caben en fila, apila sin partir texto', (WidgetTester tester) async {
      await pumpCielo(tester, bar(), wrapInScaffold: false, size: const Size(320, 780));
      final Rect primary = tester.getRect(find.byType(FilledButton));
      final Rect secondary = tester.getRect(find.byType(OutlinedButton));
      expect(primary.top, greaterThan(secondary.bottom - 1));
      expect(primary.width, secondary.width);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con texto grande apila y deja la principal abajo', (WidgetTester tester) async {
      await pumpCielo(tester, bar(), wrapInScaffold: false, textScale: 2.0);
      final Rect primary = tester.getRect(find.byType(FilledButton));
      final Rect secondary = tester.getRect(find.byType(OutlinedButton));
      expect(primary.top, greaterThan(secondary.bottom - 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ocupado: deshabilita acciones y muestra progreso', (WidgetTester tester) async {
      await pumpCielo(tester, bar(busy: true), wrapInScaffold: false);
      expect(find.text(CieloStrings.saving), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
    });
  });
}
