import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/sync/application/sync_orchestrator.dart';
import 'package:second_brain/features/sync/domain/entities/sync_status.dart';

import 'bdd_world.dart';

/// Usage: a remote repository is configured
Future<void> aRemoteRepositoryIsConfigured(WidgetTester tester) async {
  // The vault is now backed by a remote, as after a fresh clone:
  // nothing to push yet, everything up to date.
  fakeGitSyncRepository.remoteConfigured = true;
  fakeGitSyncRepository.setStatus(const SyncStatus(state: SyncState.upToDate));

  // The world registers the orchestrator without starting it (see
  // bdd_world.dart); the offline-sync scenarios need the background loop
  // (vault watcher + connectivity listener), so start it here.
  getIt<SyncOrchestrator>().start();

  // Let the new status reach the AppBar sync indicator.
  await tester.pump();
}
