import 'dart:async';

import 'package:cielo_rd/core/concurrency/write_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'exclusive espera a las escrituras en curso y rechaza las nuevas',
    () async {
      final gate = WriteGate();
      final events = <String>[];
      final hold = Completer<void>();
      final writing = gate.write(() async {
        await hold.future;
        events.add('write');
      });
      final exclusive = gate.exclusive(() async => events.add('exclusive'));
      await Future<void>.delayed(Duration.zero);
      expect(gate.isClosed, isTrue);
      expect(events, isEmpty);
      await expectLater(
        gate.write(() async {}),
        throwsA(isA<WriteGateClosed>()),
      );
      await expectLater(
        gate.exclusive(() async {}),
        throwsA(isA<WriteGateClosed>()),
      );
      hold.complete();
      await Future.wait([writing, exclusive]);
      expect(events, ['write', 'exclusive']);
      expect(gate.isClosed, isFalse);
    },
  );

  test('se reabre aunque la operación exclusiva falle', () async {
    final gate = WriteGate();
    await expectLater(
      gate.exclusive<void>(() async => throw StateError('x')),
      throwsStateError,
    );
    expect(await gate.write(() async => 7), 7);
  });

  test('una escritura que falla no deja la puerta ocupada', () async {
    final gate = WriteGate();
    await expectLater(
      gate.write<void>(() async => throw StateError('x')),
      throwsStateError,
    );
    expect(
      await gate.exclusive(() async => 1).timeout(const Duration(seconds: 1)),
      1,
    );
  });
}
