import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/vault_config.dart';
import '../repositories/setup_repository.dart';

/// Reads the persisted vault configuration; `null` means first run.
@injectable
class GetVaultConfig implements UseCase<VaultConfig?, NoParams> {
  const GetVaultConfig(this._repository);

  final SetupRepository _repository;

  @override
  Future<Either<Failure, VaultConfig?>> call(NoParams params) {
    return _repository.getConfig();
  }
}
