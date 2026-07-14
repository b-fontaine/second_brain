import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/git_sync_repository.dart';

/// Replaces the stored git personal access token, atomically: the token is
/// validated, tested against the remote, and persisted only when the test
/// succeeds (see [GitSyncRepository.updateToken]).
@injectable
class UpdateGitToken implements UseCase<Unit, UpdateGitTokenParams> {
  const UpdateGitToken(this._repository);

  final GitSyncRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(UpdateGitTokenParams params) =>
      _repository.updateToken(params.token);
}

class UpdateGitTokenParams extends Equatable {
  const UpdateGitTokenParams(this.token);

  final String token;

  @override
  List<Object?> get props => [token];
}
