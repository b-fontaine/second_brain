import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/zettel.dart';
import '../repositories/zettel_repository.dart';

@injectable
class UpdateZettel implements UseCase<Zettel, Zettel> {
  const UpdateZettel(this._repository);

  final ZettelRepository _repository;

  @override
  Future<Either<Failure, Zettel>> call(Zettel params) {
    if (params.title.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Le titre ne peut pas être vide')),
      );
    }
    return _repository.updateZettel(params);
  }
}
