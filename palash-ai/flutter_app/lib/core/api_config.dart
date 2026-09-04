/// PALASH-AI — centralised API configuration
///
/// All backend URLs are defined here so they never get scattered across
/// multiple files.
///
/// For a physical Android device, pass the current host address at build time:
///
///   flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.46:3000
///
/// DHCP addresses can change. The in-app backend settings dialog is also
/// available for changing the address without changing the translation flow.
/// The default LAN value is only the last verified development address; provide
/// BACKEND_BASE_URL or BACKEND_LAN_IP for a different physical-device network.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  ApiConfig._();

  /// Last verified development Wi-Fi address for this workstation.
  /// DHCP can change it; override with --dart-define=BACKEND_LAN_IP=[current-host-ip]
  /// or use BACKEND_BASE_URL/the in-app server settings.
  static const String defaultLanIp = String.fromEnvironment(
    'BACKEND_LAN_IP',
    defaultValue: '192.168.1.46',
  );

  /// Optional build-time override, useful for physical devices and CI.
  static const String _buildBackendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  /// Runtime override from the translator settings dialog.
  static String? customBackendBaseUrl = _buildBackendBaseUrl.trim().isEmpty
      ? null
      : _buildBackendBaseUrl;

  static String _normalize(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  /// Returns the primary base URL of the Node.js backend based on platform.
  ///
  /// A physical phone needs BACKEND_BASE_URL or BACKEND_LAN_IP for the current
  /// DHCP address. Without an override, Android uses the emulator host alias;
  /// it never probes 127.0.0.1, which would point back to the device itself.
  /// The host address can also be entered in the Text Translator settings.
  static String get backendBaseUrl {
    final configured = customBackendBaseUrl;
    if (configured != null && configured.trim().isNotEmpty) {
      return _normalize(configured);
    }
    if (kIsWeb) return 'http://127.0.0.1:3000';
    try {
      if (Platform.isAndroid) {
        // 10.0.2.2 reaches the host from the Android emulator. A physical
        // device must be configured with BACKEND_BASE_URL or BACKEND_LAN_IP.
        return defaultLanIp.isNotEmpty
            ? 'http://$defaultLanIp:3000'
            : 'http://10.0.2.2:3000';
      }
    } catch (_) {
      // Platform is unavailable on some web compilation targets.
    }
    return 'http://127.0.0.1:3000';
  }

  /// Ordered backend candidates. A physical Android device must never probe
  /// 127.0.0.1 because that address points back to the phone itself.
  static List<String> get candidateBackendUrls {
    final configured = customBackendBaseUrl;
    if (configured != null && configured.trim().isNotEmpty) {
      return [_normalize(configured)];
    }
    if (kIsWeb) return ['http://127.0.0.1:3000'];
    try {
      if (Platform.isAndroid) {
        // Never send a physical-device request to 127.0.0.1. The emulator
        // alias is safe only when the app is actually running in an emulator.
        return [
          defaultLanIp.isNotEmpty
              ? 'http://$defaultLanIp:3000'
              : 'http://10.0.2.2:3000',
        ];
      }
    } catch (_) {
      // Fall through to the host-local default below.
    }
    return ['http://127.0.0.1:3000'];
  }

  static String translateUrlFor(String baseUrl) =>
      '${_normalize(baseUrl)}/api/translate';

  static String healthUrlFor(String baseUrl) => '${_normalize(baseUrl)}/health';

  /// POST /api/translate — IndicTrans2 Hindi ↔ Santali.
  static String get translateUrl => translateUrlFor(backendBaseUrl);

  /// GET /health — Node.js readiness endpoint.
  static String get healthUrl => healthUrlFor(backendBaseUrl);

  /// Maximum time allowed for one ML translation request. This is longer than
  /// the Node-to-Python timeout so a CPU model has time to finish inference.
  static const Duration translateTimeout = Duration(seconds: 35);

  /// Maximum time allowed for an explicit backend health probe.
  static const Duration healthTimeout = Duration(seconds: 4);
}
