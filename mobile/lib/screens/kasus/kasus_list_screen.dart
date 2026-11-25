import '../../widgets/school_ui.dart';
import '../../widgets/shared.dart';
import 'package:flutter/material.dart';

import '../../models/kasus_models.dart';
import '../../network/kasus_api.dart';
import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';
import 'kasus_detail_screen.dart';

/// Warna & ikon badge per status kasus.
const kasusStatusStyle = <StatusKasus, (Color, IconData)>{
  StatusKasus.menungguVerifikasi: (Color(0xFFB8860B), Icons.hourglass_top),
  StatusKasus.dalamPembinaan: (Color(0xFF2768B2), Icons.groups_outlined),
  StatusKasus.rencanaKonselingAktif: (Color(0xFF6A4BB2), Icons.event_note),
  StatusKasus.dirujukEskalasi: (Color(0xFFE67E22), Icons.call_made),
  StatusKasus.selesaiDitutup: (Color(0xFF1E7D4F), Icons.check_circle_outline),
};

/// Daftar seluruh kasus. Digunakan oleh Guru BK dan Wali Kelas.
class KasusListScreen extends StatefulWidget {
  const KasusListScreen({
    super.key,
    required this.api,
    required this.role,
    this.isEmbedded = false,
  });

  final KasusApi api;
  final String role;
  final bool isEmbedded;

  @override
  State<KasusListScreen> createState() => _KasusListScreenState();
}

class _KasusListScreenState extends State<KasusListScreen> {
  List<Kasus>? _list;
  bool _loading = true;
  Object? _error;
  StatusKasus? _filter;

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
      final data = await widget.api.daftarKasus(
        filterStatus: _filter?.apiValue,
      );
      if (!mounted) return;
      setState(() => _list = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail(Kasus kasus) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => KasusDetailScreen(
              api: widget.api.forKasus(kasus),
              kasusId: kasus.id,
              role: widget.role,
            ),
          ),
        )
        .then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: _reload,
      child: _loading && _list == null
          ? const SchoolLoading()
          : _error != null
          ? LoadErrorView(message: '$_error', onRetry: _reload)
          : _buildContent(),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: const Text('Laporan & Penanganan Kasus'),
      ),
      body: content,
    );
  }

  Widget _buildContent() {
    final list = _list ?? [];
    final roleName = widget.role == 'GURU_BK' ? 'Guru BK' : 'Wali Kelas';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            HeroHeader(
              icon: Icons.folder_open_outlined,
              title: '${list.length} Kasus',
              subtitle: widget.role == 'GURU_BK'
                  ? 'Daftar kasus sesuai kewenangan $roleName'
                  : 'Kasus siswa binaan $roleName',
            ),
            _filterChips(),
            const SizedBox(height: 10),
            if (list.isEmpty) const SchoolEmpty('Tidak ada kasus ditemukan.'),
            for (final k in list) _kasusCard(k),
          ],
        ),
      ),
    );
  }

  Widget _filterChips() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _chip(null, 'Semua'),
        for (final s in StatusKasus.values) _chip(s, s.label),
      ],
    ),
  );

  Widget _chip(StatusKasus? status, String label) {
    final selected = _filter == status;
    final (color, _) = status != null
        ? kasusStatusStyle[status] ?? (muted, Icons.circle)
        : (navy, Icons.circle);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: selected,
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selectedColor: color.withValues(alpha: .15),
        checkmarkColor: color,
        side: BorderSide(color: selected ? color : const Color(0xFFDCE6F3)),
        onSelected: (_) {
          setState(() => _filter = status);
          _reload();
        },
      ),
    );
  }

  Widget _kasusCard(Kasus k) {
    final (color, icon) =
        kasusStatusStyle[k.status] ?? (muted, Icons.info_outline);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: .35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(k),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k.namaSiswa,
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${k.kategori} • ${k.kelas}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${formatDateId(k.tanggalLaporan)} • ${k.tempatKejadian ?? '-'}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              ColorPill(k.status.label, color: color, icon: icon),
            ],
          ),
        ),
      ),
    );
  }
}
