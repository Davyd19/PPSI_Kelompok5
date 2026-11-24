import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

class ParentAchievementsBadgesScreen extends StatefulWidget {
  const ParentAchievementsBadgesScreen({
    super.key,
    this.api,
    this.childId,
    this.initialTab = 0,
    this.onBack,
  });

  final AuthApi? api;
  final int? childId;
  final int initialTab; // 0 = Prestasi, 1 = Badge Karakter
  final VoidCallback? onBack;

  @override
  State<ParentAchievementsBadgesScreen> createState() =>
      _ParentAchievementsBadgesScreenState();
}

class _ParentAchievementsBadgesScreenState
    extends State<ParentAchievementsBadgesScreen> {
  late int _tab = widget.initialTab;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _achData;
  Map<String, dynamic>? _badgeData;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.api != null) {
        final results = await Future.wait([
          widget.api!.parentAchievements(childId: widget.childId),
          widget.api!.parentBadges(childId: widget.childId),
        ]);
        if (mounted) {
          setState(() {
            _achData = results[0];
            _badgeData = results[1];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _achData = {
              'child': null,
              'summary': {'total': 0, 'provinsi': 0, 'nasional': 0},
              'items': <Map<String, dynamic>>[],
            };
            _badgeData = {
              'child': null,
              'summary': {'earned': 0, 'total': 0},
              'items': <Map<String, dynamic>>[],
            };
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _achData = null;
          _badgeData = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty || parts.first == '-') return 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // Activity Diagram 3.13: detail prestasi + lihat bukti
  void _showAchievementDetail(Map<String, dynamic> item) {
    final attachments =
        (item['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    showDetails(
      context,
      title: 'Detail Prestasi Anak',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['title'] as String? ?? '-',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: navy,
            ),
          ),
          const SizedBox(height: 10),
          _kv('Kegiatan', item['activity_name'] as String? ?? 'Umum'),
          _kv('Tingkat', item['tingkat'] as String? ?? '-'),
          _kv('Tanggal', item['date'] as String? ?? '-'),
          _kv('Hasil', item['hasil'] as String? ?? '-'),
          if (item['nama_tim'] != null)
            _kv('Nama Tim', item['nama_tim'] as String),
          if (item['deskripsi'] != null)
            _kv('Keterangan', item['deskripsi'] as String),
          _kv('Disahkan oleh', item['verified_by'] as String? ?? '-'),
          const SizedBox(height: 12),
          const Text(
            'Bukti Prestasi',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 6),
          if (attachments.isEmpty)
            const Text(
              'Tidak ada bukti yang dilampirkan.',
              style: TextStyle(fontSize: 12, color: muted),
            )
          else
            for (final att in attachments)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: navy,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        att['nama_berkas'] as String? ?? 'Berkas',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: navy,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final available = att['tersedia'] == true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              available
                                  ? 'Membuka berkas ${att['nama_berkas']}...'
                                  : 'Bukti prestasi tidak tersedia.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Lihat Bukti'),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // Activity Diagram 3.14: detail badge (terbuka / terkunci, level maks / progres level berikutnya)
  void _showBadgeDetail(Map<String, dynamic> badge) {
    final earned = badge['diperoleh'] == true;
    final isMax = badge['is_max_level'] == true;
    final nextLevel = badge['next_level'] as Map<String, dynamic>?;
    final progress = (badge['progress'] as num?)?.toInt() ?? 0;
    final target = (badge['target'] as num?)?.toInt() ?? 0;

    showDetails(
      context,
      title: 'Detail Badge Anak',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: earned
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFF1F5F9),
                child: Icon(
                  earned ? Icons.emoji_events : Icons.lock_outline,
                  color: earned ? const Color(0xFF15803D) : muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${badge['badge'] ?? 'Badge'} • ${badge['nama'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    Text(
                      earned ? 'Terbuka (Diperoleh)' : 'Terkunci',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: earned ? const Color(0xFF15803D) : muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (badge['deskripsi'] != null) ...[
            Text(
              badge['deskripsi'] as String,
              style: const TextStyle(fontSize: 12.5, color: muted),
            ),
            const SizedBox(height: 10),
          ],
          _kv('Syarat Pencapaian', badge['syarat'] as String? ?? '-'),
          if (earned) ...[
            _kv('Level Saat Ini', badge['nama'] as String? ?? '-'),
            _kv(
              'Tanggal Pencapaian',
              badge['waktu_diperoleh'] as String? ?? '-',
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Text(
                isMax
                    ? 'Level maksimum tercapai.'
                    : 'Level berikutnya: ${nextLevel?['nama'] ?? '-'} (${nextLevel?['syarat'] ?? ''})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
          ] else ...[
            _kv('Progres Menuju Level Pertama', '$progress / $target'),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: target > 0 ? (progress / target).clamp(0.0, 1.0) : 0,
              minHeight: 7,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: const Color(0xFFE2E8F0),
              color: navy,
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: navy,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final child =
        (_achData?['child'] ?? _badgeData?['child']) as Map<String, dynamic>?;
    final achSummary = _achData?['summary'] as Map<String, dynamic>?;
    final achItems =
        (_achData?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final badgeSummary = _badgeData?['summary'] as Map<String, dynamic>?;
    final badgeItems =
        (_badgeData?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final childName = child?['name'] as String? ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.onBack != null
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: navy,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: const Text(
                'Prestasi & Badge Anak',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _achData == null && _badgeData == null)
          ? LoadErrorView(message: _error!, onRetry: _loadAll)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      // Child header card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE7EDF5)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility_outlined,
                                        size: 13,
                                        color: Color(0xFF0369A1),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Mode Pantau (Baca Saja)',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0369A1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.circle,
                                      size: 7,
                                      color: Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      child?['status'] == 'AKTIF'
                                          ? 'Aktif'
                                          : (child?['status'] as String? ??
                                                '-'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: navy,
                                  foregroundColor: Colors.white,
                                  child: Text(
                                    _initials(childName),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        childName,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: navy,
                                        ),
                                      ),
                                      Text(
                                        'NISN: ${child?['nisn'] ?? '-'} • ${child?['classroom'] ?? '-'}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: muted,
                                        ),
                                      ),
                                      Text(
                                        'SMAN 12 Padang • TP ${child?['academic_year'] ?? '-'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Segmented Switch: Prestasi | Badge Karakter
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _segmentTab(
                              index: 0,
                              icon: Icons.emoji_events_outlined,
                              label: 'Prestasi',
                            ),
                            _segmentTab(
                              index: 1,
                              icon: Icons.workspace_premium_outlined,
                              label: 'Badge Karakter',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (_tab == 0) ...[
                        // Achievements summary 3 boxes
                        Row(
                          children: [
                            _summaryBox(
                              'Total',
                              '${achSummary?['total'] ?? 0}',
                              'Sertifikat',
                            ),
                            const SizedBox(width: 8),
                            _summaryBox(
                              'Provinsi',
                              '${achSummary?['provinsi'] ?? 0}',
                              'Ajang',
                            ),
                            const SizedBox(width: 8),
                            _summaryBox(
                              'Nasional',
                              '${achSummary?['nasional'] ?? 0}',
                              'Ajang',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Daftar Capaian Resmi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: navy,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (achItems.isEmpty)
                          _emptyBox(
                            Icons.emoji_events_outlined,
                            'Belum ada prestasi tercatat',
                            'Prestasi resmi anak yang telah diverifikasi sekolah akan tampil di sini.',
                          )
                        else
                          for (final item in achItems) _achievementCard(item),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 16, color: muted),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Data prestasi dimasukkan dan divalidasi langsung oleh Tim Kesiswaan SMAN 12 Padang. Wali murid hanya berwenang untuk memantau rekam jejak.',
                                  style: TextStyle(fontSize: 11, color: muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Badges summary
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE7EDF5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${badgeSummary?['earned'] ?? 0} dari ${badgeSummary?['total'] ?? 0} Badge Terbuka',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: navy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value:
                                    ((badgeSummary?['total'] as num?) ?? 0) > 0
                                    ? (((badgeSummary?['earned'] as num?) ??
                                              0) /
                                          ((badgeSummary?['total'] as num?) ??
                                              1))
                                    : 0,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(6),
                                backgroundColor: const Color(0xFFE2E8F0),
                                color: const Color(0xFF0F766E),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (badgeItems.isEmpty)
                          _emptyBox(
                            Icons.workspace_premium_outlined,
                            'Belum ada badge tersedia',
                            'Katalog badge karakter dan pencapaian anak akan ditampilkan di sini.',
                          )
                        else
                          for (final b in badgeItems) _badgeCard(b),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _segmentTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final active = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? navy : muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? navy : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryBox(String title, String value, String unit) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  unit,
                  style: const TextStyle(fontSize: 10.5, color: muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _achievementCard(Map<String, dynamic> item) => InkWell(
    onTap: () => _showAchievementDetail(item),
    borderRadius: BorderRadius.circular(16),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: navy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item['activity_name'] != null)
                          _pill(
                            item['activity_name'] as String,
                            const Color(0xFFDBEAFE),
                            const Color(0xFF1D4ED8),
                          ),
                        _pill(
                          'Tingkat ${item['tingkat'] ?? 'Sekolah'}',
                          const Color(0xFFF1F5F9),
                          navy,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['title'] as String? ?? '-',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item['date'] as String? ?? '-',
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Disahkan: ${item['verified_by'] ?? '-'}',
                  style: const TextStyle(fontSize: 11, color: muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Text(
                'Terverifikasi Sekolah',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F766E),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _badgeCard(Map<String, dynamic> b) {
    final earned = b['diperoleh'] == true;
    final progress = (b['progress'] as num?)?.toInt() ?? 0;
    final target = (b['target'] as num?)?.toInt() ?? 0;
    return InkWell(
      onTap: () => _showBadgeDetail(b),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: earned ? const Color(0xFFBBF7D0) : const Color(0xFFE7EDF5),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: earned
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF1F5F9),
              child: Icon(
                earned ? Icons.emoji_events : Icons.lock_outline,
                color: earned ? const Color(0xFF15803D) : muted,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${b['badge'] ?? 'Badge'} • ${b['nama'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    earned
                        ? 'Diperoleh ${b['waktu_diperoleh'] ?? ''}'
                        : 'Progres $progress / $target',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: earned ? const Color(0xFF15803D) : muted,
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
  }

  Widget _pill(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
    ),
  );

  Widget _emptyBox(IconData icon, String title, String subtitle) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE7EDF5)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 42, color: const Color(0xFF94A3B8)),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: muted),
        ),
      ],
    ),
  );
}
