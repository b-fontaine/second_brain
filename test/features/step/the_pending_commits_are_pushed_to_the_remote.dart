import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the pending commits are pushed to the remote
Future<void> thePendingCommitsArePushedToTheRemote(WidgetTester tester) async {
  expect(
    fakeGitSyncRepository.pushedCommits,
    greaterThan(0),
    reason: 'At least one commit should have been pushed to the remote',
  );
  expect(
    fakeGitSyncRepository.pendingCommits,
    0,
    reason: 'No commit should remain pending after the push',
  );
}
