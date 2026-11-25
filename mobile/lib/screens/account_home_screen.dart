import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/auth_api.dart';
import '../network/attendance_recap_api.dart';
import '../network/school_attendance_api.dart';
import '../network/violation_report_api.dart';
import '../network/teacher_profile_api.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import 'account_dashboard.dart';
import 'badge_collection.dart';
import 'ekskul_qr.dart';
import 'parent/parent_achievements_badges_screen.dart';
import 'parent/parent_attendance_screen.dart';
import 'parent/parent_counseling_screen.dart';
import 'parent/parent_notifications_screen.dart';
import 'pembina_screen.dart';
import 'profile_view.dart';
import 'student/attendance_history_screen.dart';
import 'student/notifications_screen.dart';
import 'teacher/attendance_recap_screen.dart';
import 'teacher/school_attendance_screen.dart';
import 'teacher/my_reports_screen.dart';
import 'teacher/teacher_home.dart';
import 'teacher/profile_screen.dart';
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
  _Tab _active = _Tab.home;
  bool _busy = false;

  Future<void> _openSchoolAttendance() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          SchoolAttendanceScreen(api: SchoolAttendanceApi(widget.api)),
    ),
  );

  Future<void> _openAttendanceRecap() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          AttendanceRecapScreen(api: AttendanceRecapApi(widget.api)),
    ),
  );

  late final _violations = ViolationReportApi(widget.api);

  Future<void> _openMyReports() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => MyReportsScreen(api: _violations)),
  );

  Future<void> _openViolationReport() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => ViolationReportScreen(
        api: _violations,
        onOpenMine: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => MyReportsScreen(api: _violations),
          ),
        ),
      ),
    ),
  );

  void _navigate(_Tab tab) {
    if (tab == _Tab.attendance && widget.role == 'GURU') {
      _openSchoolAttendance();
      return;
    }
    if (tab == _Tab.cases && widget.role == 'GURU') {
      _openMyReports();
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
    if (widget.role == 'GURU') {
      return _TeacherWorkspace(
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
          title: Row(
            children: [
              if (widget.role == 'SISWA') ...[
                if (_active == _Tab.home) ...[
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
                ],
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
                if (_active == _Tab.home) ...[
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
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.role == 'ORANG_TUA'
                            ? 'PORTAL ORANG TUA'
                            : 'SMAN 12 PADANG',
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
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
    _Tab.coaching => PembinaHome(api: widget.api, name: widget.profile.name),
    // Beranda guru: TeacherHome buatan tim (presensi sekolah, rekap, laporan pelanggaran).
    _ when widget.role == 'GURU' => TeacherHome(
      api: widget.api,
      name: widget.profile.name,
      onSchoolAttendance: _openSchoolAttendance,
      onAttendanceRecap: _openAttendanceRecap,
      onUnavailable: (feature) => showUnavailable(context, feature),
      onViolationReport: _openViolationReport,
      assignments: assignmentsOf(widget.profile.roles),
      onPembina: () => _navigate(_Tab.coaching),
    ),
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
      onPembina: () => _navigate(_Tab.coaching),
      onSchoolAttendance: widget.role == 'GURU' ? _openSchoolAttendance : null,
      onAttendanceRecap: widget.role == 'GURU' ? _openAttendanceRecap : null,
      onScanQr: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudentScanScreen(api: widget.api),
        ),
      ),
    ),
  };
}

/// Merge integration: preserve Guru's independent tab stacks and profile editor
/// without replacing main's Student, Parent, extracurricular QR or profile routes.
class _TeacherWorkspace extends StatefulWidget {
  const _TeacherWorkspace({
    required this.api,
    required this.profile,
    required this.onLogout,
  });
  final AuthApi api;
  final AccountProfile profile;
  final Future<void> Function() onLogout;
  @override
  State<_TeacherWorkspace> createState() => _TeacherWorkspaceState();
}

class _TeacherWorkspaceState extends State<_TeacherWorkspace> {
  final _keys = <_Tab, GlobalKey<NavigatorState>>{};
  final _visited = <_Tab>{_Tab.home};
  _Tab _active = _Tab.home;
  late final _violations = ViolationReportApi(widget.api);
  List<_Tab> get _tabs => _tabsFor(widget.profile.roles);
  NavigatorState? get _current => _keys[_active]?.currentState;
  @override
  void initState() {
    super.initState();
    _syncTabs();
  }

  void _syncTabs() {
    for (final tab in _tabs) {
      _keys.putIfAbsent(tab, () => GlobalKey<NavigatorState>());
    }
    _visited.removeWhere((tab) => !_tabs.contains(tab));
    if (!_tabs.contains(_active)) {
      _active = _Tab.home;
      _visited.add(_Tab.home);
    }
  }

  @override
  void didUpdateWidget(covariant _TeacherWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTabs();
  }

  void _select(_Tab tab) {
    if (!_tabs.contains(tab)) return;
    setState(() {
      _active = tab;
      _visited.add(tab);
    });
  }

  Future<void> _push(Widget page) async {
    await _current?.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _attendance() async => _select(_Tab.attendance);
  Future<void> _recap() =>
      _push(AttendanceRecapScreen(api: AttendanceRecapApi(widget.api)));
  Future<void> _report() => _push(
    ViolationReportScreen(
      api: _violations,
      onOpenMine: () {
        _current?.pop();
        _select(_Tab.cases);
      },
    ),
  );
  Widget _root(_Tab tab) => switch (tab) {
    _Tab.attendance => SchoolAttendanceScreen(
      api: SchoolAttendanceApi(widget.api),
    ),
    _Tab.cases => MyReportsScreen(api: _violations),
    _Tab.profile => ProfileScreen(
      api: TeacherProfileApi(widget.api),
      onLogout: widget.onLogout,
    ),
    _Tab.coaching => _TeacherTabScaffold(
      title: 'Ekskul Binaan',
      name: widget.profile.name,
      onProfile: () => _select(_Tab.profile),
      child: PembinaHome(api: widget.api, name: widget.profile.name),
    ),
    _ => _TeacherTabScaffold(
      title: 'Beranda Guru',
      name: widget.profile.name,
      onProfile: () => _select(_Tab.profile),
      child: TeacherHome(
        api: widget.api,
        name: widget.profile.name,
        onSchoolAttendance: _attendance,
        onAttendanceRecap: _recap,
        onViolationReport: _report,
        onUnavailable: (feature) => showUnavailable(context, feature),
        assignments: assignmentsOf(widget.profile.roles),
        onPembina: () => _select(_Tab.coaching),
      ),
    ),
  };
  Future<void> _back() async {
    final nav = _current;
    if (nav != null && nav.canPop()) {
      await nav.maybePop();
      return;
    }
    if (_active != _Tab.home) {
      _select(_Tab.home);
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) => PortalTone.forRoles(
    widget.profile.roles,
    child: Builder(
      builder: (context) {
        final tone = PortalTone.of(context), tabs = _tabs;
        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _back();
          },
          child: Scaffold(
            body: Stack(
              children: [
                for (final tab in tabs)
                  if (_visited.contains(tab))
                    Offstage(
                      offstage: _active != tab,
                      child: TickerMode(
                        enabled: _active == tab,
                        child: Navigator(
                          key: _keys[tab],
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (_) => _root(tab),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              indicatorColor: tone.soft,
              selectedIndex: tabs.indexOf(_active),
              labelBehavior: MediaQuery.textScalerOf(context).scale(12) > 17
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (index) => _select(tabs[index]),
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
      },
    ),
  );
}

class _TeacherTabScaffold extends StatelessWidget {
  const _TeacherTabScaffold({
    required this.title,
    required this.name,
    required this.onProfile,
    required this.child,
  });
  final String title, name;
  final VoidCallback onProfile;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
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
          IconButton(
            tooltip: 'Buka profil',
            onPressed: onProfile,
            icon: CircleAvatar(
              backgroundColor: portalTeal,
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
      body: SafeArea(top: false, bottom: false, child: child),
    );
  }
}
