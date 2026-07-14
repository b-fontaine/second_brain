import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/setup/data/models/vault_config_model.dart';
import 'package:second_brain/features/sync/domain/entities/sync_status.dart';

import 'bdd_world.dart';

/// Usage: a remote repository is configured at {'https://github.com/user/notes.git'}
///
/// Like `a remote repository is configured`, but also records [param1] as
/// the remote url of the persisted vault config, as after an onboarding
/// clone — the settings screen reads it from there.
Future<void> aRemoteRepositoryIsConfiguredAt(
  WidgetTester tester,
  String param1,
) async {
  fakeSetupLocalDataSource.config = VaultConfigModel(
    vaultPath: bddVaultDir.path,
    remoteUrl: param1,
  );
  fakeGitSyncRepository.remoteConfigured = true;
  fakeGitSyncRepository.setStatus(const SyncStatus(state: SyncState.upToDate));

  // Let the new status reach the AppBar sync indicator.
  await tester.pump();
}
