import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';

/// Base contract for all use cases.
///
/// [T] is the success type, [Params] the input type. Use [NoParams]
/// when the use case takes no input.
abstract interface class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Base contract for use cases exposing a stream (e.g. token streaming,
/// live dictation, sync status).
abstract interface class StreamUseCase<T, Params> {
  Stream<Either<Failure, T>> call(Params params);
}

class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => const [];
}
