import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';
import 'package:second_brain/features/zettel/domain/usecases/create_zettel.dart';

class MockZettelRepository extends Mock implements ZettelRepository {}

void main() {
  late MockZettelRepository repository;
  late CreateZettel usecase;

  final zettel = Zettel(
    id: ZettelId.fromString('20260714103005'),
    title: 'Concept A',
    body: 'Corps',
    createdAt: DateTime(2026, 7, 14, 10, 30, 5),
  );

  setUp(() {
    repository = MockZettelRepository();
    usecase = CreateZettel(repository);
  });

  test('delegates to the repository with a trimmed title', () async {
    when(
      () => repository.createZettel(
        title: any(named: 'title'),
        body: any(named: 'body'),
        tags: any(named: 'tags'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async => Right(zettel));

    final result = await usecase(
      const CreateZettelParams(title: '  Concept A  ', body: 'Corps'),
    );

    expect(result, Right<Failure, Zettel>(zettel));
    verify(
      () => repository.createZettel(
        title: 'Concept A',
        body: 'Corps',
        tags: const [],
        source: null,
      ),
    ).called(1);
  });

  test('rejects an empty title without touching the repository', () async {
    final result = await usecase(
      const CreateZettelParams(title: '   ', body: 'Corps'),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<ValidationFailure>()),
      (_) => fail('expected a ValidationFailure'),
    );
    verifyZeroInteractions(repository);
  });
}
