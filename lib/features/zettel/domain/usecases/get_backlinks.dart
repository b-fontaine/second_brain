import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/zettel.dart';
import '../entities/zettel_id.dart';
import '../repositories/zettel_repository.dart';

@injectable
class GetBacklinks implements UseCase<List<Zettel>, ZettelId> {
  const GetBacklinks(this._repository);

  final ZettelRepository _repository;

  @override
  Future<Either<Failure, List<Zettel>>> call(ZettelId params) =>
      _repository.getBacklinks(params);
}
