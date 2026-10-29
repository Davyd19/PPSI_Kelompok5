import 'package:flutter/material.dart';
import '../models/demo_profile.dart';
import '../network/demo_api.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import '../widgets/dashboard_widgets.dart';
import 'login_screen.dart';
import 'dashboards/student_dashboard.dart';
import 'dashboards/parent_dashboard.dart';
import 'dashboards/teacher_dashboard.dart';
import 'dashboards/bk_dashboard.dart';
import 'dashboards/coach_dashboard.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key, required this.api, required this.profile});
  final DemoApi api;
  final DemoProfile profile;
  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  late Future<Map<String, dynamic>> _dashboard;
  Future<Map<String, dynamic>> _load() {
    final f = widget.api.dashboard(widget.profile.role);
    f.ignore();
    return f;
  }

  @override
  void initState() {
    super.initState();
    _dashboard = _load();
  }

  void _logout() => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => LoginScreen(api: widget.api)),
  );
  Widget _content(Map<String, dynamic> data) => switch (widget.profile.role) {
    'siswa' => StudentDashboard(data: data),
    'orang_tua' => ParentDashboard(data: data),
    'guru' => TeacherDashboard(data: data),
    'wali_kelas' => TeacherDashboard(data: data, isGuardian: true),
    'guru_bk' => BkDashboard(data: data),
    'pembina_ekstrakurikuler' => CoachDashboard(data: data),
    _ => const Text('Peran tidak tersedia.'),
  };
  List<(IconData, String)> get _tabs => switch (widget.profile.role) {
    'siswa' => [
      (Icons.home_outlined, 'Beranda'),
      (Icons.history, 'Riwayat'),
      (Icons.workspace_premium_outlined, 'Badge'),
      (Icons.notifications_none, 'Notifikasi'),
      (Icons.person_outline, 'Profil'),
    ],
    'orang_tua' => [
      (Icons.home_outlined, 'Beranda'),
      (Icons.calendar_month_outlined, 'Kehadiran'),
      (Icons.workspace_premium_outlined, 'Prestasi'),
      (Icons.forum_outlined, 'Penanganan'),
      (Icons.person_outline, 'Profil'),
    ],
    'pembina_ekstrakurikuler' => [
      (Icons.home_outlined, 'Beranda'),
      (Icons.fact_check_outlined, 'Presensi'),
      (Icons.event_note, 'Kegiatan'),
      (Icons.person_outline, 'Profil'),
    ],
    _ => [
      (Icons.home_outlined, 'Beranda'),
      (Icons.fact_check_outlined, 'Presensi'),
      (Icons.shield_outlined, 'Penanganan'),
      (Icons.person_outline, 'Profil'),
    ],
  };
  void _profile() => showDetails(
    context,
    title: 'Profil pengguna',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.profile.name,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(widget.profile.roleLabel),
        const Text('SMAN 12 Padang'),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _logout();
          },
          child: const Text('Keluar'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _dashboard,
    builder: (context, snapshot) {
      final data = snapshot.data;
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFF),
                  border: Border(bottom: BorderSide(color: Color(0xFFE6EDF7))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: navy,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SIM Kesiswaan · SMAN 12 Padang',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF236A7C),
                            ),
                          ),
                          Text(
                            'Beranda ${widget.profile.roleLabel}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Notifikasi',
                      onPressed: () => showDetails(
                        context,
                        title: 'Notifikasi',
                        child: data == null
                            ? const Text('Informasi belum dimuat.')
                            : Column(
                                children: (data['notifications'] as List)
                                    .map(
                                      (n) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(n['title']),
                                        subtitle: Text(n['body']),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                      icon: const Badge(
                        smallSize: 6,
                        child: Icon(Icons.notifications_none, size: 22),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Profil',
                      onPressed: _profile,
                      icon: const CircleAvatar(
                        radius: 16,
                        backgroundColor: navy,
                        child: Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: snapshot.connectionState != ConnectionState.done
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${snapshot.error}'),
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: () => setState(() {
                                  _dashboard = _load();
                                }),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                            children: [
                              _content(data!),
                              const SizedBox(height: 24),
                              const Text(
                                'Prototipe • Data contoh Oktober 2026',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 9, color: muted),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width:
                  MediaQuery.sizeOf(context).width < 360 &&
                      MediaQuery.textScalerOf(context).scale(1) > 1.2
                  ? _tabs.length * 82.0
                  : MediaQuery.sizeOf(context).width,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE7EDF6))),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _tabs.indexed
                      .map(
                        (entry) => Expanded(
                          child: InkWell(
                            onTap: () {
                              final label = entry.$2.$2;
                              if (entry.$1 == 0) return;
                              if (label == 'Profil') {
                                _profile();
                              } else if (label == 'Notifikasi') {
                                showDetails(
                                  context,
                                  title: 'Notifikasi',
                                  child: data == null
                                      ? const Text('Informasi belum dimuat.')
                                      : Column(
                                          children:
                                              (data['notifications'] as List)
                                                  .map(
                                                    (n) => ListTile(
                                                      title: Text(n['title']),
                                                      subtitle: Text(n['body']),
                                                    ),
                                                  )
                                                  .toList(),
                                        ),
                                );
                              } else {
                                unavailable(context, label);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    entry.$2.$1,
                                    color: entry.$1 == 0 ? navy : muted,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.$2.$2,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: entry.$1 == 0 ? navy : muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
