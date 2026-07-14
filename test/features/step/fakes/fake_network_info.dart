import 'dart:async';

import 'package:second_brain/core/services/network_info.dart';

/// Controllable connectivity.
///
/// Scripting: call [setOnline] to flip connectivity AND emit the change on
/// [onStatusChange] (what the sync layer listens to). Assign [online]
/// directly when you only want to change the polled value without an event.
class FakeNetworkInfo implements NetworkInfo {
  bool online = true;

  final StreamController<bool> controller = StreamController<bool>.broadcast();

  void setOnline(bool value) {
    online = value;
    controller.add(value);
  }

  @override
  Future<bool> get isConnected async => online;

  @override
  Stream<bool> get onStatusChange => controller.stream;

  Future<void> dispose() => controller.close();
}
