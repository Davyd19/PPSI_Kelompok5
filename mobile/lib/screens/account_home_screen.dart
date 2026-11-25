import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/auth_api.dart';
import '../network/attendance_recap_api.dart';
import '../network/school_attendance_api.dart';
import '../network/teacher_profile_api.dart';
import '../network/violation_report_api.dart';
import '../theme.dart';
import 'account_dashboard.dart';
import 'badge_collection.dart';
import 'parent/parent_achievements_badges_screen.dart';
import 'parent/parent_attendance_screen.dart';
import 'parent/parent_counseling_screen.dart';
import 'parent/parent_notifications_screen.dart';
import 'pembina_screen.dart';
import 'student/attendance_history_screen.dart';
import 'student/notifications_screen.dart';
import 'teacher/attendance_recap_screen.dart';
import 'teacher/my_reports_screen.dart';
import 'teacher/profile_screen.dart';
import 'teacher/school_attendance_screen.dart';
import 'teacher/teacher_home.dart';
import 'teacher/violation_report_screen.dart';

enum _Tab {
  home('Home', Icons.grid_view),
  history('Riwayat', Icons.history),
  badge('Badge', Icons.workspace_premium_outlined),
  notification('Notifikasi', Icons.notifications_none_outlined),
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
    _Tab.notification,
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

/// Kerangka utama setelah masuk. Setiap tab punya Navigator sendiri sehingga
/// halaman lanjutan (rekap, input manual, laporan, dll.) dibuka di dalam tab
/// dan bilah navigasi bawah tetap terlihat di semua halaman.
class AccountHomeScreen extends StatefulWidget {
  const AccountHomeScreen({
    super.key,
    required this.api,
    required this.profile,
    required this.onLogout,
  });

  final AuthApi api;
  final AccountProfile profile;
  String get role => isStaff(profile.roles) ? 'GURU' : profile.roles.first;
  final Future<void> Function() onLogout;

  @override
  State<AccountHomeScreen> createState() => _AccountHomeScreenState();
}

class _AccountHomeScreenState extends State<AccountHomeScreen> {
  late final _tabs = _tabsFor(widget.role);
  late final _keys = {for (final t in _tabs) t: GlobalKey<NavigatorState>()};
  final _visited = <_Tab>{_Tab.home};
  _Tab _active = _Tab.home;

  bool get _isTeacher => widget.role == 'GURU';
  late final _violations = ViolationReportApi(widget.api);

  NavigatorState? _nav(_Tab tab) => _keys[tab]?.currentState;

  /// Buka halaman di dalam tab yang sedang aktif.
  Future<void> _push(Widget page) async {
    await _nav(_active)?.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _select(_Tab tab) {
    if (tab.feature case final feature?
        when !(_isTeacher && (tab == _Tab.attendance || tab == _Tab.cases))) {
      showUnavailable(context, feature);
      return;
    }
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
    setState(() {
      _active = tab;
      _visited.add(tab);
    });
  }

  Future<void> _openSchoolAttendance() async => _select(_Tab.attendance);

  Future<void> _openAttendanceRecap() =>
      _push(AttendanceRecapScreen(api: AttendanceRecapApi(widget.api)));

  Future<void> _openViolationReport() => _push(
    ViolationReportScreen(
      api: _violations,
      onOpenMine: () {
        _nav(_active)?.pop();
        _select(_Tab.cases);
      },
    ),
  );

  Widget _root(_Tab tab) => switch (tab) {
    _Tab.profile when _isTeacher => ProfileScreen(
      api: TeacherProfileApi(widget.api),
      onLogout: widget.onLogout,
    ),
    _Tab.attendance when _isTeacher => SchoolAttendanceScreen(
      api: SchoolAttendanceApi(widget.api),
    ),
    _Tab.cases when _isTeacher => MyReportsScreen(api: _violations),
    _Tab.badge => _TabScaffold(
      title: 'Koleksi Badge',
      onProfile: () => _select(_Tab.profile),
      child: BadgeCollection(load: widget.api.badges),
    ),
    _Tab.profile => _BasicProfile(
      profile: widget.profile,
      role: widget.role,
      onLogout: widget.onLogout,
    ),
    _ => _TabScaffold(
      title: _isTeacher
          ? 'Beranda Guru'
          : widget.role == 'PEMBINA_EKSTRAKURIKULER'
          ? 'Beranda Pembina'
          : 'Beranda ${roleNames[widget.role] ?? widget.role}',
      onProfile: () => _select(_Tab.profile),
      child: _isTeacher
          ? TeacherHome(
              api: widget.api,
              name: widget.profile.name,
              onSchoolAttendance: _openSchoolAttendance,
              onAttendanceRecap: _openAttendanceRecap,
              onUnavailable: (feature) => showUnavailable(context, feature),
              onViolationReport: _openViolationReport,
            )
          : AccountDashboard(
              name: widget.profile.name,
              role: widget.role,
              onBadges: () => _select(_Tab.badge),
            ),
    ),
  };

  /// Tombol kembali Android: tutup halaman dalam tab dulu, lalu kembali ke
  /// Beranda, baru keluar aplikasi.
  void _onBack(bool didPop, Object? _) {
    if (didPop) return;
    final nav = _nav(_active);
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else if (_active != _Tab.home) {
      setState(() => _active = _Tab.home);
    } else {
      SystemNavigator.pop();
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
          _ when widget.role == 'GURU' => TeacherHome(
            api: widget.api,
            name: widget.profile.name,
            onSchoolAttendance: _openSchoolAttendance,
            onAttendanceRecap: _openAttendanceRecap,
            onUnavailable: (feature) => showUnavailable(context, feature),
            onViolationReport: _openViolationReport,
          ),
          _ => AccountDashboard(
            name: widget.profile.name,
            role: widget.role,
            onBadges: () => _navigate(_Tab.badge),
            onSchoolAttendance: widget.role == 'GURU'
                ? _openSchoolAttendance
                : null,
            onAttendanceRecap: widget.role == 'GURU'
                ? _openAttendanceRecap
                : null,
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
      FilledButton.icon(
        onPressed: _busy ? null : () => _run(widget.onLogout),
        icon: const Icon(Icons.logout),
        label: const Text('Keluar'),
      ),
    ],
  );
}
