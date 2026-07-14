import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the remote rejects the token {'bad-token'}
///
/// Scripts the fake git backend to refuse this token on every connection
/// test, as a revoked/expired PAT would be.
Future<void> theRemoteRejectsTheToken(
  WidgetTester tester,
  String param1,
) async {
  fakeGitSyncRepository.rejectedTokens.add(param1);
}
