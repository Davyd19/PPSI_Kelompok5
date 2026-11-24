import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/shared.dart';

// Alias lama dipertahankan agar layar lain otomatis memakai token baru.
const portalSoft = soft;
const portalTeal = Color(0xFF226A75);
const portalNavy = navy;

const roleNames = {
  'SISWA': 'Siswa',
  'ORANG_TUA': 'Orang Tua',
  'GURU': 'Guru',
  'WALI_KELAS': 'Wali Kelas',
  'GURU_BK': 'Guru BK',
  'PEMBINA_EKSTRAKURIKULER': 'Pembina Ekstrakurikuler',
};

const roleIcons = {
  'SISWA': Icons.school_outlined,
  'ORANG_TUA': Icons.family_restroom_outlined,
  'GURU': Icons.co_present_outlined,
  'WALI_KELAS': Icons.groups_outlined,
  'GURU_BK': Icons.support_agent_outlined,
  'PEMBINA_EKSTRAKURIKULER': Icons.emoji_events_outlined,
};

void showUnavailable(BuildContext context, String title) {
  showDetails(
    context,
    title: title,
    icon: Icons.construction_rounded,
    child: const Text(
      'Fitur ini sedang dikembangkan dan akan segera tersedia.',
    ),
  );
}

/// Ikon dalam kotak lembut. Tanpa [accent], warnanya mengikuti aksen akun (PortalTone).
class PortalIcon extends StatelessWidget {
  const PortalIcon(this.icon, {super.key, this.dark = false, this.accent});
  final IconData icon;
  final bool dark;
  final (Color, Color)? accent;

  @override
  Widget build(BuildContext context) {
    final tone = PortalTone.of(context);
    final (fg, bg) = dark
        ? (Colors.white, const Color(0x1FFFFFFF))
        : accent ?? (tone.color, tone.soft);
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 21, color: fg),
    );
  }
}

class PortalList extends StatelessWidget {
  const PortalList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(height: 14),
            FadeSlideIn(index: index, child: child),
          ],
        ],
      ),
    ),
  );
}

typedef PortalAction = ({String label, IconData icon});

/// Peran mobile yang menandakan akun guru. Guru tidak memilih peran:
/// semua penugasan aktifnya (wali kelas, BK, pembina) tampil dalam satu beranda.
const staffRoles = {'GURU', 'WALI_KELAS', 'GURU_BK', 'PEMBINA_EKSTRAKURIKULER'};
bool isStaff(List<String> roles) => roles.any(staffRoles.contains);

/// Penugasan tambahan guru, berurutan, tanpa peran dasar GURU.
List<String> assignmentsOf(List<String> roles) =>
    staffRoles.where((r) => r != 'GURU' && roles.contains(r)).toList();

class AccountDashboard extends StatelessWidget {
  const AccountDashboard({
    super.key,
    required this.name,
    required this.roles,
    required this.onBadges,
    this.onPembina,
    this.onScanQr,
  });

  final String name;
  final List<String> roles;
  final VoidCallback onBadges;
  final VoidCallback? onPembina;

  /// Siswa: membuka pemindai QR presensi ekskul.
  final VoidCallback? onScanQr;

  @override
  Widget build(BuildContext context) {
    final staff = isStaff(roles);
    final main = staff ? 'GURU' : roles.first;
    final assignments = staff ? assignmentsOf(roles) : const <String>[];
    final tone = PortalTone.of(context);
    return PortalList(
      children: [
        BrandBand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PortalIcon(
                    roleIcons[main] ?? Icons.person_outline,
                    dark: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting().toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFB9C8DA),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final role in [main, ...assignments])
                    Chip(
                      avatar: Icon(roleIcons[role], size: 15, color: tone.ink),
                      label: Text(roleNames[role] ?? role),
                      labelStyle: TextStyle(
                        color: tone.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: tone.soft,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
        ...switch (main) {
          'SISWA' => [
            const _FeaturePanel(
              title: 'Presensi Sekolah',
              icon: Icons.fact_check_outlined,
              description: 'Ringkasan presensi sedang dikembangkan.',
              tinted: true,
            ),
            _ActionCards(
              actions: const [
                (
                  label: 'Koleksi Badge',
                  icon: Icons.workspace_premium_outlined,
                ),
                (label: 'Scan Presensi Ekskul', icon: Icons.qr_code_scanner),
                (label: 'Riwayat Presensi', icon: Icons.history),
              ],
              onAction: (action) => switch (action.label) {
                'Koleksi Badge' => onBadges(),
                'Scan Presensi Ekskul' when onScanQr != null => onScanQr!(),
                _ => showUnavailable(context, action.label),
              },
            ),
            const _SectionTitle('Aktivitas Terbaru'),
            const _FeaturePanel(
              title: 'Aktivitas Siswa',
              icon: Icons.list_alt_outlined,
              description: 'Aktivitas belum terhubung.',
            ),
          ],
          'ORANG_TUA' => [
            const _FeaturePanel(
              title: 'Kehadiran Anak',
              icon: Icons.calendar_month_outlined,
              description: 'Ringkasan kehadiran anak belum terhubung.',
            ),
            const _SectionTitle('Perkembangan Anak'),
            _ActionCards(
              actions: const [
                (label: 'Prestasi Anak', icon: Icons.emoji_events_outlined),
                (label: 'Ringkasan Penanganan', icon: Icons.shield_outlined),
              ],
              onAction: (action) => showUnavailable(context, action.label),
            ),
            const _FeaturePanel(
              title: 'Wali Kelas',
              icon: Icons.forum_outlined,
              description: 'Informasi wali kelas belum terhubung.',
              tinted: true,
            ),
          ],
          _ => [
            ..._staff(
              context,
              contextTitle: 'Tugas Sekolah',
              contextDescription:
                  'Informasi tugas dan sesi sekolah belum terhubung.',
              icon: Icons.school_outlined,
              actions: const [
                (label: 'Buka Sesi Presensi', icon: Icons.qr_code_scanner),
                (label: 'Lapor Pelanggaran', icon: Icons.gavel_outlined),
                (label: 'Rekap Kehadiran', icon: Icons.list_alt_outlined),
              ],
              section: 'Monitoring Presensi',
              description: 'Rekap sesi sekolah belum terhubung.',
            ),
            if (assignments.contains('WALI_KELAS'))
              ..._assignment(
                context,
                title: 'Wali Kelas',
                panelTitle: 'Kelas Binaan',
                description: 'Informasi kelas binaan belum terhubung.',
                icon: Icons.groups_outlined,
                actions: const [
                  (
                    label: 'Rekap Presensi Kelas',
                    icon: Icons.calendar_month_outlined,
                  ),
                  (label: 'Kasus Binaan', icon: Icons.folder_open_outlined),
                  (label: 'Tindak Lanjut', icon: Icons.assignment_outlined),
                ],
              ),
            if (assignments.contains('GURU_BK'))
              ..._assignment(
                context,
                title: 'Guru BK',
                panelTitle: 'Ringkasan Penanganan',
                description: 'Daftar kasus sesuai kewenangan belum terhubung.',
                icon: Icons.shield_outlined,
                actions: const [
                  (label: 'Kasus Ditangani', icon: Icons.folder_open_outlined),
                  (label: 'Rencana Konseling', icon: Icons.event_note_outlined),
                  (label: 'Asesmen', icon: Icons.assignment_outlined),
                ],
              ),
            if (assignments.contains('PEMBINA_EKSTRAKURIKULER')) ...[
              const _SectionTitle('Pembina Ekstrakurikuler'),
              AppPanel(
                color: tone.soft,
                child: Row(
                  children: [
                    const PortalIcon(Icons.emoji_events_outlined),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Kelola pertemuan, presensi anggota, pendaftaran, dan prestasi kegiatan yang Anda bina.',
                        style: TextStyle(color: muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onPembina,
                      child: const Text('Buka'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        },
      ],
    );
  }

  List<Widget> _assignment(
    BuildContext context, {
    required String title,
    required String panelTitle,
    required String description,
    required IconData icon,
    required List<PortalAction> actions,
  }) => [
    _SectionTitle(title),
    _FeaturePanel(
      title: panelTitle,
      icon: icon,
      description: description,
      tinted: true,
    ),
    _ActionCards(
      actions: actions,
      onAction: (action) => showUnavailable(context, action.label),
    ),
  ];

  List<Widget> _staff(
    BuildContext context, {
    required String contextTitle,
    required String contextDescription,
    required IconData icon,
    required List<PortalAction> actions,
    required String section,
    required String description,
  }) => [
    _FeaturePanel(
      title: contextTitle,
      icon: icon,
      description: contextDescription,
      tinted: true,
    ),
    const _SectionTitle('Aksi Cepat'),
    _ActionCards(
      actions: actions,
      onAction: (action) => showUnavailable(context, action.label),
    ),
    _FeaturePanel(
      title: section,
      icon: Icons.event_note_outlined,
      description: description,
    ),
  ];
}

String _greeting() {
  final hour = DateTime.now().hour;
  return hour < 11
      ? 'Selamat pagi'
      : hour < 15
      ? 'Selamat siang'
      : hour < 18
      ? 'Selamat sore'
      : 'Selamat malam';
}

/// Judul bagian bergaya label kecil berwarna aksen, sama seperti eyebrow di portal web.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        color: PortalTone.of(context).ink,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: .9,
      ),
    ),
  );
}

class _FeaturePanel extends StatelessWidget {
  const _FeaturePanel({
    required this.title,
    required this.icon,
    required this.description,
    this.tinted = false,
  });

  final String title, description;
  final IconData icon;
  final bool tinted;

  @override
  Widget build(BuildContext context) => AppPanel(
    color: tinted ? PortalTone.of(context).soft : Colors.white,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalIcon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: navy),
              ),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(color: muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActionCards extends StatelessWidget {
  const _ActionCards({required this.actions, required this.onAction});
  final List<PortalAction> actions;
  final ValueChanged<PortalAction> onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14);
      final count = textScale > 20 || constraints.maxWidth < 295
          ? 1
          : actions.length;
      final width = (constraints.maxWidth - (count - 1) * 8) / count;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (i, action) in actions.indexed)
            SizedBox(
              width: width,
              child: PressScale(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => onAction(action),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warna ikon bergantian agar deret aksi tidak monoton.
                      PortalIcon(
                        action.icon,
                        accent: accentCycle[i % accentCycle.length],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
