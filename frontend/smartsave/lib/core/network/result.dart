import '../errors/failures.dart';

/// A sealed class representing the result of an operation that can either
/// succeed with data of type [T] or fail with a [Failure].
sealed class Result<T> {
  const Result();

  /// Unwraps the result, returning the data or throwing the Failure.
  T get dataOrThrow => switch (this) {
        Success(:final data) => data,
        FailureResult(:final failure) => throw failure,
      };

  /// Returns the data if success, or null if failure.
  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        _ => null,
      };

  /// Returns the failure if present, or null.
  Failure? get failureOrNull => switch (this) {
        FailureResult(:final failure) => failure,
        _ => null,
      };

  /// Returns true if this is a success.
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a failure.
  bool get isFailure => this is FailureResult<T>;

  /// Transforms the success data using [transform].
  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success(:final data) => Success(transform(data)),
      FailureResult(:final failure) => FailureResult(failure),
    };
  }

  /// Transforms the success data using [transform], which returns a Result.
  Result<R> flatMap<R>(Result<R> Function(T data) transform) {
    return switch (this) {
      Success(:final data) => transform(data),
      FailureResult(:final failure) => FailureResult(failure),
    };
  }

  /// Performs an action on success data.
  void onSuccess(void Function(T data) action) {
    if (this case Success(:final data)) action(data);
  }

  /// Performs an action on failure.
  void onFailure(void Function(Failure failure) action) {
    if (this case FailureResult(:final failure)) action(failure);
  }

  /// Performs an action in both cases.
  void fold(void Function(T data) onSuccess, void Function(Failure failure) onFailure) {
    if (this case Success(:final data)) {
      onSuccess(data);
    } else if (this case FailureResult(:final failure)) {
      onFailure(failure);
    }
  }
}

/// Success result containing data of type [T].
class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  String toString() => 'Success($data)';
}

/// Failure result containing a [Failure] object.
class FailureResult<T> extends Result<T> {
  final Failure failure;
  const FailureResult(this.failure);

  @override
  String toString() => 'FailureResult($failure)';
}

/// Extension helper for creating Results from try/catch blocks.
extension ResultExtension<T> on T Function() {
  Result<T> toResult() {
    try {
      return Success(this());
    } on Failure catch (f) {
      return FailureResult(f);
    } catch (e) {
      return FailureResult(ServerFailure(message: e.toString()));
    }
  }
}

/// Async extension helper.
extension AsyncResultExtension<T> on Future<T> Function() {
  Future<Result<T>> toResultAsync() async {
    try {
      final data = await this();
      return Success(data);
    } on Failure catch (f) {
      return FailureResult(f);
    } catch (e) {
      return FailureResult(ServerFailure(message: e.toString()));
    }
  }
}


