import 'package:flutter/foundation.dart';

import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import '../domain/observation_input.dart';
import '../domain/observation_types.dart';
import '../domain/observation_validator.dart';

/// C0 only: editing and validation. No persistence, autosave or device access.
final class ObservationFormController extends ChangeNotifier {
  ObservationFormController({
    required this.validator,
    ObservationInput? initialInput,
  }) : _initialInput = initialInput ?? ObservationInput() {
    _input = _initialInput;
  }
  final ObservationValidator validator;
  final ObservationInput _initialInput;
  late ObservationInput _input;
  AppFailure? _failure;
  bool _isDirty = false;
  ObservationInput get input => _input;
  AppFailure? get failure => _failure;
  bool get isDirty => _isDirty;

  void replaceInput(ObservationInput input) {
    _input = input;
    _failure = null;
    _isDirty = true;
    notifyListeners();
  }

  Result<ObservationInput> validateFor(ObservationStatus status) {
    final result = validator.validate(_input, status: status);
    _failure = switch (result) {
      Failure<ObservationInput>(:final failure) => failure,
      _ => null,
    };
    notifyListeners();
    return result;
  }

  void reset() {
    _input = _initialInput;
    _failure = null;
    _isDirty = false;
    notifyListeners();
  }
}
