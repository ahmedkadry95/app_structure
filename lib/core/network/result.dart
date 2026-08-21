import 'failures.dart';

sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Failed(failure: final f) => failure(f),
    };
  }

  bool get isSuccess => this is Success<T>;

  T? get dataOrNull => switch (this) {
    Success(:final data) => data,
    Failed() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Success() => null,
    Failed(:final failure) => failure,
  };
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failed<T> extends Result<T> {
  final Failure failure;
  const Failed(this.failure);
}
