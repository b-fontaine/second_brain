import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the git token is updated
///
/// The token entered in the settings screen went through
/// GitSyncRepository.updateToken and is now the stored one.
Future<void> theGitTokenIsUpdated(WidgetTester tester) async {
  expect(
    fakeGitSyncRepository.updateTokenCalls,
    isNotEmpty,
    reason: 'GitSyncRepository.updateToken should have been invoked',
  );
  expect(
    fakeGitSyncRepository.storedToken,
    fakeGitSyncRepository.updateTokenCalls.last.trim(),
    reason: 'The tested token should now be the stored one',
  );
}
