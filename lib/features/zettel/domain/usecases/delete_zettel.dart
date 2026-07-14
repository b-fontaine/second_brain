import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/zettel_id.dart';
import '../repositories/zettel_repository.dart';

@injectable
class DeleteZettel implements UseCase<Unit, ZettelId> {
  const DeleteZettel(this._repository);

  final ZettelRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(ZettelId params) =>
      _repository.deleteZettel(params);
}
