import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device currently has an active network connection.
/// Classroom content is always read from local storage, regardless of status.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> get isOnline async => _hasConnection(await _connectivity.checkConnectivity());

  Stream<bool> get onConnectionChanged => _connectivity.onConnectivityChanged
      .map(_hasConnection)
      .distinct();

  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
