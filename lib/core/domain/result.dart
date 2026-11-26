import 'app_failure.dart';

sealed class Result<T> {
  const Result();
  R fold<R>({
    required R Function(T value) success,
    required R Function(AppFailure failure) failure,
  }) => switch (this) {
    Success<T>(:final value) => success(value),
    Failure<T>(failure: final error) => failure(error),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final AppFailure failure;
}

/// Explicit successful result for commands without a payload.
enum Unit { value }
