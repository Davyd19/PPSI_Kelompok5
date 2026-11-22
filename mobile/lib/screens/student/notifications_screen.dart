import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.api});
  final AuthApi? api;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String _activeFilter = 'all'; // all, attendance, violation
  bool _showEmptyPreview = false;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      if (widget.api != null) {
        final res = await widget.api!.studentNotifications();
        setState(() => _data = res);
      } else {
        _setFallback();
      }
    } catch (_) {
      _setFallback();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFallback() {
    setState(() {
      _data = {
        'unread_count': 2,
        'filter_tabs': [
          {'key': 'all', 'label': 'Semua', 'count': 5},
          {'key': 'attendance', 'label': 'Presensi', 'count': 2},
          {'key': 'violation', 'label': 'Pelanggaran', 'count': 1},
        ],
        'groups': [
          {
            'group_name': 'Hari Ini',
            'date_label': '21 April 2025',
            'badge_label': '2 Baru',
            'items': [
              {
                'id': 1,
                'category': 'PRESENSI GERBANG',
                'title': 'Presensi Pagi Berhasil...',
                'description':
                    'NIS 21084 (Ahmad Fadhil) tercatat hadir di Gerbang Utama pukul 06.45 WIB melalui pemindaian kartu RFID.',
                'time_ago': '10 mnt lalu',
                'unread': true,
                'tags': ['Tepat Waktu', 'Pos Satpam A'],
                'icon': Icons.check_circle_outline,
                'color': const Color(0xFF0D9488),
                'type': 'attendance',
              },
              {
                'id': 2,
                'category': 'KETERTIBAN SISWA',
                'title': 'Catatan Disiplin: Keterlambatan',
                'description':
                    'Poin kedisiplinan bertambah +5 poin karena keterlambatan apel Senin pagi tanggal 21 April 2025.',
                'time_ago': '2 jam lalu',
                'unread': true,
                'tags': ['+5 Demerit', 'Guru Piket: Bpk. Hendra, S.Pd'],
                'icon': Icons.warning_amber_rounded,
                'color': const Color(0xFFEF4444),
                'type': 'violation',
                'is_violation': true,
              },
            ],
          },
          {
            'group_name': 'Kemarin',
            'date_label': '20 April 2025',
            'items': [
              {
                'id': 3,
                'category': 'APRESIASI SISWA',
                'title': 'Lencana Disiplin Unggul Diterbitkan',
                'description':
                    'Selamat! Anda memperoleh badge "Kehadiran 100% Bulan Maret" dengan rekor tanpa alpa atau izin.',
                'time_ago': 'Kemarin, 14.20',
                'unread': false,
                'badge_info': {
                  'title': 'Bintang Disiplin Maret',
                  'subtitle': 'Koleksi Profil Bertambah',
                },
                'icon': Icons.military_tech_outlined,
                'color': const Color(0xFF0284C7),
                'type': 'badge',
              },
              {
                'id': 4,
                'category': 'WARTA SEKOLAH',
                'title': 'Jadwal Latihan Gabungan Paskibra',
                'description':
                    'Pemberitahuan gladi resik upacara Hari Pendidikan Nasional di Lapangan Utama SMAN 12 Padang. Seluruh anggota wajib membawa seragam PDL lengkap.',
                'time_ago': 'Kemarin, 09.00',
                'unread': false,
                'tags': ['Lapangan Utama', '2 Mei 2025'],
                'icon': Icons.campaign_outlined,
                'color': const Color(0xFF6366F1),
                'type': 'announcement',
              },
            ],
          },
          {
            'group_name': 'Minggu Ini',
            'date_label': 'Pekan ke-3 April',
            'items': [
              {
                'id': 5,
                'category': 'PERIZINAN',
                'title': 'Persetujuan Izin Sakit Diterima',
                'description':
                    'Surat keterangan dokter untuk izin tanggal 17 April 2025 telah diverifikasi oleh Wali Kelas XI MIPA 3 (Ibu Dra. Rosmaini).',
                'time_ago': '3 hari lalu',
                'unread': false,
                'tags': ['Status: Sah / Berizin'],
                'icon': Icons.fact_check_outlined,
                'color': const Color(0xFF0D9488),
                'type': 'attendance',
              },
            ],
          },
        ],
      };
    });
  }

  Future<void> _markAllRead() async {
    try {
      if (widget.api != null) {
        await widget.api!.studentMarkNotificationsRead();
      }
      setState(() {
        if (_data != null) {
          _data!['unread_count'] = 0;
          final groups = _data!['groups'] as List? ?? [];
          for (final g in groups) {
            final items = g['items'] as List? ?? [];
            for (final it in items) {
              it['unread'] = false;
            }
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua notifikasi ditandai dibaca')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _data?['unread_count'] as int? ?? 0;
    final groups =
        (_data?['groups'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Presensi',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: navy,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: navy, size: 20),
            onPressed: () {},
          ),
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: const CircleAvatar(
              radius: 13,
              backgroundColor: Color(0xFFE0EAF8),
              child: Icon(Icons.person, size: 16, color: navy),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Header Bar: Unread Count + Button Tandai semua dibaca
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0D9488),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$unreadCount Notifikasi Baru',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F2942),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: _markAllRead,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.done_all,
                                  size: 14,
                                  color: Color(0xFF0284C7),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Tandai semua dibaca',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Filter Tabs: Semua (5) | Presensi (2) | Pelanggaran (1)
                    Row(
                      children: [
                        _buildFilterPill('all', 'Semua', 5),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          'attendance',
                          'Presensi',
                          2,
                          icon: Icons.fact_check_outlined,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          'violation',
                          'Pelanggaran',
                          1,
                          icon: Icons.error_outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_showEmptyPreview) ...[
                      const SizedBox(height: 40),
                      const Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 48,
                              color: Color(0xFF94A3B8),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Tidak Ada Notifikasi',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F2942),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Semua pengumuman dan catatan kehadiran telah dibaca.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ] else ...[
                      // Grouped Notifications
                      ...groups.map((group) {
                        final items =
                            (group['items'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            [];

                        final filtered = items.where((it) {
                          if (_activeFilter == 'all') return true;
                          final type = it['type'] as String? ?? '';
                          return type == _activeFilter;
                        }).toList();

                        if (filtered.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Group Header
                            Row(
                              children: [
                                Text(
                                  group['group_name'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F2942),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF94A3B8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  group['date_label'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const Spacer(),
                                if (group['badge_label'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      group['badge_label'] as String,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Items
                            ...filtered.map(
                              (item) => _buildNotificationCard(item),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      }),
                    ],

                    const SizedBox(height: 14),
                    // Pratinjau Status Kosong footer toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Pratinjau Status Kosong',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(
                            () => _showEmptyPreview = !_showEmptyPreview,
                          ),
                          child: Text(
                            _showEmptyPreview
                                ? 'Tampilkan Semua'
                                : 'Tampilkan Tampilan Kosong',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0284C7),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterPill(
    String key,
    String label,
    int count, {
    IconData? icon,
  }) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F2942) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F2942)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final unread = item['unread'] as bool? ?? false;
    final color = item['color'] as Color? ?? const Color(0xFF0D9488);
    final isViolation = item['is_violation'] as bool? ?? false;
    final tags = (item['tags'] as List?)?.cast<String>() ?? [];
    final badgeInfo = item['badge_info'] as Map<String, dynamic>?;

    return InkWell(
      onTap: () {
        setState(() => item['unread'] = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationDetailScreen(
              api: widget.api,
              notificationId: item['id'] as int? ?? 2,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isViolation
                ? const Color(0xFFFECACA)
                : const Color(0xFFF1F5F9),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06082B50),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item['icon'] as IconData? ?? Icons.notifications,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['category'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        item['title'] as String? ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F2942),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item['time_ago'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isViolation
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF0D9488),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              item['description'] as String? ?? '',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),

            if (badgeInfo != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFBAE6FD),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badgeInfo['title'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                          Text(
                            badgeInfo['subtitle'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF0284C7),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: const Text(
                        'Lihat Profil',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((t) {
                  final isDemerit = t.contains('Demerit');
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDemerit
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDemerit
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF475569),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
