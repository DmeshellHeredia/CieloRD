import 'package:cielo_rd/app/contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fold exposes only the active success or failure branch', () {
    expect(
      const Success(7).fold(
        success: (value) => value * 2,
        failure: (_) => throw StateError('wrong branch'),
      ),
      14,
    );
    final error = AppFailure(FailureCode.conflict);
    expect(
      Failure<int>(error).fold(
        success: (_) => throw StateError('wrong branch'),
        failure: (value) => value.code,
      ),
      FailureCode.conflict,
    );
  });
  test('failure fields cannot change through caller-owned map', () {
    final fields = {'title': 'required'};
    final failure = AppFailure(FailureCode.validation, fieldErrors: fields);
    fields.clear();
    expect(failure.fieldErrors['title'], 'required');
    expect(() => failure.fieldErrors.clear(), throwsUnsupportedError);
  });
}
