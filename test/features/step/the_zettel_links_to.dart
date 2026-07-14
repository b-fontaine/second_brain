import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';

import 'bdd_world.dart';

/// Usage: the zettel {'Concept A'} links to {'Concept B'}
///
/// Dual-purpose (used both as a Given and as a Then across features):
/// ensures the wikilink exists — appending `[[id]]` to the source body when
/// missing — then asserts it is really parsed as an outgoing link.
Future<void> theZettelLinksTo(
  WidgetTester tester,
  String param1,
  String param2,
) async {
  final source = await worldRequireZettelByTitle(param1);
  final target = await worldRequireZettelByTitle(param2);

  if (!source.outgoingLinks.contains(target.id)) {
    final updated = source.copyWith(
      body: '${source.body}\n\n[[${target.id.value}|${target.title}]]',
    );
    final result = await getIt<ZettelRepository>().updateZettel(updated);
    result.getOrElse(
      (failure) => throw StateError('theZettelLinksTo: ${failure.message}'),
    );
    await tester.pumpAndSettle();
  }

  final refreshed = await worldRequireZettelByTitle(param1);
  expect(
    refreshed.outgoingLinks.map((id) => id.value),
    contains(target.id.value),
    reason: "'$param1' should contain a wikilink to '$param2'",
  );
}
