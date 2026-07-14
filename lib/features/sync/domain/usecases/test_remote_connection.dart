import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/git_sync_repository.dart';

/// Checks that the remote repository accepts the candidate token (or the
/// stored one when none is provided) with a real fetch. Diagnostic only:
/// nothing is persisted.
@injectable
class TestRemoteConnection
    implements UseCase<Unit, TestRemoteConnectionParams> {
  const TestRemoteConnection(this._repository);

  final GitSyncRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(TestRemoteConnectionParams params) =>
      _repository.testRemoteConnection(tokenOverride: params.tokenOverride);
}

class TestRemoteConnectionParams extends Equatable {
  const TestRemoteConnectionParams({this.tokenOverride});

  /// Candidate token to try; null tests the stored token.
  final String? tokenOverride;

  @override
  List<Object?> get props => [tokenOverride];
}
