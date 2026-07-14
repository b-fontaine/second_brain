import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/zettel.dart';
import '../repositories/zettel_repository.dart';

@injectable
class GetAllZettels implements UseCase<List<Zettel>, NoParams> {
  const GetAllZettels(this._repository);

  final ZettelRepository _repository;

  @override
  Future<Either<Failure, List<Zettel>>> call(NoParams params) =>
      _repository.getAllZettels();
}
