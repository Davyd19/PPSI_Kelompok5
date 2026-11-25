import '../../widgets/school_ui.dart';
import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

class ParentCounselingScreen extends StatefulWidget {
  const ParentCounselingScreen({
    super.key,
    this.api,
    this.childId,
    this.onBack,
  });

  final AuthApi? api;
  final int? childId;
  final VoidCallback? onBack;

  @override
  State<ParentCounselingScreen> createState() => _ParentCounselingScreenState();
}

class _ParentCounselingScreenState extends State<ParentCounselingScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.api != null) {
        final res = await widget.api!.parentCounseling(childId: widget.childId);
        if (mounted) setState(() => _data = res);
      } else {
        if (mounted) {
          setState(() {
            _data = {
              'child': null,
              'items': <Map<String, dynamic>>[],
              'homeroom_teacher': null,
            };
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _data = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Activity Diagram 3.16: re-verify access via GET /parent/counseling/:id before displaying full details
  Future<void> _openCaseDetail(Map<String, dynamic> summaryCase) async {
    final caseId = summaryCase['id'] as int?;
    if (caseId == null) return;
    Map<String, dynamic> detail = summaryCase;
    if (widget.api != null) {
      try {
        detail = await widget.api!.parentCounselingDetail(
          caseId,
          childId: widget.childId,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Informasi tidak dapat diakses: $e')),
        );
        return;
      }
    }
    if (!mounted) return;

    final counselor = detail['counselor'] as Map<String, dynamic>?;
    final upcoming = detail['upcoming_session'] as Map<String, dynamic>?;
    final history =
        (detail['history'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    showDetails(
      context,
      title: 'Ringkasan Penanganan Anak',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  detail['status_label'] as String? ??
                      detail['status'] as String? ??
                      '-',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
              Text(
                detail['code'] as String? ?? '',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detail['title'] as String? ?? '-',
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dibuka: ${detail['date_opened'] ?? '-'} • Konselor: ${counselor?['name'] ?? '-'}',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ringkasan Perkembangan',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail['summary'] as String? ??
                'Belum ada ringkasan yang dibagikan.',
            style: const TextStyle(fontSize: 12.5, color: muted, height: 1.45),
          ),
          if (detail['home_advice'] != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Saran Kerjasama Rumah / Tindak Lanjut',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail['home_advice'] as String,
              style: const TextStyle(
                fontSize: 12.5,
                color: muted,
                height: 1.45,
              ),
            ),
          ],
          if (upcoming != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jadwal Tindak Lanjut / Konseling',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${upcoming['type'] ?? 'Konseling'} • ${upcoming['date_formatted'] ?? '-'} (${upcoming['time'] ?? '-'})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: navy,
                    ),
                  ),
                  if (upcoming['goal'] != null)
                    Text(
                      upcoming['goal'] as String,
                      style: const TextStyle(fontSize: 11.5, color: muted),
                    ),
                ],
              ),
            ),
          ],
          if (history.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Riwayat Tahapan Diizinkan',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: navy,
              ),
            ),
            const SizedBox(height: 6),
            for (final h in history)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: canvas,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          h['jenis'] as String? ?? '-',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: navy,
                          ),
                        ),
                        Text(
                          h['date'] as String? ?? '-',
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                    if (h['summary'] != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        h['summary'] as String,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showContactDialog(String title, Map<String, dynamic>? person) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SchoolDialog(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: person == null
            ? const Text(
                'Informasi kontak belum tersedia di sistem.',
                style: TextStyle(fontSize: 13),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person['name'] as String? ?? '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Telepon: ${person['telepon'] ?? 'Belum dicantumkan'}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  if (person['email'] != null)
                    Text(
                      'Email: ${person['email']}',
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
    final child = _data?['child'] as Map<String, dynamic>?;
    final items =
        (_data?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final teacher = _data?['homeroom_teacher'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: canvas,
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
                'Konseling Anak',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
      body: _loading
          ? const SchoolLoading()
          : (_error != null && _data == null)
          ? LoadErrorView(message: _error!, onRetry: _loadData)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      // Child header
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFFE0EAF8),
                            child: Icon(Icons.person_outline, color: navy),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  child?['name'] as String? ?? '-',
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
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 13,
                                  color: navy,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Mode Pantau',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (items.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 36,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE7EDF5)),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.support_agent_outlined,
                                size: 42,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Belum ada informasi penanganan yang dapat ditampilkan',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: navy,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final item in items) _caseCard(item),

                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.lock_outline, size: 15, color: muted),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Catatan BK internal sekolah. Kerahasiaan data siswa terjaga.',
                              style: TextStyle(fontSize: 11.5, color: muted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: navy,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final firstCounselor = items.isNotEmpty
                                ? items.first['counselor']
                                      as Map<String, dynamic>?
                                : null;
                            _showContactDialog(
                              'Konsultasi dengan Guru BK',
                              firstCounselor,
                            );
                          },
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: const Text(
                            'Hubungi / Jadwalkan Konsultasi BK',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton.icon(
                          onPressed: () =>
                              _showContactDialog('Hubungi Wali Kelas', teacher),
                          icon: const Icon(Icons.chat_outlined, size: 16),
                          label: const Text('Hubungi Wali Kelas'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _caseCard(Map<String, dynamic> item) {
    final counselor = item['counselor'] as Map<String, dynamic>?;
    return InkWell(
      onTap: () => _openCaseDetail(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7EDF5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,

              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 13,
                        color: Color(0xFF15803D),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item['status_label'] as String? ?? '-',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item['date_opened'] as String? ?? '-',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'KATEGORI BIMBINGAN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F766E),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item['title'] as String? ?? '-',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.psychology_outlined, color: navy, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        counselor?['role'] as String? ??
                            'Guru Pembimbing / Konselor BK',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                      Text(
                        counselor?['name'] as String? ?? '-',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item['summary'] != null) ...[
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 16,
                    color: Color(0xFF0F766E),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Ringkasan Perkembangan Siswa',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item['summary'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  color: muted,
                  height: 1.45,
                ),
              ),
            ],
            if (item['home_advice'] != null) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.home_outlined, size: 16, color: Color(0xFF0F766E)),
                  SizedBox(width: 6),
                  Text(
                    'Saran Kerjasama Rumah',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item['home_advice'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  color: muted,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,

              children: [
                Text(
                  'Telah Disetujui Sekolah${(item['semester_label'] as String? ?? '').isNotEmpty ? ' • ${item['semester_label']}' : ''}',
                  style: const TextStyle(fontSize: 10.5, color: muted),
                ),
                Text(
                  item['code'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 10.5,
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
  }
}
