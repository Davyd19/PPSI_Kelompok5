import 'package:flutter/material.dart';

import '../network/auth_api.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import 'account_dashboard.dart';
import 'badge_collection.dart';
import 'student/attendance_history_screen.dart';
import 'student/notifications_screen.dart';

enum _Tab {
  home('Home', Icons.grid_view),
  history('Riwayat', Icons.history),
  badge('Badge', Icons.workspace_premium_outlined),
  notification('Notifikasi', Icons.notifications_none_outlined),
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

List<_Tab> _tabsFor(String role) => switch (role) {
  'SISWA' => [
    _Tab.home,
    _Tab.history,
    _Tab.badge,
    _Tab.notification,
    _Tab.profile,
  ],
  'ORANG_TUA' => [
    _Tab.home,
    _Tab.attendance,
    _Tab.achievement,
    _Tab.counseling,
    _Tab.profile,
  ],
  'PEMBINA_EKSTRAKURIKULER' => [
    _Tab.home,
    _Tab.attendance,
    _Tab.activities,
    _Tab.profile,
  ],
  'GURU_BK' => [_Tab.home, _Tab.cases, _Tab.counseling, _Tab.profile],
  _ => [_Tab.home, _Tab.attendance, _Tab.cases, _Tab.profile],
};

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
      _Tab.history => 'Riwayat Presensi',
      _Tab.badge => 'Koleksi Badge',
      _Tab.notification => 'Notifikasi',
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
            if (widget.role == 'SISWA') ...[
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D253A),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF38BDF8),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SMAN 12 PADANG',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: portalTeal,
                        letterSpacing: .6,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _active == _Tab.home ? 'Home' : title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(
                          width: 0,
                          height: 0,
                          child: OverflowBox(
                            maxWidth: 0,
                            maxHeight: 0,
                            child: Text(
                              'Beranda Siswa',
                              style: TextStyle(
                                fontSize: 0,
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
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
          ],
        ),
        actions: [
          if (widget.role == 'SISWA')
            IconButton(
              tooltip: 'Notifikasi',
              onPressed: () => _navigate(_Tab.notification),
              icon: const Icon(
                Icons.notifications_none_outlined,
                color: navy,
                size: 24,
              ),
            ),
          if (_active != _Tab.profile)
            IconButton(
              tooltip: 'Buka profil',
              onPressed: () => _navigate(_Tab.profile),
              icon: widget.role == 'SISWA'
                  ? Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFE0EAF8),
                        child: Icon(Icons.person, size: 18, color: navy),
                      ),
                    )
                  : const CircleAvatar(
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
          _Tab.history => AttendanceHistoryScreen(api: widget.api),
          _Tab.badge => BadgeCollection(load: widget.api.badges),
          _Tab.notification => NotificationsScreen(api: widget.api),
          _Tab.profile => _profile(role),
          _ => AccountDashboard(
            api: widget.api,
            name: widget.profile.name,
            role: widget.role,
            onBadges: () => _navigate(_Tab.badge),
            onProfile: () => _navigate(_Tab.profile),
            onNotifications: () => _navigate(_Tab.notification),
            onHistory: () => _navigate(_Tab.history),
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
