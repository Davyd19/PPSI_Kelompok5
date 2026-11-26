import '../../widgets/school_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/account_capabilities.dart';
import '../../network/auth_api.dart';
import '../../network/kasus_api.dart';
import '../../network/attendance_recap_api.dart';
import '../../network/school_attendance_api.dart';
import '../../network/violation_report_api.dart';
import '../../network/teacher_profile_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import '../kasus/kasus_list_screen.dart';
import '../pembina_screen.dart';
import 'attendance_recap_screen.dart';
import 'school_attendance_screen.dart';
import 'my_reports_screen.dart';
import 'profile_screen.dart';
import 'teacher_home.dart';
import 'violation_report_screen.dart';

enum _Tab {
  home('Beranda', Icons.grid_view),
  attendance('Presensi', Icons.fact_check_outlined),
  cases('Laporan Saya', Icons.folder_open_outlined),
  profile('Profil', Icons.person_outline);

  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

List<_Tab> _tabsFor(List<String> roles) => [
  _Tab.home,
  _Tab.attendance,
  _Tab.cases,
  _Tab.profile,
];

/// One teacher workspace shares base features and preserves each tab navigation stack.
class TeacherWorkspace extends StatefulWidget {
  const TeacherWorkspace({
    super.key,
    required this.api,
    required this.profile,
    required this.onLogout,
  });
  final AuthApi api;
  final AccountProfile profile;
  final Future<void> Function() onLogout;
  @override
  State<TeacherWorkspace> createState() => TeacherWorkspaceState();
}

class TeacherWorkspaceState extends State<TeacherWorkspace> {
  final _keys = <_Tab, GlobalKey<NavigatorState>>{};
  final _visited = <_Tab>{_Tab.home};
  _Tab _active = _Tab.home;
  late final _violations = ViolationReportApi(widget.api);
  List<_Tab> get _tabs => _tabsFor(widget.profile.roles);
  NavigatorState? get _current => _keys[_active]?.currentState;
  AccountCapabilities get _capabilities => AccountCapabilities(widget.profile);
  Future<void> _openFeature(TeacherFeature feature) async {
    if (!_capabilities.permits(feature)) {
      showDetails(
        context,
        title: 'Fitur tidak tersedia',
        child: const Text(
          'Periksa kembali peran atau penugasan aktif akun Anda.',
        ),
      );
      return;
    }
    if (feature == TeacherFeature.extracurricular) {
      await _push(
        TeacherPageLayout(
          title: 'Ekskul Binaan',
          name: widget.profile.name,
          onProfile: () => _select(_Tab.profile),
          child: PembinaHome(api: widget.api, name: widget.profile.name),
        ),
      );
      return;
    }
    final role = feature == TeacherFeature.homeroomCases
        ? 'WALI_KELAS'
        : 'GURU_BK';
    await _push(
      KasusListScreen(
        api: KasusApi(widget.api, role: role),
        role: role,
      ),
    );
  }

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
  void didUpdateWidget(covariant TeacherWorkspace oldWidget) {
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
    _ => TeacherPageLayout(
      title: widget.profile.primaryRole == 'GURU_BK'
          ? 'Beranda Guru BK'
          : 'Beranda Guru',
      name: widget.profile.name,
      onProfile: () => _select(_Tab.profile),
      child: TeacherHome(
        api: widget.api,
        name: widget.profile.name,
        onSchoolAttendance: _attendance,
        onAttendanceRecap: _recap,
        onViolationReport: _report,
        onOpenFeature: _openFeature,
        capabilities: _capabilities,
        primaryRole: widget.profile.primaryRole ?? 'GURU',
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
        final tabs = _tabs;
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
              // Menu aktif: pil navy dengan ikon putih agar jelas berbeda.
              indicatorColor: brandMid,
              selectedIndex: tabs.indexOf(_active),
              labelBehavior: MediaQuery.textScalerOf(context).scale(12) > 17
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (index) => _select(tabs[index]),
              destinations: [
                for (final tab in tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon, color: muted),
                    selectedIcon: Icon(tab.icon, color: Colors.white),
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

class TeacherPageLayout extends StatelessWidget {
  const TeacherPageLayout({
    super.key,
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
        title: SchoolPageTitle(
          title: title,
          accent: PortalTone.of(context).color,
        ),
        actions: [
          IconButton(
            tooltip: 'Buka profil',
            onPressed: onProfile,
            icon: CircleAvatar(
              backgroundColor: PortalTone.of(context).color,
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
