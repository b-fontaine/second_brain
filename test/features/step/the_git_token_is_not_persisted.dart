import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the git token is not persisted
///
/// A rejected token must never be written: the stored token is unchanged
/// (none in these scenarios, where no clone ever ran).
Future<void> theGitTokenIsNotPersisted(WidgetTester tester) async {
  expect(
    fakeGitSyncRepository.storedToken,
    isNull,
    reason: 'A rejected token must not be persisted',
  );
}
