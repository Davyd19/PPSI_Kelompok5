import 'package:flutter/material.dart';

import '../network/auth_api.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import 'account_dashboard.dart';
import 'badge_collection.dart';
import 'pembina_screen.dart';

enum _Tab {
  home('Beranda', Icons.dashboard_outlined),
  history('Riwayat', Icons.history, 'Riwayat Presensi'),
  badge('Badge', Icons.workspace_premium_outlined),
  attendance('Presensi', Icons.fact_check_outlined, 'Presensi'),
  achievement('Prestasi', Icons.emoji_events_outlined, 'Prestasi Anak'),
  counseling('Konseling', Icons.support_agent_outlined, 'Konseling'),
  cases('Kasus', Icons.folder_open_outlined, 'Kasus Binaan'),
  activities('Ekskul', Icons.groups_outlined),
  coaching('Ekskul', Icons.emoji_events_outlined),
  profile('Profil', Icons.person_outline);

  const _Tab(this.label, this.icon, [this.feature]);
  final String label;
  final IconData icon;
  final String? feature;
}

// Satu beranda per akun. Guru mendapat semua fitur penugasannya sekaligus, tanpa memilih peran.
List<_Tab> _tabsFor(List<String> roles) => [
  _Tab.home,
  if (roles.contains('SISWA')) ...[
    _Tab.history,
    _Tab.badge,
    _Tab.activities,
  ] else if (roles.contains('ORANG_TUA')) ...[
    _Tab.attendance,
    _Tab.achievement,
    _Tab.counseling,
  ] else ...[
    _Tab.attendance,
    _Tab.cases,
    if (roles.contains('PEMBINA_EKSTRAKURIKULER')) _Tab.coaching,
  ],
  _Tab.profile,
];

class AccountHomeScreen extends StatefulWidget {
  const AccountHomeScreen({
    super.key,
    required this.api,
    required this.profile,
    required this.onLogout,
  });

  final AuthApi api;
  final AccountProfile profile;
  final Future<void> Function() onLogout;

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
    final roles = widget.profile.roles;
    final tabs = _tabsFor(roles);
    final staff = isStaff(roles);
    final role = staff
        ? [
            'Guru',
            ...assignmentsOf(roles).map((r) => roleNames[r] ?? r),
          ].join(', ')
        : roleNames[roles.first] ?? roles.first;
    final title = switch (_active) {
      _Tab.badge => 'Koleksi Badge',
      _Tab.profile => 'Profil',
      _Tab.coaching => 'Ekskul Binaan',
      _ => staff ? 'Beranda Guru' : 'Beranda $role',
    };
    final initials = widget.profile.name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    // Aksen warna mengikuti jenis akun, setara dengan warna aksen portal web.
    return PortalTone.forRoles(
      roles,
      child: Builder(
        builder: (context) {
          final tone = PortalTone.of(context);
          return _scaffold(context, tone, tabs, title, role, initials);
        },
      ),
    );
  }

  Widget _scaffold(
    BuildContext context,
    PortalTone tone,
    List<_Tab> tabs,
    String title,
    String role,
    String initials,
  ) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 21,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SMAN 12 PADANG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tone.color,
                      letterSpacing: .8,
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
              icon: CircleAvatar(
                backgroundColor: tone.color,
                foregroundColor: Colors.white,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          _Tab.activities => StudentEkskul(api: widget.api),
          _Tab.coaching => PembinaHome(
            api: widget.api,
            name: widget.profile.name,
          ),
          _ => AccountDashboard(
            name: widget.profile.name,
            roles: widget.profile.roles,
            onBadges: () => _navigate(_Tab.badge),
            onPembina: () => _navigate(_Tab.coaching),
          ),
        },
      ),
      bottomNavigationBar: NavigationBar(
        indicatorColor: tone.soft,
        selectedIndex: tabs.indexOf(_active),
        labelBehavior: MediaQuery.textScalerOf(context).scale(12) > 17
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => _navigate(tabs[index]),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon, color: muted),
              selectedIcon: Icon(tab.icon, color: tone.ink),
              label: tab.label,
            ),
        ],
      ),
    );
  }

  Widget _profile(String role) => PortalList(
    children: [
      BrandBand(
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
                    style: TextStyle(color: Color(0xFFB9C8DA)),
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
            Text(isStaff(widget.profile.roles) ? 'Penugasan aktif' : 'Peran'),
            Text(
              role,
              style: const TextStyle(color: navy, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      FilledButton.icon(
        onPressed: _busy ? null : () => _run(widget.onLogout),
        icon: const Icon(Icons.logout),
        label: const Text('Keluar'),
      ),
    ],
  );
}
