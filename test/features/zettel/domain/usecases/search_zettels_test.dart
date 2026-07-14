import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';
import 'package:second_brain/features/zettel/domain/usecases/search_zettels.dart';

class MockZettelRepository extends Mock implements ZettelRepository {}

void main() {
  late MockZettelRepository repository;
  late SearchZettels usecase;

  setUp(() {
    repository = MockZettelRepository();
    usecase = SearchZettels(repository);
  });

  test('delegates a non-empty query to searchZettels', () async {
    when(
      () => repository.searchZettels('mémoire'),
    ).thenAnswer((_) async => const Right(<Zettel>[]));

    await usecase('mémoire');

    verify(() => repository.searchZettels('mémoire')).called(1);
    verifyNever(() => repository.getAllZettels());
  });

  test('falls back to getAllZettels for a blank query', () async {
    when(
      () => repository.getAllZettels(),
    ).thenAnswer((_) async => const Right(<Zettel>[]));

    await usecase('   ');

    verify(() => repository.getAllZettels()).called(1);
    verifyNever(() => repository.searchZettels(any()));
  });
}
