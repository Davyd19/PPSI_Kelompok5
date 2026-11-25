import 'package:flutter/foundation.dart';

const _fromBuild = String.fromEnvironment('API_BASE_URL');

/// Alamat API backend.
///
/// Urutan prioritas:
/// 1. `--dart-define=API_BASE_URL=...` saat build/run (wajib untuk HP fisik
///    Android/iPhone, mis. `http://192.168.1.10:3000/api/v1`, atau server HTTPS).
/// 2. Bawaan pengembangan per platform:
///    - Android emulator: `10.0.2.2` = localhost komputer.
///    - iOS Simulator: berbagi jaringan dengan Mac, jadi cukup `127.0.0.1`.
String get defaultApiBaseUrl {
  if (_fromBuild.isNotEmpty) return _fromBuild;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'http://10.0.2.2:3000/api/v1',
    _ => 'http://127.0.0.1:3000/api/v1',
  };
}
