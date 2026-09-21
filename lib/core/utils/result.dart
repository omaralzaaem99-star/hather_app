/// Simple Result type for repository / use-case returns.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Err<T>;

  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Err<T>() => null,
  };

  F? failureOrNull<F>() => switch (this) {
    Err<T>(:final failure) => failure is F ? failure as F : null,
    Success<T>() => null,
  };

  R when<R>({
    required R Function(T value) success,
    required R Function(Object error) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final value) => success(value),
      Err<T>(:final failure) => onFailure(failure),
    };
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.failure);
  final Object failure;
}
