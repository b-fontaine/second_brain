import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/zettel.dart';
import '../repositories/zettel_repository.dart';

@injectable
class SearchZettels implements UseCase<List<Zettel>, String> {
  const SearchZettels(this._repository);

  final ZettelRepository _repository;

  @override
  Future<Either<Failure, List<Zettel>>> call(String params) {
    final query = params.trim();
    if (query.isEmpty) return _repository.getAllZettels();
    return _repository.searchZettels(query);
  }
}
