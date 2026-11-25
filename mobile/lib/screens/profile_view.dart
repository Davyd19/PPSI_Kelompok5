import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/auth_api.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import 'account_dashboard.dart'
    show PortalList, isStaff, roleNames, showUnavailable;

/// Profil akun: identitas, kontak dari database, pengaturan, bantuan, dan keluar.
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

  String get _roleLabel => isStaff(profile.roles)
      ? 'Guru'
      : roleNames[profile.roles.first] ?? profile.roles.first;

  String get _initials => profile.name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final tone = PortalTone.of(context);
    final student = profile.roles.contains('SISWA');
    return PortalList(
      children: [
        BrandBand(
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x40FFFFFF), width: 3),
                ),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${profile.identity}',
                      style: const TextStyle(color: Color(0xFFB9C8DA)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tone.soft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_roleLabel · SMAN 12 Padang',
                        style: TextStyle(
                          color: tone.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const _Label('Informasi akun'),
        _Group(
          children: [
            _InfoTile(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              value: profile.email,
            ),
            _InfoTile(
              icon: Icons.phone_outlined,
              label: 'Nomor telepon',
              value: profile.phone,
            ),
            if (student) ...[
              _InfoTile(
                icon: Icons.badge_outlined,
                label: 'NISN',
                value: profile.nisn,
              ),
              _InfoTile(
                icon: Icons.numbers_rounded,
                label: 'NIS',
                value: profile.nis,
              ),
            ],
            _InfoTile(
              icon: Icons.alternate_email_rounded,
              label: 'Identitas login',
              value: profile.identity,
            ),
          ],
        ),
        const _Label('Pengaturan'),
        _Group(
          children: [
            _ActionTile(
              icon: Icons.lock_outline_rounded,
              label: 'Ubah kata sandi',
              onTap: () => showDetails(
                context,
                title: 'Ubah kata sandi',
                icon: Icons.lock_outline_rounded,
                child: const Text(
                  'Kata sandi diatur oleh Admin sekolah. Hubungi Admin untuk '
                  'mengganti kata sandi; semua sesi di perangkat lain akan '
                  'otomatis keluar setelah diganti.',
                ),
              ),
            ),
            _ActionTile(
              icon: Icons.notifications_none_rounded,
              label: 'Notifikasi',
              onTap: () => showUnavailable(context, 'Notifikasi'),
            ),
          ],
        ),
        const _Label('Bantuan'),
        _Group(
          children: [
            _ActionTile(
              icon: Icons.menu_book_outlined,
              label: 'Panduan penggunaan',
              onTap: () => showDetails(
                context,
                title: 'Panduan penggunaan',
                icon: Icons.menu_book_outlined,
                child: Text(_guide()),
              ),
            ),
            _ActionTile(
              icon: Icons.support_agent_outlined,
              label: 'Bantuan akun',
              onTap: () => showDetails(
                context,
                title: 'Bantuan akun',
                icon: Icons.support_agent_outlined,
                child: const Text(
                  'Data email, nomor telepon, dan kelas dikelola oleh Admin '
                  'sekolah. Bila ada data yang salah atau akun terkunci, '
                  'hubungi Admin atau bagian Kesiswaan.',
                ),
              ),
            ),
            _ActionTile(
              icon: Icons.info_outline_rounded,
              label: 'Tentang aplikasi',
              onTap: () => showDetails(
                context,
                title: 'SIM Kesiswaan',
                icon: Icons.school_outlined,
                child: const Text(
                  'Versi 1.0.0\nSistem informasi kedisiplinan, kehadiran, dan '
                  'ekstrakurikuler SMAN 12 Padang.',
                ),
              ),
            ),
          ],
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: cBrick.$1,
            side: BorderSide(color: cBrick.$2, width: 1.5),
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: busy ? null : () => _confirmLogout(context),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Keluar'),
        ),
      ],
    );
  }

  String _guide() {
    if (profile.roles.contains('SISWA')) {
      return '• Beranda: ringkasan presensi dan badge.\n'
          '• Ekskul: daftar kegiatan dan lihat riwayat kehadiran.\n'
          '• Saat kegiatan, tekan "Scan QR Presensi" lalu arahkan kamera ke QR di layar pembina.';
    }
    if (profile.roles.contains('ORANG_TUA')) {
      return '• Beranda: ringkasan kehadiran dan perkembangan anak.\n'
          '• Prestasi dan konseling: informasi yang diizinkan sekolah untuk orang tua.';
    }
    return '• Beranda: semua penugasan Anda tampil dalam satu halaman.\n'
        '• Pembina: buka sesi presensi, tekan "Tampilkan QR" agar anggota memindai, '
        'lalu tutup sesi. Anggota yang belum tercatat otomatis Alfa.\n'
        '• Fitur web Kesiswaan tersedia di portal web dengan akun yang sama.';
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Keluar dari akun?',
      icon: Icons.logout_rounded,
      iconColor: cBrick.$1,
      iconBackground: cBrick.$2,
      child: const Text('Anda perlu masuk kembali untuk memakai aplikasi.'),
      actions: [
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
        ),
        Builder(
          builder: (context) => FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cBrick.$1),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar'),
          ),
        ),
      ],
    );
    if (yes == true) onLogout();
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: PortalTone.of(context).ink,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: .9,
      ),
    ),
  );
}

/// Kartu berisi beberapa baris dengan garis pemisah tipis.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 58, color: line),
          child,
        ],
      ],
    ),
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, this.value});
  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.trim().isNotEmpty;
    return ListTile(
      leading: _TileIcon(icon),
      title: Text(label, style: const TextStyle(fontSize: 12, color: muted)),
      subtitle: Text(
        filled ? value! : 'Belum diisi',
        style: TextStyle(
          fontSize: 15,
          color: filled ? navy : const Color(0xFFA0AAB8),
          fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
          fontStyle: filled ? FontStyle.normal : FontStyle.italic,
        ),
      ),
      trailing: filled
          ? IconButton(
              tooltip: 'Salin $label',
              icon: const Icon(Icons.copy_rounded, size: 18, color: muted),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value!));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$label disalin')));
                }
              },
            )
          : null,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: _TileIcon(icon),
    title: Text(
      label,
      style: const TextStyle(color: navy, fontWeight: FontWeight.w600),
    ),
    trailing: const Icon(Icons.chevron_right_rounded, color: muted),
    onTap: onTap,
  );
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final tone = PortalTone.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: tone.color),
    );
  }
}
