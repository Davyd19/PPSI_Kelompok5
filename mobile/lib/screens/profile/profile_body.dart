import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';
import '../../widgets/school_ui.dart';

const profileRed = Color(0xFFC62828);

/// Data yang ditampilkan halaman profil, sama untuk semua peran
/// (Guru, Guru BK, Siswa, Orang Tua).
class ProfileData {
  const ProfileData({
    required this.name,
    required this.login,
    required this.roleLabel,
    this.status,
    this.identities = const [],
    this.identityNote,
    this.email,
    this.phone,
    this.roles = const [],
    this.tasks = const [],
    this.headerNote,
    this.guide,
  });

  final String name, login, roleLabel;

  /// Status akun ('AKTIF' / lainnya); null bila tidak diketahui.
  final String? status;

  /// Nomor identitas resmi, mis. ('NIP', '1980...') atau ('NISN', '00...').
  final List<(String, String?)> identities;

  /// Catatan siapa yang boleh mengubah data diri.
  final String? identityNote;
  final String? email, phone;

  /// Label peran/tugas yang ditampilkan sebagai pil.
  final List<String> roles;

  /// Rincian tugas: (label, nilai, ikon), mis. wali kelas atau ekskul binaan.
  final List<(String, String, IconData)> tasks;

  /// Baris tambahan di kepala profil, mis. "Wali Kelas X 1".
  final String? headerNote;

  /// Panduan penggunaan sesuai peran.
  final String? guide;

  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  /// Baris di bawah nama pada kepala profil.
  String get headerSubtitle {
    for (final (label, value) in identities) {
      if (value != null && value.trim().isNotEmpty) return '$label $value';
    }
    return '$roleLabel • SMAN 12 Padang';
  }
}

/// Tampilan profil bersama untuk semua peran. Tombol ubah kontak dan ganti
/// kata sandi hanya aktif bila callback-nya tersedia; bila tidak, pengguna
/// diarahkan ke Admin sekolah.
class ProfileBody extends StatelessWidget {
  const ProfileBody({
    super.key,
    required this.data,
    required this.onLogout,
    this.loggingOut = false,
    this.onEditContact,
    this.onChangePassword,
    this.onRefresh,
  });

  final ProfileData data;

  /// Dipanggil setelah pengguna mengonfirmasi keluar.
  final VoidCallback onLogout;
  final bool loggingOut;
  final VoidCallback? onEditContact;
  final VoidCallback? onChangePassword;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: _content(context),
        ),
      ),
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }

  List<Widget> _content(BuildContext context) {
    final p = data;
    return [
      ProfileHeader(data: p),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Data Diri',
        icon: Icons.badge_outlined,
        color: sectionBlue,
        child: Column(
          children: [
            _InfoRow(Icons.person_outline, 'Nama lengkap', p.name),
            for (final (label, value) in p.identities)
              _InfoRow(Icons.numbers, label, value ?? '-'),
            _InfoRow(Icons.alternate_email, 'Identitas akun', p.login),
            if (p.status != null)
              _InfoRow(
                Icons.verified_user_outlined,
                'Status akun',
                p.status == 'AKTIF' ? 'Aktif' : 'Nonaktif',
              ),
            if (p.identityNote != null) ...[
              const SizedBox(height: 4),
              Text(
                p.identityNote!,
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ],
        ),
      ),
      SectionCard(
        title: 'Kontak',
        icon: Icons.contact_phone_outlined,
        color: sectionGreen,
        trailing: onEditContact == null
            ? null
            : TextButton.icon(
                onPressed: onEditContact,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Ubah'),
              ),
        child: Column(
          children: [
            _InfoRow(Icons.email_outlined, 'Email', p.email ?? 'Belum diisi'),
            _InfoRow(Icons.phone_outlined, 'Telepon', p.phone ?? 'Belum diisi'),
            if (onEditContact == null) ...[
              const SizedBox(height: 4),
              const Text(
                'Kontak dikelola oleh Admin sekolah.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ],
        ),
      ),
      SectionCard(
        title: p.tasks.isEmpty ? 'Peran' : 'Tugas',
        icon: Icons.work_outline,
        color: sectionPurple,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in p.roles.isEmpty ? [p.roleLabel] : p.roles)
                  ColorPill(r, color: sectionPurple),
              ],
            ),
            for (final (label, value, icon) in p.tasks)
              _InfoRow(icon, label, value),
          ],
        ),
      ),
      SectionCard(
        title: 'Keamanan',
        icon: Icons.lock_outline,
        color: sectionOrange,
        padding: EdgeInsets.zero,
        child: _Tappable(
          leading: const Icon(Icons.password, color: sectionOrange),
          title: const Text('Ganti kata sandi'),
          subtitle: Text(
            onChangePassword == null
                ? 'Hubungi Admin sekolah untuk mengganti'
                : 'Perangkat lain akan otomatis dikeluarkan',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap:
              onChangePassword ??
              () => _info(
                context,
                'Ganti kata sandi',
                'Kata sandi akun Anda diatur oleh Admin sekolah. Hubungi Admin '
                    'untuk mengganti kata sandi; semua sesi di perangkat lain '
                    'akan otomatis keluar setelah diganti.',
              ),
        ),
      ),
      SectionCard(
        title: 'Bantuan',
        icon: Icons.info_outline,
        color: attendanceTeal,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            if (p.guide != null)
              _Tappable(
                dense: true,
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Panduan penggunaan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _info(context, 'Panduan penggunaan', p.guide!),
              ),
            _Tappable(
              dense: true,
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Bantuan akun'),
              subtitle: const Text('Hubungi Admin sekolah'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _info(
                context,
                'Bantuan akun',
                'Untuk perubahan nama, nomor identitas, peran, atau lupa kata '
                    'sandi, hubungi Admin sekolah atau bagian Kesiswaan.',
              ),
            ),
            const _Tappable(
              dense: true,
              leading: SchoolLogo(size: 28),
              title: Text('SIM Kesiswaan'),
              subtitle: Text('Versi 1.0.0 • SMAN 12 Padang'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      ProfileLogoutButton(
        loggingOut: loggingOut,
        onConfirmed: onLogout,
      ),
    ];
  }

  static Future<void> _info(BuildContext context, String title, String body) =>
      showDialog<void>(
        context: context,
        builder: (context) => SchoolDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
}

/// Kepala profil: avatar inisial, nama, nomor identitas, catatan tambahan.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) => SchoolBrandPanel(
    child: Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: Colors.white,
          child: Text(
            data.initials,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: navy,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.headerSubtitle,
                style: const TextStyle(color: Color(0xFFD9E9FA), fontSize: 12),
              ),
              if (data.headerNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data.headerNote!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Tombol keluar merah dengan dialog konfirmasi.
class ProfileLogoutButton extends StatelessWidget {
  const ProfileLogoutButton({
    super.key,
    required this.onConfirmed,
    this.loggingOut = false,
  });
  final VoidCallback onConfirmed;
  final bool loggingOut;

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => SchoolDialog(
        icon: const Icon(Icons.logout, color: profileRed),
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda perlu masuk kembali untuk memakai aplikasi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: profileRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, keluar'),
          ),
        ],
      ),
    );
    if (ok == true) onConfirmed();
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: profileRed,
      side: const BorderSide(color: profileRed),
      minimumSize: const Size.fromHeight(48),
    ),
    onPressed: loggingOut ? null : () => _confirm(context),
    icon: const Icon(Icons.logout),
    label: Text(loggingOut ? 'Keluar...' : 'Keluar'),
  );
}

/// ListTile dengan Material sendiri agar efek sentuh terlihat di atas
/// latar berwarna SectionCard.
class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dense = false,
  });
  final Widget leading, title;
  final Widget? subtitle, trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ListTile(
      dense: dense,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: muted)),
              Text(
                value,
                style: const TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
