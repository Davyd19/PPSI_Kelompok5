import '../../widgets/school_ui.dart';
import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

class ExtracurricularDetailScreen extends StatefulWidget {
  const ExtracurricularDetailScreen({
    super.key,
    this.api,
    this.ekskulId = 0,
    this.name = '',
  });

  final AuthApi? api;
  final int ekskulId;
  final String name;

  @override
  State<ExtracurricularDetailScreen> createState() =>
      _ExtracurricularDetailScreenState();
}

class _ExtracurricularDetailScreenState
    extends State<ExtracurricularDetailScreen> {
  bool _loading = true;
  bool _registering = false;
  String? _error;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.api != null) {
        final res = await widget.api!.studentExtracurricularDetail(
          widget.ekskulId,
        );
        if (mounted) setState(() => _detail = res);
      } else {
        if (mounted) setState(() => _detail = {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _detail = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_registering) return;
    setState(() => _registering = true);

    try {
      if (widget.api != null) {
        await widget.api!.studentRegisterExtracurricular(widget.ekskulId);
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      setState(() {
        if (_detail != null) {
          _detail!['is_pending'] = true;
          _detail!['registration_status'] = 'Menunggu Persetujuan';
        }
      });

      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => SchoolDialog(
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Pendaftaran Berhasil', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            'Pengajuan pendaftaran ekstrakurikuler telah diterima dengan status *Menunggu Persetujuan Pembina*. Notifikasi verifikasi akan dikirimkan.',
            style: TextStyle(fontSize: 12.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _detail?['stats'] as Map<String, dynamic>?;
    final schedule = _detail?['schedule_place'] as Map<String, dynamic>?;
    final reqs = (_detail?['requirements'] as List?)?.cast<String>() ?? [];
    final isRegistered = _detail?['is_registered'] as bool? ?? false;
    final isPending = _detail?['is_pending'] as bool? ?? false;

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Detail Ekstrakurikuler',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: navy,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: navy, size: 20),
            onPressed: () {},
          ),
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: line, width: 1.5),
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
          ? const SchoolLoading()
          : (_error != null && _detail == null)
          ? LoadErrorView(message: _error!, onRetry: _loadDetail)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadDetail,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            // Banner container
                            Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: const Color(0xFF0E2A47),
                              ),
                              child: Stack(
                                children: [
                                  const Center(
                                    child: Icon(
                                      Icons.groups_outlined,
                                      size: 48,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xDD082B50),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF38BDF8),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _detail?['category'] as String? ??
                                                '-',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Titles
                            Text(
                              _detail?['school'] as String? ?? 'SMAN 12 Padang',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _detail?['title'] as String? ?? widget.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: navy,
                              ),
                            ),
                            if ((_detail?['subtitle'] as String? ?? '')
                                    .isNotEmpty &&
                                _detail?['subtitle'] != _detail?['title']) ...[
                              const SizedBox(height: 2),
                              Text(
                                _detail!['subtitle'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),

                            // Coach Box
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    size: 16,
                                    color: navy,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _detail?['coach'] as String? ?? '-',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: navy,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 3 Metric Boxes
                            Row(
                              children: [
                                _buildMetricItem(
                                  title: stats?['active_students'] ?? '-',
                                  subtitle: 'Siswa Aktif',
                                ),
                                const SizedBox(width: 8),
                                _buildMetricItem(
                                  title: stats?['track'] ?? '-',
                                  subtitle: 'Peminatan',
                                ),
                                const SizedBox(width: 8),
                                _buildMetricItem(
                                  title: stats?['accreditation'] ?? '-',
                                  subtitle: 'Akreditasi',
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Tentang Ekstrakurikuler
                            const Text(
                              'Tentang Ekstrakurikuler',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: navy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _detail?['description'] as String? ??
                                  'Tidak ada deskripsi.',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Waktu & Tempat Latihan
                            const Text(
                              'Waktu & Tempat Latihan',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: line),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 16,
                                        color: Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          schedule?['days_time'] as String? ??
                                              'Belum dijadwalkan',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: navy,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(
                                    height: 16,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.meeting_room_outlined,
                                        size: 16,
                                        color: Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          schedule?['location'] as String? ??
                                              '-',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF475569),
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Persyaratan Bergabung
                            const Text(
                              'Persyaratan Bergabung',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: line),
                              ),
                              child: Column(
                                children: reqs.map((req) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          size: 16,
                                          color: Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            req,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF475569),
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sticky Bottom Bar: Sisa Kuota & Button Daftar Sekarang
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 10,
                            offset: Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isRegistered || isPending
                                            ? Colors.amber
                                            : const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isPending
                                          ? 'Menunggu Persetujuan'
                                          : (isRegistered
                                                ? 'Sudah Terdaftar'
                                                : (_detail?['registration_status']
                                                          as String? ??
                                                      'Pendaftaran Terbuka')),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isPending
                                            ? Colors.amber.shade800
                                            : const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sisa ${_detail?['remaining_quota'] ?? 0} Kuota',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: isRegistered || isPending
                                  ? muted
                                  : const Color(0xFF0A2540),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                            onPressed: isRegistered || isPending
                                ? null
                                : _register,
                            icon: _registering
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward, size: 16),
                            label: Text(
                              isPending
                                  ? 'Menunggu'
                                  : (isRegistered
                                        ? 'Terdaftar'
                                        : 'Daftar Sekarang'),
                              style: const TextStyle(
                                fontSize: 13,
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

  Widget _buildMetricItem({required String title, required String subtitle}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: line),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10.5, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
