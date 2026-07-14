import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';

import 'bdd_world.dart';

/// Usage: the zettel {'Concept B'} shows {'Concept A'} as a backlink
Future<void> theZettelShowsAsABacklink(
  WidgetTester tester,
  String param1,
  String param2,
) async {
  final target = await worldRequireZettelByTitle(param1);
  final expectedBacklink = await worldRequireZettelByTitle(param2);

  final result = await getIt<ZettelRepository>().getBacklinks(target.id);
  final backlinks = result.getOrElse(
    (failure) => throw StateError('getBacklinks: ${failure.message}'),
  );
  expect(
    backlinks.map((zettel) => zettel.id.value),
    contains(expectedBacklink.id.value),
    reason: "'$param2' should appear as a backlink of '$param1'",
  );
}
