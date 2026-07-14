import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the vault lives on this device.
///
/// Written once by the setup feature, read by every data layer that
/// touches vault files. Null until onboarding completes.
abstract interface class VaultLocator {
  Future<String?> vaultPath();

  Future<void> setVaultPath(String path);

  /// Forgets the published path (setup rollback: a stored path marks the
  /// app as configured and skips onboarding forever).
  Future<void> clearVaultPath();
}

@LazySingleton(as: VaultLocator)
class PreferencesVaultLocator implements VaultLocator {
  static const _key = 'vault_path';

  @override
  Future<String?> vaultPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> setVaultPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }

  @override
  Future<void> clearVaultPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
