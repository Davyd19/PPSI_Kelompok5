import '../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../network/auth_api.dart';
import 'teacher/teacher_workspace.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import 'account_dashboard.dart';
import 'pembina_screen.dart' show StudentEkskul;
import 'badge_collection.dart';
import 'parent/parent_achievements_badges_screen.dart';
import 'parent/parent_attendance_screen.dart';
import 'parent/parent_counseling_screen.dart';
import 'parent/parent_notifications_screen.dart';
import 'profile_view.dart';
import 'student/attendance_history_screen.dart';
import 'student/scan_qr_screen.dart';
import 'student/notifications_screen.dart';

enum _Tab {
  home('Beranda', Icons.grid_view),
  history('Riwayat', Icons.history),
  badge('Badge', Icons.workspace_premium_outlined),
  notification('Notifikasi', Icons.notifications_none_outlined),
  attendance('Presensi', Icons.fact_check_outlined, 'Presensi'),
  achievement('Prestasi', Icons.emoji_events_outlined, 'Prestasi Anak'),
  counseling('Konseling', Icons.support_agent_outlined, 'Konseling'),
  activities('Ekskul', Icons.groups_outlined),
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
    _Tab.notification,
  ] else if (roles.contains('ORANG_TUA')) ...[
    _Tab.attendance,
    _Tab.achievement,
    _Tab.counseling,
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
  String get role =>
      profile.primaryRole ??
      (isStaff(profile.roles) ? 'GURU' : profile.roles.first);
  final Future<void> Function() onLogout;

  @override
  State<AccountHomeScreen> createState() => _AccountHomeScreenState();
}

class _AccountHomeScreenState extends State<AccountHomeScreen> {
  _Tab _active = _Tab.home;
  bool _busy = false;

  void _navigate(_Tab tab) {
    if (widget.role == 'ORANG_TUA' &&
        (tab == _Tab.attendance ||
            tab == _Tab.achievement ||
            tab == _Tab.counseling)) {
      setState(() => _active = tab);
      return;
    }
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
    if (widget.role == 'GURU' || widget.role == 'GURU_BK') {
      return TeacherWorkspace(
        api: widget.api,
        profile: widget.profile,
        onLogout: widget.onLogout,
      );
    }
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
      _Tab.history => 'Riwayat Presensi',
      _Tab.attendance => 'Kehadiran Anak',
      _Tab.achievement => 'Prestasi & Badge',
      _Tab.counseling => 'Konseling Anak',
      _Tab.badge => 'Koleksi Badge',
      _Tab.notification => 'Notifikasi',
      _Tab.profile => 'Profil',
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
    return PopScope(
      canPop: _active == _Tab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _active = _Tab.home);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _active != _Tab.home
              ? IconButton(
                  tooltip: 'Kembali ke Beranda',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _navigate(_Tab.home),
                )
              : null,
          titleSpacing: _active != _Tab.home ? 0 : 16,
          title: SchoolPageTitle(
            title: title,
            accent: tone.color,
            showMark: _active == _Tab.home,
          ),
          actions: [
            if ((widget.role == 'SISWA' || widget.role == 'ORANG_TUA') &&
                _active != _Tab.notification)
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
                          border: Border.all(color: line, width: 1.5),
                        ),
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFFE0EAF8),
                          child: Icon(Icons.person, size: 18, color: navy),
                        ),
                      )
                    : CircleAvatar(
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
          // Pergantian tab memudar dan naik sedikit agar terasa halus.
          child: AnimatedSwitcher(
            duration: motionBase,
            switchInCurve: motionCurve,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(_active), child: _body(context)),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          indicatorColor: tone.soft,
          selectedIndex: tabs.indexOf(_active).clamp(0, tabs.length - 1),
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
      ),
    );
  }

  // Isi tiap tab: layar siswa & orang tua dan TeacherHome dari tim, profil baru, dan scan QR ekskul.
  Widget _body(BuildContext context) => switch (_active) {
    _Tab.history => AttendanceHistoryScreen(
      api: widget.api,
      onBack: () => _navigate(_Tab.home),
    ),
    _Tab.attendance when widget.role == 'ORANG_TUA' => ParentAttendanceScreen(
      api: widget.api,
      onBack: () => _navigate(_Tab.home),
    ),
    _Tab.achievement when widget.role == 'ORANG_TUA' =>
      ParentAchievementsBadgesScreen(
        api: widget.api,
        onBack: () => _navigate(_Tab.home),
      ),
    _Tab.counseling when widget.role == 'ORANG_TUA' => ParentCounselingScreen(
      api: widget.api,
      onBack: () => _navigate(_Tab.home),
    ),
    _Tab.badge => BadgeCollection(load: widget.api.badges),
    _Tab.notification when widget.role == 'ORANG_TUA' =>
      ParentNotificationsScreen(
        api: widget.api,
        onBack: () => _navigate(_Tab.home),
      ),
    _Tab.notification => NotificationsScreen(
      api: widget.api,
      onBack: () => _navigate(_Tab.home),
    ),
    _Tab.profile => ProfileView(
      profile: widget.profile,
      busy: _busy,
      onLogout: () => _run(widget.onLogout),
    ),
    _Tab.activities => StudentEkskul(api: widget.api),
    _ => AccountDashboard(
      api: widget.api,
      name: widget.profile.name,
      roles: widget.profile.roles,
      onBadges: () => _navigate(_Tab.badge),
      onProfile: () => _navigate(_Tab.profile),
      onNotifications: () => _navigate(_Tab.notification),
      onHistory: () => _navigate(_Tab.history),
      onAttendance: () => _navigate(_Tab.attendance),
      onAchievements: () => _navigate(_Tab.achievement),
      onCounseling: () => _navigate(_Tab.counseling),
      onPembina: () => showUnavailable(context, 'Ekskul Binaan'),
      onScanQr: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ScanQrScreen(api: widget.api)),
      ),
    ),
  };
}
