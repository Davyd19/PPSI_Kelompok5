import 'auth_api.dart';

/// Profil akun Guru. Nama, NIP, dan identitas login dikelola Admin (baca saja);
/// email & telepon dapat diubah sendiri.
class TeacherProfile {
  const TeacherProfile({
    required this.name,
    required this.login,
    required this.status,
    this.nip,
    this.email,
    this.phone,
    this.roles = const [],
    this.homeroomClasses = const [],
    this.extracurriculars = const [],
  });

  factory TeacherProfile.fromJson(Map<String, dynamic> j) {
    List<String> list(String k) => List<String>.from(j[k] as List? ?? []);
    return TeacherProfile(
      name: j['nama'] as String,
      login: j['identitas_login'] as String,
      status: j['status_akun'] as String? ?? 'AKTIF',
      nip: j['nip'] as String?,
      email: j['email'] as String?,
      phone: j['telepon'] as String?,
      roles: list('peran'),
      homeroomClasses: list('wali_kelas'),
      extracurriculars: list('pembina_ekstrakurikuler'),
    );
  }

  final String name, login, status;
  final String? nip, email, phone;
  final List<String> roles, homeroomClasses, extracurriculars;

  /// Inisial untuk avatar, mis. "Guru Contoh" -> "GC".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class TeacherProfileApi {
  const TeacherProfileApi(this._api);
  final AuthApi _api;

  Future<TeacherProfile> load() async => TeacherProfile.fromJson(
    await _api.send('/guru/profil') as Map<String, dynamic>,
  );

  Future<TeacherProfile> updateContact({
    required String email,
    required String phone,
  }) async => TeacherProfile.fromJson(
    await _api.send(
          '/guru/profil',
          body: {'email': email.trim(), 'telepon': phone.trim()},
        )
        as Map<String, dynamic>,
  );

  Future<void> changePassword(String current, String next) =>
      _api.changePassword(current, next);
}
