const exampleAccounts = <String, String>{
  'admin': 'admin',
  'kesiswaan': 'kesiswaan',
  'kepsek': 'kepala_sekolah',
  'siswa': 'siswa',
  'ortu': 'orang_tua',
  'guru': 'guru',
  'wali': 'wali_kelas',
  'bk': 'guru_bk',
  'pembina': 'pembina_ekstrakurikuler',
};
String? accountError(String identity, String password) {
  final role = exampleAccounts[identity.trim().toLowerCase()];
  if (role == null || password != 'Contoh123!') {
    return 'Identitas akun atau kata sandi salah.';
  }
  if (['admin', 'kesiswaan', 'kepala_sekolah'].contains(role)) {
    return 'Gunakan portal web untuk akun ini.';
  }
  return null;
}
