import 'dart:async';

import 'package:injectable/injectable.dart';

/// In-process signal fired whenever a git pull changed files in the vault.
///
/// The sync orchestrator relays it so the zettel data layer can re-index
/// the vault after remote changes land on disk.
@lazySingleton
class PullChangeNotifier {
  final _controller = StreamController<void>.broadcast();

  /// Emits after a pull applied remote changes to the working directory.
  Stream<void> get changes => _controller.stream;

  void notifyPulledChanges() {
    if (!_controller.isClosed) _controller.add(null);
  }

  @disposeMethod
  Future<void> dispose() => _controller.close();
}
