import 'package:second_brain/core/services/clock.dart';
import 'package:second_brain/core/services/vault_locator.dart';

/// In-memory [VaultLocator] pointing at a test directory (or null to
/// simulate an unconfigured vault).
class FakeVaultLocator implements VaultLocator {
  FakeVaultLocator(this._path);

  String? _path;

  @override
  Future<String?> vaultPath() async => _path;

  @override
  Future<void> setVaultPath(String path) async => _path = path;

  @override
  Future<void> clearVaultPath() async => _path = null;
}

/// Manually advanced [Clock] so id generation is deterministic in tests.
class FakeClock implements Clock {
  FakeClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration duration) => current = current.add(duration);
}
