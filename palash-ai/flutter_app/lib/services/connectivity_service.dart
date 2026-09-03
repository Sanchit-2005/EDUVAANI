import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device currently has an active network connection.
///
/// Classroom content is always read from local storage, regardless of status.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Checks the current network connection status.
  Future<bool> get isOnline async {
    return _hasConnection(await _connectivity.checkConnectivity());
  }

  /// Emits the connection status whenever the network changes.
  Stream<bool> get onConnectionChanged {
    return _connectivity.onConnectivityChanged.map(_hasConnection).distinct();
  }

  /// Returns true when at least one network connection is available.
  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}