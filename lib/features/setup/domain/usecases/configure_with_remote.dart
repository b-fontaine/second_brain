import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/vault_config.dart';
import '../repositories/setup_repository.dart';
import 'git_remote_url_validator.dart';

/// Configures the vault against a remote git repository (clone + token).
@injectable
class ConfigureWithRemote
    implements UseCase<VaultConfig, ConfigureWithRemoteParams> {
  const ConfigureWithRemote(this._repository);

  final SetupRepository _repository;

  @override
  Future<Either<Failure, VaultConfig>> call(ConfigureWithRemoteParams params) {
    final remoteUrl = params.remoteUrl.trim();
    if (!GitRemoteUrlValidator.isValid(remoteUrl)) {
      return Future.value(
        const Left(ValidationFailure(GitRemoteUrlValidator.invalidUrlMessage)),
      );
    }
    return _repository.configureWithRemote(
      remoteUrl: remoteUrl,
      token: params.token,
    );
  }
}

class ConfigureWithRemoteParams extends Equatable {
  const ConfigureWithRemoteParams({
    required this.remoteUrl,
    required this.token,
  });

  final String remoteUrl;
  final String token;

  @override
  List<Object?> get props => [remoteUrl, token];
}
