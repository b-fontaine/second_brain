import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'bdd_world.dart';

/// Usage: the repository is cloned locally
Future<void> theRepositoryIsClonedLocally(WidgetTester tester) async {
  expect(
    fakeGitSyncRepository.cloneCalled,
    isTrue,
    reason: 'GitSyncRepository.cloneRemote should have been invoked',
  );
  expect(fakeGitSyncRepository.clonedRemoteUrl, isNotNull);
  expect(
    fakeSetupLocalDataSource.storedToken,
    isNotNull,
    reason: 'The access token should have been stored',
  );
  expect(
    fakeVaultLocator.path,
    bddVaultDir.path,
    reason: 'The vault path should be published before cloning',
  );
  expect(
    Directory(p.join(bddVaultDir.path, 'zettel')).existsSync(),
    isTrue,
    reason: 'The cloned vault should exist on disk',
  );
}
