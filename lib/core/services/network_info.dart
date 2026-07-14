import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

/// Connectivity awareness for the opportunistic git sync.
abstract interface class NetworkInfo {
  Future<bool> get isConnected;

  /// Emits whenever connectivity appears or disappears.
  Stream<bool> get onStatusChange;
}

@LazySingleton(as: NetworkInfo)
class ConnectivityNetworkInfo implements NetworkInfo {
  ConnectivityNetworkInfo(this._connectivity);

  final Connectivity _connectivity;

  static bool _hasNetwork(List<ConnectivityResult> results) => results.any(
    (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
  );

  @override
  Future<bool> get isConnected async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();
}

@module
abstract class ConnectivityModule {
  @lazySingleton
  Connectivity get connectivity => Connectivity();
}
