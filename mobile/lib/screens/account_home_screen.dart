import 'package:flutter/material.dart';

import '../network/auth_api.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import 'account_dashboard.dart';
import 'badge_collection.dart';

enum _Tab {
  home('Beranda', Icons.dashboard_outlined),
  history('Riwayat', Icons.history, 'Riwayat Presensi'),
  badge('Badge', Icons.workspace_premium_outlined),
  attendance('Presensi', Icons.fact_check_outlined, 'Presensi'),
  achievement('Prestasi', Icons.emoji_events_outlined, 'Prestasi Anak'),
  counseling('Konseling', Icons.support_agent_outlined, 'Konseling'),
  cases('Kasus', Icons.folder_open_outlined, 'Kasus Binaan'),
  activities('Kegiatan', Icons.event_outlined, 'Kegiatan Ekstrakurikuler'),
  profile('Profil', Icons.person_outline);

  const _Tab(this.label, this.icon, [this.feature]);
  final String label;
  final IconData icon;
  final String? feature;
}

List<_Tab> _tabsFor(String role) => [
  _Tab.home,
  ...switch (role) {
    'SISWA' => [_Tab.history, _Tab.badge],
    'ORANG_TUA' => [_Tab.attendance, _Tab.achievement, _Tab.counseling],
    'PEMBINA_EKSTRAKURIKULER' => [_Tab.attendance, _Tab.activities],
    'GURU_BK' => [_Tab.cases, _Tab.counseling],
    _ => [_Tab.attendance, _Tab.cases],
  },
  _Tab.profile,
];

class AccountHomeScreen extends StatefulWidget {
  const AccountHomeScreen({
    super.key,
    required this.api,
    required this.profile,
    required this.role,
    required this.onLogout,
    required this.onSwitchRole,
  });

  final AuthApi api;
  final AccountProfile profile;
  final String role;
  final Future<void> Function() onLogout, onSwitchRole;

  @override
  State<AccountHomeScreen> createState() => _AccountHomeScreenState();
}

class _AccountHomeScreenState extends State<AccountHomeScreen> {
  _Tab _active = _Tab.home;
  bool _busy = false;

  void _navigate(_Tab tab) {
    if (tab.feature case final feature?) {
      showUnavailable(context, feature);
      return;
    }
    setState(() => _active = tab);
  }

  Future<void> _run(Future<void> Function() callback) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await callback();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabsFor(widget.role);
    final role = roleNames[widget.role] ?? widget.role;
    final title = switch (_active) {
      _Tab.badge => 'Koleksi Badge',
      _Tab.profile => 'Profil',
      _ =>
        widget.role == 'PEMBINA_EKSTRAKURIKULER'
            ? 'Beranda Pembina'
            : 'Beranda $role',
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        titleSpacing: 16,
        title: Row(
          children: [
            const PortalIcon(Icons.school_outlined, dark: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SMAN 12 PADANG',
                    style: TextStyle(
                      fontSize: 11,
                      color: portalTeal,
                      letterSpacing: .6,
                    ),
                  ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_active != _Tab.profile)
            IconButton(
              tooltip: 'Buka profil',
              onPressed: () => _navigate(_Tab.profile),
              icon: const CircleAvatar(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                child: Icon(Icons.person_outline, size: 19),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: switch (_active) {
          _Tab.badge => BadgeCollection(load: widget.api.badges),
          _Tab.profile => _profile(role),
          _ => AccountDashboard(
            name: widget.profile.name,
            role: widget.role,
            onBadges: () => _navigate(_Tab.badge),
          ),
        },
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: portalSoft,
        selectedIndex: tabs.indexOf(_active),
        labelBehavior: MediaQuery.textScalerOf(context).scale(12) > 17
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => _navigate(tabs[index]),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }

  Widget _profile(String role) => PortalList(
    children: [
      AppPanel(
        color: portalNavy,
        child: Row(
          children: [
            const PortalIcon(Icons.person_outline, dark: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.profile.name,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const Text(
                    'SMAN 12 Padang',
                    style: TextStyle(color: Color(0xFFD9E9FA)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Akun',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('Identitas akun'),
            Text(
              widget.profile.identity,
              style: const TextStyle(color: navy, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text('Peran aktif'),
            Text(
              role,
              style: const TextStyle(color: navy, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      if (widget.profile.roles.length > 1)
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _run(widget.onSwitchRole),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Ganti peran'),
        ),
      FilledButton.icon(
        onPressed: _busy ? null : () => _run(widget.onLogout),
        icon: const Icon(Icons.logout),
        label: const Text('Keluar'),
      ),
    ],
  );
}
