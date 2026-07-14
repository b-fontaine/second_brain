import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/zettel.dart';
import '../repositories/zettel_repository.dart';

@injectable
class CreateZettel implements UseCase<Zettel, CreateZettelParams> {
  const CreateZettel(this._repository);

  final ZettelRepository _repository;

  @override
  Future<Either<Failure, Zettel>> call(CreateZettelParams params) {
    final title = params.title.trim();
    if (title.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Le titre ne peut pas être vide')),
      );
    }
    return _repository.createZettel(
      title: title,
      body: params.body,
      tags: params.tags,
      source: params.source,
    );
  }
}

class CreateZettelParams extends Equatable {
  const CreateZettelParams({
    required this.title,
    required this.body,
    this.tags = const [],
    this.source,
  });

  final String title;
  final String body;
  final List<String> tags;
  final String? source;

  @override
  List<Object?> get props => [title, body, tags, source];
}
