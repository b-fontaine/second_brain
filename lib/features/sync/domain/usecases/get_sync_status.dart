import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/sync_status.dart';
import '../repositories/git_sync_repository.dart';

/// Returns the current synchronization status of the vault.
@injectable
class GetSyncStatus implements UseCase<SyncStatus, NoParams> {
  const GetSyncStatus(this._repository);

  final GitSyncRepository _repository;

  @override
  Future<Either<Failure, SyncStatus>> call(NoParams params) =>
      _repository.getStatus();
}
