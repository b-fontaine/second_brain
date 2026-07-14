import 'dart:async';

import 'package:injectable/injectable.dart';

/// In-process signal fired when vault files change outside the zettel
/// repository stream (e.g. inbox captures written as JSON files).
///
/// The sync orchestrator treats it exactly like a zettel change:
/// debounce, auto-commit, opportunistic sync — a capture must never stay
/// uncommitted just because no note was edited afterwards.
@lazySingleton
class VaultWriteNotifier {
  final _controller = StreamController<void>.broadcast();

  /// Emits after a vault file was written or deleted.
  Stream<void> get changes => _controller.stream;

  void notifyWrite() {
    if (!_controller.isClosed) _controller.add(null);
  }

  @disposeMethod
  Future<void> dispose() => _controller.close();
}
