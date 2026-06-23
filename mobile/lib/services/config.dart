import 'dart:io' show Platform;

/// App-wide configuration read from --dart-define flags (or env / dev fallback).
class AppConfig {
  AppConfig._();

  static const String _devSecret = 'gpx-dev-secret-do-not-use-in-production';
  static const String _envKey = 'GATEPASSX_QR_SECRET';
  static bool _warned = false;

  /// The secret used to HMAC-sign QR payloads.
  ///
  /// Precedence:
  /// 1. --dart-define=GATEPASSX_QR_SECRET=...
  /// 2. Platform.environment['GATEPASSX_QR_SECRET']
  /// 3. Insecure dev default (prints a warning once)
  static String get qrSecret {
    const fromDefine = String.fromEnvironment(_envKey);
    if (fromDefine.isNotEmpty) return fromDefine;

    final fromEnv = Platform.environment[_envKey];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

    if (!_warned) {
      _warned = true;
      // ignore: avoid_print
      print(
        'WARNING: $_envKey not set via --dart-define or environment. '
        'Using insecure dev default. Set --dart-define=$_envKey=... for production builds.',
      );
    }
    return _devSecret;
  }
}
