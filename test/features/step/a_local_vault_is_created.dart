import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'bdd_world.dart';

/// Usage: a local vault is created
Future<void> aLocalVaultIsCreated(WidgetTester tester) async {
  expect(
    fakeGitSyncRepository.initCalled,
    isTrue,
    reason: 'A local-only git repository should have been initialized',
  );
  expect(fakeVaultLocator.path, bddVaultDir.path);
  expect(
    fakeSetupLocalDataSource.config,
    isNotNull,
    reason: 'The vault configuration should be persisted',
  );
  for (final folder in const ['zettel', 'inbox', 'assets']) {
    expect(
      Directory(p.join(bddVaultDir.path, folder)).existsSync(),
      isTrue,
      reason: 'The vault should contain the $folder/ folder',
    );
  }
}
