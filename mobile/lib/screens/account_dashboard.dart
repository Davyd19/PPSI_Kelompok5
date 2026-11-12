import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/shared.dart';

const portalSoft = Color(0xFFECF2FD);
const portalTeal = Color(0xFF236A7C);
const portalNavy = Color(0xFF203B60);

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
    child: const Text('Fitur ini sedang dikembangkan.'),
  );
}

class PortalIcon extends StatelessWidget {
  const PortalIcon(this.icon, {super.key, this.dark = false});
  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: dark ? navy : portalSoft,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Icon(icon, size: 21, color: dark ? Colors.white : portalTeal),
  );
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
            child,
          ],
        ],
      ),
    ),
  );
}

typedef PortalAction = ({String label, IconData icon});

class AccountDashboard extends StatelessWidget {
  const AccountDashboard({
    super.key,
    required this.name,
    required this.role,
    required this.onBadges,
  });

  final String name, role;
  final VoidCallback onBadges;

  @override
  Widget build(BuildContext context) {
    final nameOfRole = roleNames[role] ?? role;
    return PortalList(
      children: [
        Row(
          children: [
            PortalIcon(roleIcons[role] ?? Icons.person_outline, dark: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat datang',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  Text(nameOfRole, style: const TextStyle(color: portalTeal)),
                ],
              ),
            ),
          ],
        ),
        ...switch (role) {
          'SISWA' => [
            const _FeaturePanel(
              title: 'Presensi Sekolah',
              icon: Icons.fact_check_outlined,
              description: 'Ringkasan presensi sedang dikembangkan.',
              dark: true,
            ),
            _ActionCards(
              actions: const [
                (
                  label: 'Koleksi Badge',
                  icon: Icons.workspace_premium_outlined,
                ),
                (label: 'Riwayat Presensi', icon: Icons.history),
              ],
              onAction: (action) => action.label == 'Koleksi Badge'
                  ? onBadges()
                  : showUnavailable(context, action.label),
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
              dark: true,
            ),
          ],
          'PEMBINA_EKSTRAKURIKULER' => [
            const _FeaturePanel(
              title: 'Sesi Terdekat',
              icon: Icons.event_outlined,
              description: 'Jadwal sesi belum terhubung.',
            ),
            _ActionCards(
              actions: const [
                (label: 'Buka Sesi', icon: Icons.lock_open_outlined),
                (label: 'Presensi Manual', icon: Icons.fact_check_outlined),
                (label: 'Rekap Anggota', icon: Icons.groups_outlined),
              ],
              onAction: (action) => showUnavailable(context, action.label),
            ),
            const _SectionTitle('Kegiatan yang Dibina'),
            const _FeaturePanel(
              title: 'Daftar Kegiatan',
              icon: Icons.sports_outlined,
              description: 'Daftar kegiatan belum terhubung.',
            ),
          ],
          'WALI_KELAS' => _staff(
            context,
            contextTitle: 'Kelas Binaan',
            contextDescription: 'Informasi kelas binaan belum terhubung.',
            icon: Icons.groups_outlined,
            actions: const [
              (label: 'Rekap Presensi', icon: Icons.calendar_month_outlined),
              (label: 'Kasus Binaan', icon: Icons.folder_open_outlined),
              (label: 'Tindak Lanjut', icon: Icons.assignment_outlined),
            ],
            section: 'Pendampingan Kelas',
            description: 'Ringkasan pendampingan belum terhubung.',
          ),
          'GURU_BK' => _staff(
            context,
            contextTitle: 'Ringkasan Penanganan',
            contextDescription:
                'Daftar kasus sesuai kewenangan belum terhubung.',
            icon: Icons.shield_outlined,
            actions: const [
              (label: 'Kasus Binaan', icon: Icons.folder_open_outlined),
              (label: 'Rencana Konseling', icon: Icons.event_note_outlined),
              (label: 'Asesmen', icon: Icons.assignment_outlined),
            ],
            section: 'Agenda Konseling',
            description: 'Agenda konseling belum terhubung.',
          ),
          _ => _staff(
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
        },
      ],
    );
  }

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
      color: portalSoft,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) =>
      Text(title, style: Theme.of(context).textTheme.titleMedium);
}

class _FeaturePanel extends StatelessWidget {
  const _FeaturePanel({
    required this.title,
    required this.icon,
    required this.description,
    this.dark = false,
    this.color = Colors.white,
  });

  final String title, description;
  final IconData icon;
  final bool dark;
  final Color color;

  @override
  Widget build(BuildContext context) => AppPanel(
    color: dark ? portalNavy : color,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalIcon(icon, dark: dark),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: dark ? Colors.white : navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: dark ? const Color(0xFFD9E9FA) : muted),
              ),
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
          for (final action in actions)
            SizedBox(
              width: width,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: () => onAction(action),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PortalIcon(action.icon, dark: action == actions.first),
                    const SizedBox(height: 8),
                    Text(action.label, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
