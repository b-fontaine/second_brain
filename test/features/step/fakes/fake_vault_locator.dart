import 'package:second_brain/core/services/vault_locator.dart';

/// In-memory vault locator.
///
/// Scripting: leave [path] null to simulate a first launch (no vault
/// configured); assign the temp vault path to simulate a configured app.
/// The setup flow calls [setVaultPath] itself during onboarding scenarios.
class FakeVaultLocator implements VaultLocator {
  FakeVaultLocator({this.path});

  String? path;

  @override
  Future<String?> vaultPath() async => path;

  @override
  Future<void> setVaultPath(String newPath) async => path = newPath;

  @override
  Future<void> clearVaultPath() async => path = null;
}
