import 'package:cielo_rd/features/observations/domain/observation_types.dart';
import 'package:cielo_rd/l10n/cielo_format.dart';
import 'package:cielo_rd/l10n/cielo_strings.dart';
import 'package:cielo_rd/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_cielo.dart';

void main() {
  group('Tablas visuales alineadas con los enums de Codex', () {
    test('cada ObservationCategory tiene apariencia propia', () {
      for (final ObservationCategory v in ObservationCategory.values) {
        expect(CategoryVisual.fromCode(v.name).code, v.name, reason: v.name);
      }
      expect(CategoryVisual.all.length, ObservationCategory.values.length);
    });

    test('cada SkyCondition tiene apariencia propia', () {
      for (final SkyCondition v in SkyCondition.values) {
        expect(SkyConditionVisual.fromCode(v.code).code, v.code, reason: v.code);
      }
      expect(SkyConditionVisual.all.length, SkyCondition.values.length);
    });

    test('cada CardinalDirection tiene apariencia propia', () {
      for (final CardinalDirection v in CardinalDirection.values) {
        expect(DirectionVisual.fromCode(v.code)?.code, v.code, reason: v.code);
      }
    });

    test('códigos desconocidos no rompen la UI', () {
      expect(CategoryVisual.fromCode('futuro'), CategoryVisual.other);
      expect(CategoryVisual.fromCode(null), CategoryVisual.other);
      expect(SkyConditionVisual.fromCode('futuro'), SkyConditionVisual.unknown);
      expect(DirectionVisual.fromCode('futuro'), isNull);
    });
  });

  group('CategoryGrid', () {
    testWidgets('selección única y estado accesible', (WidgetTester tester) async {
      String? selected;
      await pumpCielo(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => CategoryGrid(
            selectedCode: selected,
            onSelected: (CategoryVisual v) => setState(() => selected = v.code),
          ),
        ),
      );
      final handle = tester.ensureSemantics();

      await tester.tap(find.text(CieloStrings.categoryBirds));
      await tester.pumpAndSettle();
      expect(selected, 'birds');

      expect(
        tester.getSemantics(find.bySemanticsLabel(CieloStrings.categoryBirds)),
        isSemantics(
          isSelected: true,
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(CieloStrings.categoryAstronomy)),
        isSemantics(isSelected: false),
      );

      // TalkBack lee el nombre completo aunque la casilla muestre el corto.
      expect(find.text(CieloStrings.categoryArtificialShort), findsOneWidget);
      expect(find.bySemanticsLabel(CieloStrings.categoryArtificial), findsOneWidget);
      handle.dispose();
    });

    testWidgets('casillas de al menos 88 dp de alto', (WidgetTester tester) async {
      await pumpCielo(tester, CategoryGrid(selectedCode: null, onSelected: (_) {}));
      final Size size = tester.getSize(find.ancestor(
        of: find.text(CieloStrings.categoryBirds),
        matching: find.byType(InkWell),
      ));
      expect(size.height, greaterThanOrEqualTo(88));
    });
  });

  testWidgets('CategoryChip permite selección múltiple', (WidgetTester tester) async {
    final Set<String> selected = <String>{};
    await pumpCielo(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => Wrap(
          children: <Widget>[
            for (final CategoryVisual v in CategoryVisual.all)
              CategoryChip(
                category: v,
                selected: selected.contains(v.code),
                onSelected: (bool s) => setState(() => s ? selected.add(v.code) : selected.remove(v.code)),
              ),
          ],
        ),
      ),
    );
    await tester.tap(find.text(CieloStrings.categoryBirds));
    await tester.pump();
    await tester.tap(find.text(CieloStrings.categoryAstronomy));
    await tester.pump();
    expect(selected, <String>{'birds', 'astronomy'});
    await tester.tap(find.text(CieloStrings.categoryBirds));
    await tester.pump();
    expect(selected, <String>{'astronomy'});
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  group('SkyConditionSelector', () {
    testWidgets('selecciona y desmarca', (WidgetTester tester) async {
      String? value;
      await pumpCielo(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => SkyConditionSelector(
            selectedCode: value,
            onChanged: (String? v) => setState(() => value = v),
          ),
        ),
      );
      await tester.tap(find.text(CieloStrings.skySaharanDust));
      await tester.pump();
      expect(value, 'saharan_dust');
      await tester.tap(find.text(CieloStrings.skySaharanDust));
      await tester.pump();
      expect(value, isNull);
    });

    testWidgets('la calima explica "polvo del Sahara" a TalkBack', (WidgetTester tester) async {
      await pumpCielo(tester, SkyConditionSelector(selectedCode: null, onChanged: (_) {}));
      expect(
        find.bySemanticsLabel('${CieloStrings.skySaharanDust}, ${CieloStrings.skySaharanDustHint}'),
        findsOneWidget,
      );
    });
  });

  group('DirectionSelector', () {
    testWidgets('elige dirección y el centro la quita', (WidgetTester tester) async {
      String? value;
      await pumpCielo(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => DirectionSelector(
            selectedCode: value,
            onChanged: (String? v) => setState(() => value = v),
          ),
        ),
      );
      await tester.tap(find.text('NO'));
      await tester.pump();
      expect(value, 'nw');
      expect(find.bySemanticsLabel(CieloStrings.directionNW), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(CieloStrings.directionNone));
      await tester.pump();
      expect(value, isNull);
    });

    testWidgets('casillas de al menos 56 dp', (WidgetTester tester) async {
      await pumpCielo(tester, DirectionSelector(selectedCode: null, onChanged: (_) {}));
      final Size size = tester.getSize(find.ancestor(of: find.text('N'), matching: find.byType(InkWell)));
      expect(size.height, greaterThanOrEqualTo(56));
      expect(size.width, greaterThanOrEqualTo(56));
    });
  });

  group('DurationPicker', () {
    Future<void> pumpPicker(WidgetTester tester, ValueNotifier<Duration?> value) => pumpCielo(
          tester,
          ValueListenableBuilder<Duration?>(
            valueListenable: value,
            builder: (BuildContext context, Duration? v, _) =>
                DurationPicker(value: v, onChanged: (Duration? d) => value.value = d),
          ),
        );

    testWidgets('preset, quitar y valor personalizado', (WidgetTester tester) async {
      final ValueNotifier<Duration?> value = ValueNotifier<Duration?>(null);
      addTearDown(value.dispose);
      await pumpPicker(tester, value);

      await tester.tap(find.text(CieloFormat.duration(const Duration(minutes: 5))));
      await tester.pump();
      expect(value.value, const Duration(minutes: 5));

      await tester.tap(find.text(CieloStrings.durationRemove));
      await tester.pump();
      expect(value.value, isNull);

      await tester.tap(find.text(CieloStrings.durationOther));
      await tester.pump();
      expect(value.value, const Duration(minutes: 1));

      await tester.tap(find.byTooltip(CieloStrings.durationIncrease('minutos')));
      await tester.pump();
      await tester.tap(find.byTooltip(CieloStrings.durationIncrease('segundos')));
      await tester.pump();
      expect(value.value, const Duration(minutes: 2, seconds: 5));
    });

    testWidgets('un valor que no es preset abre el ajuste fino', (WidgetTester tester) async {
      final ValueNotifier<Duration?> value = ValueNotifier<Duration?>(const Duration(minutes: 7, seconds: 30));
      addTearDown(value.dispose);
      await pumpPicker(tester, value);
      expect(find.text(CieloStrings.durationMinutes), findsOneWidget);
      expect(find.text('07'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('no baja de cero', (WidgetTester tester) async {
      final ValueNotifier<Duration?> value = ValueNotifier<Duration?>(const Duration(seconds: 3));
      addTearDown(value.dispose);
      await pumpPicker(tester, value);
      final IconButton minus = tester.widget<IconButton>(find.ancestor(
        of: find.byTooltip(CieloStrings.durationDecrease('minutos')),
        matching: find.byType(IconButton),
      ));
      expect(minus.onPressed, isNull);
    });
  });
}
