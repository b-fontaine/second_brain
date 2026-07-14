import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the draft references the original capture as source
///
/// The accepted zettel (resolved by the preceding "a zettel exists with
/// title" step into [worldLastZettel]) must carry the capture provenance
/// `capture:<type>:<ref>` in its `source` frontmatter field.
Future<void> theDraftReferencesTheOriginalCaptureAsSource(
  WidgetTester tester,
) async {
  final zettel = worldLastZettel;
  expect(
    zettel,
    isNotNull,
    reason: 'A previous step should have resolved the accepted zettel',
  );
  expect(
    zettel!.source,
    matches(RegExp(r'^capture:(clipboard|audio|screenshot|dictation):.+')),
    reason: 'The accepted note must reference its original capture',
  );
}
