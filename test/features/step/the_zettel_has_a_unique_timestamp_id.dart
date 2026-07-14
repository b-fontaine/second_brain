import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';

import 'bdd_world.dart';

/// Usage: the zettel has a unique timestamp id
///
/// "The zettel" is [worldLastZettel], set by the previous
/// "a zettel exists with title ..." assertion.
Future<void> theZettelHasAUniqueTimestampId(WidgetTester tester) async {
  final zettel = worldLastZettel;
  if (zettel == null) {
    fail('No zettel in scope: run "a zettel exists with title ..." first');
  }

  expect(
    RegExp(r'^\d{14}$').hasMatch(zettel.id.value),
    isTrue,
    reason: 'Zettel id "${zettel.id.value}" is not a yyyyMMddHHmmss timestamp',
  );

  final result = await getIt<ZettelRepository>().getAllZettels();
  final all = result.getOrElse(
    (failure) => throw StateError('getAllZettels: ${failure.message}'),
  );
  final sameId = all.where((other) => other.id.value == zettel.id.value);
  expect(
    sameId.length,
    1,
    reason: 'Id ${zettel.id.value} must be unique in the vault',
  );
}
