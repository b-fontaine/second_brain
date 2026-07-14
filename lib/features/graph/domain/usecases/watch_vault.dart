import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../zettel/domain/repositories/zettel_repository.dart';

/// Exposes vault change events to the graph feature, so its presentation
/// layer never touches [ZettelRepository] directly.
@injectable
class WatchVault implements StreamUseCase<VaultChanged, NoParams> {
  const WatchVault(this._repository);

  final ZettelRepository _repository;

  @override
  Stream<Either<Failure, VaultChanged>> call(NoParams params) =>
      _repository.watchVault().map(Right<Failure, VaultChanged>.new);
}
