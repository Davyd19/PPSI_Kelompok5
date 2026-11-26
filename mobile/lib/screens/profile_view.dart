import 'package:flutter/material.dart';

import '../network/auth_api.dart';
import 'account_dashboard.dart' show isStaff, roleNames;
import 'profile/profile_body.dart';

/// Profil akun Siswa / Orang Tua dengan tampilan yang sama seperti profil
/// Guru ([ProfileBody]). Data diri dan kontak dikelola Admin sekolah.
class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.profile,
    required this.busy,
    required this.onLogout,
  });

  final AccountProfile profile;
  final bool busy;
  final VoidCallback onLogout;

  bool get _student => profile.roles.contains('SISWA');

  String get _roleLabel => isStaff(profile.roles)
      ? 'Guru'
      : roleNames[profile.roles.first] ?? profile.roles.first;

  ProfileData get _data => ProfileData(
    name: profile.name,
    login: profile.identity,
    roleLabel: _roleLabel,
    identities: [
      if (_student) ('NISN', profile.nisn),
      if (_student) ('NIS', profile.nis),
    ],
    identityNote: _student
        ? 'Nama, NISN, dan NIS hanya dapat diubah oleh Admin sekolah.'
        : 'Data diri hanya dapat diubah oleh Admin sekolah.',
    email: profile.email,
    phone: profile.phone,
    roles: [
      _roleLabel,
      for (final d in profile.duties)
        if ((roleNames[d] ?? d) != _roleLabel) roleNames[d] ?? d,
    ],
    guide: _guide(),
  );

  String _guide() {
    if (_student) {
      return '• Beranda: ringkasan presensi dan badge.\n'
          '• Ekskul: daftar kegiatan dan lihat riwayat kehadiran.\n'
          '• Presensi sekolah: pindai QR Guru pada waktu yang berlaku. Presensi ekskul dicatat manual oleh Pembina.';
    }
    if (profile.roles.contains('ORANG_TUA')) {
      return '• Beranda: ringkasan kehadiran dan perkembangan anak.\n'
          '• Prestasi dan konseling: informasi yang diizinkan sekolah untuk orang tua.';
    }
    return '• Beranda: semua penugasan Anda tampil dalam satu halaman.\n'
        '• Pembina: buka sesi presensi dan catat kehadiran anggota satu per satu, '
        'lalu tutup sesi. Belum Diisi tidak otomatis menjadi Alfa.\n'
        '• Fitur tambahan mengikuti penugasan aktif. Portal Kesiswaan memakai akun dengan peran utama Kesiswaan.';
  }

  @override
  Widget build(BuildContext context) =>
      ProfileBody(data: _data, loggingOut: busy, onLogout: onLogout);
}
