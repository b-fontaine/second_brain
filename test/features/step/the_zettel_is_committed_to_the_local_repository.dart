import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the zettel is committed to the local repository
Future<void> theZettelIsCommittedToTheLocalRepository(
  WidgetTester tester,
) async {
  expect(
    fakeGitSyncRepository.commitMessages,
    isNotEmpty,
    reason: 'Saving the zettel should have produced an automatic local commit',
  );
}
