import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

abstract interface class SessionStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage();
  static const _storage = FlutterSecureStorage();
  static const _key = 'ppsik5.auth.session.v1';

  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

class AuthError implements Exception {
  const AuthError(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class AccountProfile {
  const AccountProfile(this.name, this.identity, this.roles);
  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
    json['name'] as String,
    json['identitas_login'] as String,
    List<String>.from(json['available_roles'] as List),
  );
  final String name;
  final String identity;
  final List<String> roles;
}

class AuthApi {
  AuthApi({http.Client? client, SessionStorage? storage, String? baseUrl})
    : _client = client ?? http.Client(),
      _storage = storage ?? const SecureSessionStorage(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:3000/api/v1',
          );

  final http.Client _client;
  final SessionStorage _storage;
  final String baseUrl;
  String? _access, _refresh;
  final _pendingLogout = <String>[];
  Future<void>? _initial, _refreshing, _flushing;
  Future<void> _diskWrites = Future.value();
  bool _loggingOut = false;
  void Function()? onExpired;

  Future<void> _load() => _initial ??= _read();
  Future<void> _read() async {
    final raw = await _storage.read();
    if (raw == null) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _refresh = data['refresh'] as String?;
    _pendingLogout.addAll(List<String>.from(data['logout'] as List? ?? []));
  }

  Future<void> _persist() {
    // Serialize writes so an older snapshot cannot restore a session after logout.
    final snapshot = jsonEncode({
      'refresh': _refresh,
      'logout': _pendingLogout,
    });
    final write = _diskWrites.then((_) => _storage.write(snapshot));
    _diskWrites = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }

  Future<dynamic> _request(
    String path, {
    Map<String, dynamic>? body,
    String? access,
  }) async {
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');
    final headers = {
      if (body != null) 'Content-Type': 'application/json',
      if (access != null) 'Authorization': 'Bearer $access',
    };
    http.Response response;
    try {
      response =
          await (body == null
                  ? _client.get(uri, headers: headers)
                  : _client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const AuthError('Server tidak merespons. Coba lagi.');
    } on Exception {
      throw const AuthError('Server tidak dapat dihubungi. Periksa koneksi.');
    }
    if (response.statusCode == 204) return null;
    Map<String, dynamic>? payload;
    try {
      payload =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      // Preserve the HTTP status for error handling even with a non-JSON response.
    } on TypeError {
      // The API envelope must be a JSON object.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload?['error'];
      throw AuthError(
        error is Map
            ? error['message']?.toString() ?? 'Permintaan gagal.'
            : 'Permintaan gagal.',
        response.statusCode,
      );
    }
    if (payload == null) throw const AuthError('Respons server tidak valid.');
    return payload['data'];
  }

  Future<AccountProfile> login(String identity, String password) async {
    await _load();
    final data =
        await _request(
              '/auth/login',
              body: {
                'identitas_akun': identity,
                'kata_sandi': password,
                'platform': 'mobile',
              },
            )
            as Map<String, dynamic>;
    _access = data['access_token'] as String;
    _refresh = data['refresh_token'] as String;
    await _persist();
    unawaited(retryPendingLogout());
    return AccountProfile.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> _rotate() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final refresh = _performRefresh();
    _refreshing = refresh;
    return refresh.whenComplete(() => _refreshing = null);
  }

  Future<void> _performRefresh() async {
    if (_refresh == null || _loggingOut) {
      throw const AuthError('Sesi berakhir.', 401);
    }
    try {
      final data =
          await _request('/auth/refresh', body: {'refresh_token': _refresh})
              as Map<String, dynamic>;
      _access = data['access_token'] as String;
      _refresh = data['refresh_token'] as String;
      await _persist();
    } on AuthError catch (error) {
      if (error.status == 401 || error.status == 403) {
        _access = _refresh = null;
        await _persist();
        onExpired?.call();
      }
      rethrow;
    }
  }

  Future<dynamic> _authenticated(String path) async {
    if (_loggingOut) throw const AuthError('Sesi sedang ditutup.', 401);
    if (_access == null) await _rotate();
    final sent = _access;
    try {
      return await _request(path, access: sent);
    } on AuthError catch (error) {
      if (error.status != 401 || _loggingOut) rethrow;
      if (_access == sent) await _rotate();
      return _request(path, access: _access);
    }
  }

  Future<AccountProfile?> restore() async {
    await _load();
    unawaited(retryPendingLogout());
    if (_refresh == null) return null;
    try {
      return await profile();
    } on AuthError catch (error) {
      if (error.status == 401 || error.status == 403) return null;
      rethrow;
    }
  }

  Future<AccountProfile> profile() async => AccountProfile.fromJson(
    await _authenticated('/auth/me') as Map<String, dynamic>,
  );
  Future<List<Map<String, dynamic>>> badges() async =>
      List<Map<String, dynamic>>.from(
        await _authenticated('/student/badges') as List,
      );

  Future<void> logout() async {
    _loggingOut = true;
    try {
      await _load();
      try {
        await _refreshing;
      } catch (_) {}
      if (_refresh != null && !_pendingLogout.contains(_refresh)) {
        _pendingLogout.add(_refresh!);
      }
      _refresh = _access = null;
      await _persist();
      unawaited(retryPendingLogout());
    } finally {
      _loggingOut = false;
    }
  }

  Future<void> retryPendingLogout() {
    final inFlight = _flushing;
    if (inFlight != null) return inFlight;
    final flushing = _flush();
    _flushing = flushing;
    return flushing.whenComplete(() => _flushing = null);
  }

  Future<void> _flush() async {
    try {
      await _load();
      for (final token in List<String>.from(_pendingLogout)) {
        await _request('/auth/logout', body: {'refresh_token': token});
        _pendingLogout.remove(token);
        await _persist();
      }
    } catch (_) {
      // The queue remains on disk and is retried on startup, resume and periodically.
    }
  }

  void close() => _client.close();
}
