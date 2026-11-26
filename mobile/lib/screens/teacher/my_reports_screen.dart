import '../../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../../network/violation_report_api.dart';
import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';
import 'violation_report_screen.dart';

const _statusInfo = {
  'MENUNGGU': ('Menunggu verifikasi', sectionOrange, Icons.hourglass_top),
  'TERVERIFIKASI': ('Terverifikasi', sectionGreen, Icons.verified_outlined),
  'DITOLAK': ('Ditolak', Color(0xFFC62828), Icons.cancel_outlined),
};

/// Laporan pelanggaran yang dikirim guru ini beserta status verifikasinya.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key, required this.api});
  final ViolationReportApi api;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final _rows = <MyReport>[];
  int _total = 0, _page = 1;
  bool _loading = true;
  Object? _error;
  String _query = '';

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
      final r = await widget.api.mine(query: _query);
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(r.rows);
        _total = r.total;
        _page = 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _more() async {
    final r = await widget.api.mine(page: _page + 1, query: _query);
    if (!mounted) return;
    setState(() {
      _rows.addAll(r.rows);
      _page++;
    });
  }

  Future<void> _newReport() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ViolationReportScreen(api: widget.api)),
    );
    if (sent == true) _reload();
  }

  void _detail(MyReport r) {
    final (label, color, icon) =
        _statusInfo[r.status] ?? (r.status, muted, Icons.info_outline);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ColorPill(label, color: color, icon: icon),
              const SizedBox(height: 10),
              Text(r.student, style: Theme.of(context).textTheme.titleLarge),
              Text(r.classroom ?? '-', style: const TextStyle(fontSize: 12)),
              const Divider(height: 24),
              _row(Icons.category_outlined, 'Jenis', r.category),
              _row(
                Icons.event,
                'Waktu',
                '${formatDateId(r.occurredAt)} • ${formatHhmm(r.occurredAt)}',
              ),
              _row(Icons.place_outlined, 'Tempat', r.place ?? '-'),
              _row(Icons.notes, 'Deskripsi', r.description ?? '-'),
              _row(
                Icons.photo_library_outlined,
                'Bukti',
                '${r.attachments} berkas',
              ),
              if (r.verificationNote != null)
                _row(
                  Icons.fact_check_outlined,
                  'Catatan Kesiswaan',
                  r.verificationNote!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: attendanceTeal),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: navy,
      title: const SchoolPageTitle(title: 'Laporan Pelanggaran Saya'),
    ),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: const Color(0xFFC62828),
      foregroundColor: Colors.white,
      onPressed: _newReport,
      icon: const Icon(Icons.add),
      label: const Text('Lapor'),
    ),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: _loading && _rows.isEmpty && _query.isEmpty
          ? const SchoolLoading()
          : _error != null && _rows.isEmpty && _query.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text('$_error')),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
              children: [
                // Pencarian selalu di paling atas halaman.
                SchoolSearchField(
                  hint: 'Cari nama siswa, NIS, jenis, atau tempat',
                  initialValue: _query,
                  debounce: const Duration(milliseconds: 400),
                  onChanged: (v) {
                    _query = v.trim();
                    _reload();
                  },
                ),
                const SizedBox(height: 12),
                HeroHeader(
                  icon: Icons.gavel_outlined,
                  title: _query.isEmpty
                      ? '$_total laporan'
                      : '$_total laporan ditemukan',
                  subtitle: 'Status verifikasi oleh Kesiswaan',
                ),
                if (_loading && _rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.isEmpty
                          ? 'Belum ada laporan. Tekan "Lapor" untuk membuat laporan.'
                          : 'Tidak ada laporan yang cocok dengan "$_query".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final r in _rows) _card(r),
                if (_rows.length < _total)
                  OutlinedButton(
                    onPressed: _more,
                    child: const Text('Muat lebih banyak'),
                  ),
              ],
            ),
    ),
  );

  Widget _card(MyReport r) {
    final (label, color, icon) =
        _statusInfo[r.status] ?? (r.status, muted, Icons.info_outline);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: .35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _detail(r),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 56,
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
                      r.student,
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${r.category} • ${r.classroom ?? '-'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${formatDateId(r.occurredAt)} • ${r.place ?? '-'}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              ColorPill(label, color: color, icon: icon),
            ],
          ),
        ),
      ),
    );
  }
}
