import 'package:cielo_rd/app/contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('form reports field errors then clears them after editing', () {
    final controller = ObservationFormController(
      validator: const ObservationValidator(),
    );
    addTearDown(controller.dispose);
    var changes = 0;
    controller.addListener(() => changes++);
    expect(
      controller.validateFor(ObservationStatus.published),
      isA<Failure<ObservationInput>>(),
    );
    expect(controller.failure?.fieldErrors, contains('title'));
    controller.replaceInput(
      ObservationInput(
        title: 'Luna',
        observedAt: DateTime.utc(2026),
        utcOffsetMinutes: -240,
        category: ObservationCategory.astronomy,
      ),
    );
    expect(controller.failure, isNull);
    expect(controller.isDirty, isTrue);
    expect(
      controller.validateFor(ObservationStatus.published),
      isA<Success<ObservationInput>>(),
    );
    expect(changes, 3);
  });
  test('form reset restores its initial immutable input', () {
    final original = ObservationInput(title: 'Original');
    final controller = ObservationFormController(
      validator: const ObservationValidator(),
      initialInput: original,
    );
    addTearDown(controller.dispose);
    controller.replaceInput(original.copyWith(title: 'Cambio'));
    controller.reset();
    expect(controller.input.title, 'Original');
    expect(controller.isDirty, isFalse);
  });
}
