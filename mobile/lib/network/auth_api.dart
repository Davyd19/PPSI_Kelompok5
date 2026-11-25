import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

abstract interface class SessionStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage();
  // iOS: simpan di Keychain hanya untuk perangkat ini (tidak ikut sinkron
  // iCloud/backup), tetap bisa dibaca setelah HP dibuka sekali.
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const _key = 'ppsik5.auth.session.v1';

  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

class AuthError implements Exception {
  const AuthError(this.message, [this.status, this.details]);
  final String message;
  final int? status;

  /// Pesan kesalahan per kolom dari server (mis. validasi formulir).
  final Map<String, dynamic>? details;
  @override
  String toString() => message;
}

class AccountProfile {
  const AccountProfile(
    this.name,
    this.identity,
    this.roles, {
    this.email,
    this.phone,
    this.nisn,
    this.nis,
    this.primaryRole,
    this.duties = const [],
  });
  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
    json['name'] as String,
    json['identitas_login'] as String,
    List<String>.from(json['available_roles'] as List),
    email: json['email'] as String?,
    phone: json['telepon'] as String?,
    nisn: json['nisn'] as String?,
    nis: json['nis'] as String?,
    primaryRole: json['primary_role'] as String?,
    duties: List<String>.from(json['duties'] as List? ?? []),
  );
  final String name;
  final String identity;
  final List<String> roles;
  final String? primaryRole;
  final List<String> duties;

  /// Data kontak dari database; null bila belum diisi Admin.
  final String? email, phone, nisn, nis;
}

typedef _Upload = ({List<int> bytes, String contentType, String filename});

class AuthApi {
  AuthApi({http.Client? client, SessionStorage? storage, String? baseUrl})
    : _client = client ?? http.Client(),
      _storage = storage ?? const SecureSessionStorage(),
      baseUrl = baseUrl ?? defaultApiBaseUrl;

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
    String method = 'POST',
    bool envelope = false,
    _Upload? upload,
  }) async {
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');
    final headers = {
      if (body != null) 'Content-Type': 'application/json',
      if (path == '/auth/login') 'Connection': 'close',
      if (upload != null) ...{
        'Content-Type': upload.contentType,
        'X-Filename': Uri.encodeComponent(upload.filename),
      },
      if (access != null) 'Authorization': 'Bearer $access',
    };
    http.Response response;
    try {
      response =
          await (upload != null
                  ? _client.post(uri, headers: headers, body: upload.bytes)
                  : body == null
                  ? _client.get(uri, headers: headers)
                  : method == 'PUT'
                  ? _client.put(uri, headers: headers, body: jsonEncode(body))
                  : _client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(Duration(seconds: upload == null ? 15 : 60));
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
        error is Map && error['details'] is Map
            ? Map<String, dynamic>.from(error['details'] as Map)
            : null,
      );
    }
    if (payload == null) throw const AuthError('Respons server tidak valid.');
    return envelope ? payload : payload['data'];
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

  Future<dynamic> _authenticated(
    String path, {
    Map<String, dynamic>? body,
    String method = 'POST',
    bool envelope = false,
    _Upload? upload,
  }) async {
    if (_loggingOut) throw const AuthError('Sesi sedang ditutup.', 401);
    if (_access == null) await _rotate();
    final sent = _access;
    try {
      return await _request(
        path,
        body: body,
        access: sent,
        envelope: envelope,
        method: method,
        upload: upload,
      );
    } on AuthError catch (error) {
      if (error.status != 401 || _loggingOut) rethrow;
      if (_access == sent) await _rotate();
      return _request(
        path,
        body: body,
        access: _access,
        envelope: envelope,
        method: method,
        upload: upload,
      );
    }
  }

  /// Ganti kata sandi. Server mencabut semua sesi lain dan mengirim token
  /// baru untuk perangkat ini sehingga pengguna tetap masuk.
  Future<void> changePassword(String current, String next) async {
    final data =
        await _authenticated(
              '/guru/profil/kata-sandi',
              body: {'kata_sandi_lama': current, 'kata_sandi_baru': next},
            )
            as Map<String, dynamic>;
    _access = data['access_token'] as String;
    _refresh = data['refresh_token'] as String;
    await _persist();
  }

  /// Unggah berkas biner (mis. foto bukti) secara terautentikasi.
  Future<dynamic> upload(
    String path, {
    required List<int> bytes,
    required String contentType,
    required String filename,
  }) => _authenticated(
    path,
    upload: (bytes: bytes, contentType: contentType, filename: filename),
  );

  /// Seperti [send] (GET), tetapi mengembalikan seluruh amplop `{data, meta}`.
  Future<Map<String, dynamic>> sendWithMeta(String path) async =>
      await _authenticated(path, envelope: true) as Map<String, dynamic>;

  /// Permintaan terautentikasi untuk modul fitur. `body == null` -> GET,
  /// selain itu POST JSON. Token akses diperbarui otomatis saat 401.
  Future<dynamic> send(String path, {Map<String, dynamic>? body}) =>
      _authenticated(path, body: body);

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

  /// Endpoint Pembina Ekstrakurikuler (`/pembina/...`), memakai sesi dan rotasi token yang sama.
  Future<dynamic> pembinaGet(String path) => _authenticated('/pembina$path');
  Future<dynamic> pembinaSend(
    String path, {
    String method = 'POST',
    Map<String, dynamic> body = const {},
  }) => _authenticated('/pembina$path', body: body, method: method);

  /// Endpoint ekskul untuk siswa (`/siswa/ekskul/...`).
  Future<dynamic> siswaGet(String path) => _authenticated('/siswa$path');
  Future<dynamic> siswaSend(String path) =>
      _authenticated('/siswa$path', body: const {});

  /// Presensi ekskul mandiri dengan kode dari QR pembina.
  Future<Map<String, dynamic>> scanEkskulAttendance(String code) async =>
      throw const AuthError(
        'Presensi ekstrakurikuler dicatat manual oleh Pembina.',
      );

  Future<List<Map<String, dynamic>>> badges() async =>
      List<Map<String, dynamic>>.from(
        await _authenticated('/student/badges') as List,
      );

  // Student specific API integrations
  Future<Map<String, dynamic>> studentDashboard() async {
    final res = await _authenticated('/student/dashboard');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> studentScanAttendance({
    String? qrCode,
    String? manualCode,
  }) async {
    final res = await _authenticated(
      '/student/attendance/scan',
      body: {
        'qr_code': qrCode ?? 'SMAN12-PRESENSI-GERBANG-UTAMA',
        if (manualCode != null) 'manual_code': manualCode,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> studentAttendanceHistory({
    int? year,
    int? month,
  }) async {
    final params = <String>[
      if (year != null) 'year=$year',
      if (month != null) 'month=$month',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final res = await _authenticated('/student/attendance/history$query');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> studentCounseling() async {
    final res = await _authenticated('/student/counseling');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> studentExtracurriculars() async {
    final res = await _authenticated('/student/extracurriculars');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> studentExtracurricularDetail(int id) async {
    final res = await _authenticated('/student/extracurriculars/$id');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> studentRegisterExtracurricular(int id) async {
    final res = await _authenticated(
      '/student/extracurriculars/$id/register',
      body: {'id': id},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> studentAchievements() async {
    final res = await _authenticated('/student/achievements');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> studentSubmitAchievement(
    Map<String, dynamic> data,
  ) async {
    final res = await _authenticated(
      '/student/achievements/submit',
      body: data,
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> studentNotifications() async {
    final res = await _authenticated('/student/notifications');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> studentNotificationDetail(int id) async {
    final res = await _authenticated('/student/notifications/$id');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> studentMarkNotificationsRead({int? id}) async {
    await _authenticated(
      '/student/notifications/read-all',
      body: {if (id != null) 'id': id},
    );
  }

  // Parent (Orang Tua) API integrations
  String _parentQuery({int? childId, int? year, int? month, String? jenis}) {
    final params = <String>[
      if (childId != null) 'child_id=$childId',
      if (year != null) 'year=$year',
      if (month != null) 'month=$month',
      if (jenis != null && jenis.isNotEmpty) 'jenis=$jenis',
    ];
    return params.isEmpty ? '' : '?${params.join('&')}';
  }

  Future<Map<String, dynamic>> parentDashboard({int? childId}) async {
    final res = await _authenticated(
      '/parent/dashboard${_parentQuery(childId: childId)}',
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> parentAttendance({
    int? childId,
    int? year,
    int? month,
    String? jenis,
  }) async {
    final res = await _authenticated(
      '/parent/attendance${_parentQuery(childId: childId, year: year, month: month, jenis: jenis)}',
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> parentAchievements({int? childId}) async {
    final res = await _authenticated(
      '/parent/achievements${_parentQuery(childId: childId)}',
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> parentBadges({int? childId}) async {
    final res = await _authenticated(
      '/parent/badges${_parentQuery(childId: childId)}',
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> parentExtracurriculars({int? childId}) async {
    final res = await _authenticated(
      '/parent/extracurriculars${_parentQuery(childId: childId)}',
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> parentCounseling({int? childId}) async {
    final res = await _authenticated(
      '/parent/counseling${_parentQuery(childId: childId)}',
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> parentCounselingDetail(
    int id, {
    int? childId,
  }) async {
    final res = await _authenticated(
      '/parent/counseling/$id${_parentQuery(childId: childId)}',
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> parentNotifications({int? childId}) async {
    final res = await _authenticated(
      '/parent/notifications${_parentQuery(childId: childId)}',
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> parentNotificationDetail(
    int id, {
    int? childId,
  }) async {
    final res = await _authenticated(
      '/parent/notifications/$id${_parentQuery(childId: childId)}',
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> parentMarkNotificationsRead({int? id}) async {
    await _authenticated(
      '/parent/notifications/read-all',
      body: {if (id != null) 'id': id},
    );
  }

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
