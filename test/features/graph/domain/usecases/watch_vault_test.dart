import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/graph/domain/usecases/watch_vault.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';

class MockZettelRepository extends Mock implements ZettelRepository {}

void main() {
  test('WatchVault forwards vault change events as Right', () async {
    final repository = MockZettelRepository();
    when(repository.watchVault).thenAnswer(
      (_) => Stream.fromIterable(const [VaultChanged(), VaultChanged()]),
    );
    final useCase = WatchVault(repository);

    final events = await useCase(const NoParams()).toList();

    expect(events, hasLength(2));
    for (final event in events) {
      expect(event, isA<Right<Failure, VaultChanged>>());
    }
  });
}
