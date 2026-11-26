import '../../widgets/school_ui.dart';
import '../../widgets/shared.dart';
import 'package:flutter/material.dart';

import '../../models/kasus_models.dart';
import '../../network/kasus_api.dart';
import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';
import 'kasus_list_screen.dart';

// Forms Guru BK
import 'forms/verifikasi_form.dart';
import 'forms/rencana_konseling_form.dart';
import 'forms/catatan_konseling_form.dart';
import 'forms/tindak_lanjut_ortu_form.dart';
import 'forms/eskalasi_form.dart';
import 'forms/tutup_kasus_form.dart';
import 'forms/pemantauan_form.dart';

// Forms Wali Kelas
import 'forms/catatan_pembinaan_form.dart';
import 'forms/usulan_penutupan_eskalasi_form.dart';

/// Detail kasus + riwayat penanganan + aksi-aksi sesuai role.
class KasusDetailScreen extends StatefulWidget {
  const KasusDetailScreen({
    super.key,
    required this.api,
    required this.kasusId,
    required this.role,
  });

  final KasusApi api;
  final int kasusId;
  final String role;

  @override
  State<KasusDetailScreen> createState() => _KasusDetailScreenState();
}

class _KasusDetailScreenState extends State<KasusDetailScreen> {
  Kasus? _kasus;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final k = await widget.api.detailKasus(widget.kasusId);
      if (!mounted) return;
      setState(() => _kasus = k);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm(Widget form) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => form));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: const Text('Detail Kasus & Riwayat'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: _loading && _kasus == null
            ? const SchoolLoading()
            : _error != null
            ? LoadErrorView(message: '$_error', onRetry: _reload)
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final k = _kasus!;
    final (statusColor, statusIcon) =
        kasusStatusStyle[k.status] ?? (muted, Icons.info_outline);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            // ─── Header ───
            _infoHeader(k, statusColor, statusIcon),
            const SizedBox(height: 14),

            // ─── Detail Informasi ───
            _detailInfo(k),
            const SizedBox(height: 14),

            // ─── Aksi-aksi sesuai role ───
            if (widget.role == 'GURU_BK') ..._guruBkActions(k),
            if (widget.role == 'WALI_KELAS') ..._waliKelasActions(k),

            const SizedBox(height: 14),

            // ─── Riwayat Penanganan (Timeline) ───
            _timelineSection(k),
          ],
        ),
      ),
    );
  }

  Widget _infoHeader(
    Kasus k,
    Color color,
    IconData icon,
  ) => SchoolContextHeader(
    title: k.namaSiswa,
    subtitle:
        '${k.kelas} • ${k.kategori}\nLaporan: ${formatDateId(k.tanggalLaporan)}',
    trailing: ColorPill(k.status.label, color: color, icon: icon),
  );

  Widget _detailInfo(Kasus k) => SectionCard(
    title: 'Informasi Laporan',
    icon: Icons.article_outlined,
    color: sectionBlue,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(Icons.person_outline, 'Pelapor', k.pelapor ?? '-'),
        _infoRow(Icons.place_outlined, 'Tempat', k.tempatKejadian ?? '-'),
        _infoRow(Icons.notes, 'Deskripsi', k.deskripsi ?? '-'),
        if (k.catatanVerifikasi != null)
          _infoRow(
            Icons.fact_check_outlined,
            'Catatan Verifikasi',
            k.catatanVerifikasi!,
          ),
      ],
    ),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF236A7C)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11)),
              Text(value, style: const TextStyle(color: navy)),
            ],
          ),
        ),
      ],
    ),
  );

  // ─── Timeline Riwayat ───
  Widget _timelineSection(Kasus k) => SectionCard(
    title: 'Riwayat Penanganan',
    icon: Icons.timeline,
    color: sectionPurple,
    child: k.riwayat.isEmpty
        ? const Text('Belum ada riwayat penanganan.')
        : Column(
            children: [
              for (final (i, r) in k.riwayat.reversed.toList().indexed)
                _timelineItem(r, i == 0, i == k.riwayat.length - 1),
            ],
          ),
  );

  Widget _timelineItem(RiwayatPenanganan r, bool isFirst, bool isLast) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFirst ? sectionPurple : const Color(0xFFD9DFE8),
            ),
          ),
          if (!isLast)
            Container(width: 2, height: 60, color: const Color(0xFFD9DFE8)),
        ],
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.jenis,
                style: const TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                '${formatDateId(r.tanggal)} • ${r.oleh}',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
              const SizedBox(height: 4),
              Text(r.deskripsi, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    ],
  );

  // ━━━━━━━━━━━━━ GURU BK ACTIONS ━━━━━━━━━━━━━

  List<Widget> _guruBkActions(Kasus k) => [
    SectionCard(
      title: 'Aksi Guru BK',
      icon: Icons.support_agent_outlined,
      color: const Color(0xFF236A7C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Verifikasi (hanya jika status Menunggu Verifikasi)
          if (k.status == StatusKasus.menungguVerifikasi)
            _actionButton(
              'Verifikasi Laporan',
              Icons.fact_check_outlined,
              const Color(0xFFB8860B),
              () => _openForm(
                VerifikasiForm(api: widget.api, kasus: k, onDone: _reload),
              ),
            ),

          // 2. Rencana Konseling
          if (k.status != StatusKasus.selesaiDitutup &&
              k.status != StatusKasus.menungguVerifikasi)
            _actionButton(
              'Kelola Rencana Konseling',
              Icons.event_note_outlined,
              sectionPurple,
              () => _openForm(
                RencanaKonselingForm(
                  api: widget.api,
                  kasus: k,
                  onDone: _reload,
                ),
              ),
            ),

          // 3. Catatan Konseling
          if (k.status != StatusKasus.selesaiDitutup &&
              k.status != StatusKasus.menungguVerifikasi)
            _actionButton(
              'Tambahkan Catatan Konseling',
              Icons.edit_note,
              sectionBlue,
              () => _openForm(
                CatatanKonselingForm(
                  api: widget.api,
                  kasus: k,
                  onDone: _reload,
                ),
              ),
            ),

          // 4. Tindak Lanjut & Orang Tua
          if (k.status != StatusKasus.selesaiDitutup &&
              k.status != StatusKasus.menungguVerifikasi)
            _actionButton(
              'Tindak Lanjut & Keterlibatan Orang Tua',
              Icons.family_restroom_outlined,
              sectionOrange,
              () => _openForm(
                TindakLanjutOrtuForm(
                  api: widget.api,
                  kasus: k,
                  onDone: _reload,
                ),
              ),
            ),

          // 5. Pemantauan
          if (k.status != StatusKasus.selesaiDitutup &&
              k.status != StatusKasus.menungguVerifikasi)
            _actionButton(
              'Pemantauan Perkembangan',
              Icons.trending_up,
              sectionGreen,
              () => _openForm(
                PemantauanForm(
                  api: widget.api,
                  kasus: k,
                  role: widget.role,
                  onDone: _reload,
                ),
              ),
            ),

          // 6. Eskalasi / Rujukan
          if (k.status != StatusKasus.selesaiDitutup &&
              k.status != StatusKasus.menungguVerifikasi)
            _actionButton(
              'Usulkan Eskalasi atau Rujukan',
              Icons.call_made,
              const Color(0xFFE67E22),
              () => _openForm(
                EskalasiForm(api: widget.api, kasus: k, onDone: _reload),
              ),
            ),

          // 7. Tutup Kasus
          if (k.status != StatusKasus.selesaiDitutup &&
              k.status != StatusKasus.menungguVerifikasi)
            _actionButton(
              'Tutup Kasus',
              Icons.lock_outlined,
              const Color(0xFFC62828),
              () => _openForm(
                TutupKasusForm(api: widget.api, kasus: k, onDone: _reload),
              ),
            ),
        ],
      ),
    ),
  ];

  // ━━━━━━━━━━━━━ WALI KELAS ACTIONS ━━━━━━━━━━━━━

  List<Widget> _waliKelasActions(Kasus k) => [
    SectionCard(
      title: 'Aksi Wali Kelas',
      icon: Icons.groups_outlined,
      color: const Color(0xFF236A7C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Catatan Pembinaan
          if (k.status != StatusKasus.selesaiDitutup &&
              k.status != StatusKasus.menungguVerifikasi)
            _actionButton(
              'Tambahkan Catatan Pembinaan',
              Icons.edit_note,
              sectionBlue,
              () => _openForm(
                CatatanPembinaanForm(
                  api: widget.api,
                  kasus: k,
                  onDone: _reload,
                ),
              ),
            ),

          // 2. Tindak Lanjut & Orang Tua
          if (k.status != StatusKasus.selesaiDitutup &&
              k.status != StatusKasus.menungguVerifikasi)
            _actionButton(
              'Tindak Lanjut & Keterlibatan Orang Tua',
              Icons.family_restroom_outlined,
              sectionOrange,
              () => _openForm(
                TindakLanjutOrtuForm(
                  api: widget.api,
                  kasus: k,
                  onDone: _reload,
                ),
              ),
            ),

          // 3. Pemantauan
          if (k.status != StatusKasus.selesaiDitutup &&
              k.status != StatusKasus.menungguVerifikasi)
            _actionButton(
              'Pemantauan Perkembangan',
              Icons.trending_up,
              sectionGreen,
              () => _openForm(
                PemantauanForm(
                  api: widget.api,
                  kasus: k,
                  role: widget.role,
                  onDone: _reload,
                ),
              ),
            ),

          // 4. Usulan Penutupan/Eskalasi
          if (k.status != StatusKasus.selesaiDitutup &&
              k.status != StatusKasus.menungguVerifikasi)
            _actionButton(
              'Penutupan atau Eskalasi Kasus',
              Icons.call_made,
              const Color(0xFFE67E22),
              () => _openForm(
                UsulanPenutupanEskalasiForm(
                  api: widget.api,
                  kasus: k,
                  onDone: _reload,
                ),
              ),
            ),
        ],
      ),
    ),
  ];

  Widget _actionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: .4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
    ),
  );
}
