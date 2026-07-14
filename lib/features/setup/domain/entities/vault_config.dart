import 'package:equatable/equatable.dart';

/// Persisted configuration of the vault, written at the end of onboarding.
class VaultConfig extends Equatable {
  const VaultConfig({required this.vaultPath, this.remoteUrl});

  /// Absolute path of the vault directory on this device.
  final String vaultPath;

  /// HTTPS url of the remote git repository; null when local-only.
  final String? remoteUrl;

  bool get hasRemote => remoteUrl != null && remoteUrl!.isNotEmpty;

  @override
  List<Object?> get props => [vaultPath, remoteUrl];
}
