import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/vault_config.dart';
import '../repositories/setup_repository.dart';

/// Creates an empty local-only vault (no git remote).
@injectable
class ConfigureLocalOnly implements UseCase<VaultConfig, NoParams> {
  const ConfigureLocalOnly(this._repository);

  final SetupRepository _repository;

  @override
  Future<Either<Failure, VaultConfig>> call(NoParams params) {
    return _repository.configureLocalOnly();
  }
}
