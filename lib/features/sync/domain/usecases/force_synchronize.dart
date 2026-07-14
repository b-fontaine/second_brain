import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/git_sync_repository.dart';

/// User-triggered synchronization: commits any pending local change,
/// then pulls and pushes.
@injectable
class ForceSynchronize implements UseCase<Unit, NoParams> {
  const ForceSynchronize(this._repository);

  static const _commitMessage = 'note: sauvegarde manuelle';

  final GitSyncRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(NoParams params) async {
    final committed = await _repository.commitAll(_commitMessage);
    return committed.fold(
      (failure) => Future.value(Left(failure)),
      (_) => _repository.synchronize(),
    );
  }
}
