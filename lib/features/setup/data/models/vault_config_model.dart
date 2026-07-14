import '../../domain/entities/vault_config.dart';

/// Data-layer representation of the vault configuration persisted
/// in `SharedPreferences` (keys `vault_path` / `remote_url`).
class VaultConfigModel extends VaultConfig {
  const VaultConfigModel({required super.vaultPath, super.remoteUrl});
}
