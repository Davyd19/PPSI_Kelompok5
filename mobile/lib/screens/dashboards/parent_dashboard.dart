import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import '../parent/parent_extracurricular_screen.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({
    super.key,
    this.api,
    this.data,
    this.name,
    this.onAttendance,
    this.onAchievements,
    this.onBadges,
    this.onCounseling,
    this.onNotifications,
    this.onProfile,
  });

  final AuthApi? api;
  final Map<String, dynamic>? data;
  final String? name;
  final VoidCallback? onAttendance;
  final VoidCallback? onAchievements;
  final VoidCallback? onBadges;
  final VoidCallback? onCounseling;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _backendData;
  int? _selectedChildId;

  @override
  void initState() {
    super.initState();
    if (widget.api != null) {
      _loadDashboard();
    }
  }

  Future<void> _loadDashboard() async {
    if (widget.api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.api!.parentDashboard(childId: _selectedChildId);
      if (mounted) {
        setState(() {
          _backendData = res;
          _selectedChildId = (res['child'] as Map?)?['id'] as int?;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openExtracurriculars() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParentExtracurricularScreen(
          api: widget.api,
          childId: _selectedChildId,
        ),
      ),
    );
  }

  void _showTeacherContact(Map<String, dynamic>? teacher) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Komunikasi Wali Kelas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: teacher == null
            ? const Text(
                'Informasi kontak wali kelas belum tersedia di sistem.',
                style: TextStyle(fontSize: 13),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacher['name'] as String? ?? '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Telepon: ${teacher['telepon'] ?? 'Belum dicantumkan'}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Email: ${teacher['email'] ?? 'Belum dicantumkan'}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ],
              ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fallback for legacy demo mode (role_home_screen.dart) when api == null
    if (widget.api == null && widget.data != null) {
      return _buildLegacyDemo(context, widget.data!);
    }

    if (_loading && _backendData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _backendData == null) {
      return LoadErrorView(message: _error!, onRetry: _loadDashboard);
    }

    final data = _backendData ?? const <String, dynamic>{};
    final children =
        (data['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final child = data['child'] as Map<String, dynamic>?;
    final monthName = data['month_name'] as String? ?? '-';
    final att =
        data['attendance_summary'] as Map<String, dynamic>? ?? const {};
    final pts = data['points_summary'] as Map<String, dynamic>? ?? const {};
    final disc =
        data['discipline_summary'] as Map<String, dynamic>? ?? const {};
    final ekskul =
        data['extracurricular_summary'] as Map<String, dynamic>? ?? const {};
    final recent = data['recent_activity'] as Map<String, dynamic>?;
    final teacher = data['homeroom_teacher'] as Map<String, dynamic>?;

    final hadir = (att['hadir'] as num?)?.toInt() ?? 0;
    final izin = (att['izin'] as num?)?.toInt() ?? 0;
    final terlambat = (att['terlambat'] as num?)?.toInt() ?? 0;
    final alfa = (att['alfa'] as num?)?.toInt() ?? 0;
    final totalSessions = (att['total_sessions'] as num?)?.toInt() ?? 0;
    final rate = (att['rate_percentage'] as num?)?.toDouble() ?? 0;
    final predicate = att['predicate'] as String? ?? 'Belum Ada Data';
    final rateLabel = rate == rate.roundToDouble()
        ? '${rate.round()}%'
        : '${rate.toStringAsFixed(1)}%';

    final totalPoints = (pts['total_points'] as num?)?.toInt() ?? 0;
    final earnedBadges = (pts['earned_badges'] as num?)?.toInt() ?? 0;
    final totalBadges = (pts['total_badges'] as num?)?.toInt() ?? 0;
    final disciplineStatus =
        disc['status_label'] as String? ?? '0 Pelanggaran • Tertib';
    final enrolledEkskul = (ekskul['enrolled_count'] as num?)?.toInt() ?? 0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              if (children.length > 1) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in children)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c['name'] as String? ?? '-'),
                            selected: c['id'] == _selectedChildId,
                            selectedColor: navy,
                            labelStyle: TextStyle(
                              color: c['id'] == _selectedChildId
                                  ? Colors.white
                                  : navy,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            onSelected: (_) {
                              setState(() => _selectedChildId = c['id'] as int);
                              _loadDashboard();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (child != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child['name'] as String? ?? '-',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: navy,
                              ),
                            ),
                            Text(
                              '${child['classroom'] ?? '-'} • NISN: ${child['nisn'] ?? '-'}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Mode Pantau',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 1. Top Attendance Summary Card
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.event_available_outlined,
                                size: 18,
                                color: navy,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Kehadiran $monthName',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: navy,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            totalSessions > 0
                                ? '$rateLabel $predicate'
                                : predicate,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _statTile('Hadir', '$hadir', navy),
                        const SizedBox(width: 8),
                        _statTile('Izin', '$izin', const Color(0xFF0F766E)),
                        const SizedBox(width: 8),
                        _statTile(
                          'Terlambat',
                          '$terlambat',
                          const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 8),
                        _statTile('Alfa', '$alfa', const Color(0xFFDC2626)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: widget.onAttendance,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Rekap Detail Presensi',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Color(0xFF0F766E),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ringkasan Bulan $monthName',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  const Text(
                    'Diperbarui real-time',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0F766E)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 3. Detailed Monthly Progress Card
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: navy,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Kehadiran Siswa',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: navy,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            predicate,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: navy, fontSize: 12),
                            children: [
                              TextSpan(
                                text: '$rateLabel ',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: 'dari $totalSessions sesi',
                                style: const TextStyle(color: muted),
                              ),
                            ],
                          ),
                        ),
                        const Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 7,
                              color: Color(0xFF0F766E),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Hadir Tepat Waktu',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (rate / 100).clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE0F2FE),
                        valueColor: const AlwaysStoppedAnimation<Color>(navy),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: widget.onAttendance,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Lihat Kalender & Rekap Lengkap Presensi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward,
                              size: 15,
                              color: Color(0xFF0F766E),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Quick Navigation Tiles (Prestasi/Badge, Konseling, Ekskul)
              _menuTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Bintang Kedisiplinan & Prestasi',
                subtitle:
                    '+$totalPoints Poin Karakter • $earnedBadges/$totalBadges Badge',
                onTap: widget.onAchievements ?? widget.onBadges,
              ),
              const SizedBox(height: 10),
              _menuTile(
                icon: Icons.verified_user_outlined,
                title: 'Catatan Karakter & Konseling',
                subtitle: disciplineStatus,
                onTap: widget.onCounseling,
              ),
              const SizedBox(height: 10),
              _menuTile(
                icon: Icons.groups_outlined,
                title: 'Kegiatan Ekstrakurikuler Anak',
                subtitle: '$enrolledEkskul Ekskul Diikuti',
                onTap: _openExtracurriculars,
              ),
              const SizedBox(height: 16),

              // 5. Recent Activity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Aktivitas Terkini',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  InkWell(
                    onTap: widget.onAttendance,
                    child: const Text(
                      'Log Harian',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _card(
                child: recent == null
                    ? const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: muted),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Belum ada aktivitas presensi anak yang tercatat.',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: navy,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recent['title'] as String? ?? '-',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: navy,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  recent['description'] as String? ?? '-',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                recent['time'] as String? ?? '-',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              if (recent['date'] != null)
                                Text(
                                  recent['date'] as String,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: muted,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // 6. Homeroom Teacher Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF132B45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.chat_outlined,
                        color: Color(0xFF5EEAD4),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KOMUNIKASI WALI KELAS',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5EEAD4),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            teacher?['name'] as String? ?? 'Belum ditentukan',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: navy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showTeacherContact(teacher),
                      icon: const Icon(Icons.phone_outlined, size: 15),
                      label: const Text(
                        'Hubungi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE7EDF5)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06082B50),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  Widget _statTile(String label, String value, Color valueColor) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: _card(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: muted, size: 20),
        ],
      ),
    ),
  );

  Widget _buildLegacyDemo(BuildContext context, Map<String, dynamic> data) {
    final p = data['parent'] as Map? ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          p['child']?.toString() ?? 'Anak',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${p['classroom'] ?? '-'} • ${data['period'] ?? ''}',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
