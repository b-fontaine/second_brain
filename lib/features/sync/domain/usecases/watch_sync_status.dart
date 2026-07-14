import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/sync_status.dart';
import '../repositories/git_sync_repository.dart';

/// Emits the synchronization status on every change (commit, push,
/// connectivity...), starting with the current value.
@injectable
class WatchSyncStatus implements StreamUseCase<SyncStatus, NoParams> {
  const WatchSyncStatus(this._repository);

  final GitSyncRepository _repository;

  @override
  Stream<Either<Failure, SyncStatus>> call(NoParams params) => _repository
      .watchStatus()
      .map((status) => Right<Failure, SyncStatus>(status));
}
