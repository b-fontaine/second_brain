import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:second_brain/features/setup/data/datasources/setup_local_data_source.dart';
import 'package:second_brain/features/setup/data/models/vault_config_model.dart';

/// In-memory onboarding persistence bound to the test's temp vault.
///
/// Scripting: leave [config] null for a first launch; the setup flow fills
/// it via [saveConfig]. [storedToken] captures the PAT the user "entered".
/// Unlike the real implementation, [createLocalVaultStructure] creates the
/// vault folders but NO welcome notes, so scenarios start on a truly empty
/// zettelkasten.
class FakeSetupLocalDataSource implements SetupLocalDataSource {
  FakeSetupLocalDataSource({required this.vaultPath, this.config});

  /// Absolute path of the temp vault used as `defaultVaultPath`.
  final String vaultPath;

  VaultConfigModel? config;

  String? storedToken;

  @override
  Future<VaultConfigModel?> getConfig() async => config;

  @override
  Future<void> saveConfig(VaultConfigModel newConfig) async =>
      config = newConfig;

  @override
  Future<void> storeToken(String token) async => storedToken = token;

  @override
  Future<String> defaultVaultPath() async => vaultPath;

  // Sync IO on purpose: async dart:io never completes under the FakeAsync
  // zone of testWidgets.
  @override
  Future<void> createVaultDirectory(String path) async =>
      Directory(path).createSync(recursive: true);

  @override
  Future<void> createLocalVaultStructure(String path) async {
    for (final folder in const ['zettel', 'inbox', 'assets']) {
      Directory(p.join(path, folder)).createSync(recursive: true);
    }
  }
}
