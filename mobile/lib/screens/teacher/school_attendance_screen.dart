import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../network/school_attendance_api.dart';
import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';
import 'manual_attendance_page.dart';

const _teal = Color(0xFF236A7C);
const _soft = Color(0xFFECF2FD);

String _hhmm(DateTime? time) => time == null
    ? '-'
    : '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';

void _toast(BuildContext context, Object message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message.toString())));

/// Use case Guru: "Membuka Sesi Presensi Sekolah" (presensi pagi & salat Zuhur)
/// dengan QR dinamis dan input manual berjejak bila pemindaian gagal.
class SchoolAttendanceScreen extends StatefulWidget {
  const SchoolAttendanceScreen({super.key, required this.api});
  final SchoolAttendanceApi api;

  @override
  State<SchoolAttendanceScreen> createState() => _SchoolAttendanceScreenState();
}

class _SchoolAttendanceScreenState extends State<SchoolAttendanceScreen> {
  SchoolDay? _day;
  Object? _error;
  bool _busy = false;
  final _limits = <String, TimeOfDay>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final day = await widget.api.today();
      if (!mounted) return;
      setState(() {
        _day = day;
        _error = null;
        for (final entry in day.defaultLimits.entries) {
          final [h, m] = entry.value.split(':').map(int.parse).toList();
          _limits.putIfAbsent(
            entry.key,
            () => TimeOfDay(hour: h, minute: m),
          );
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _toast(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _reload();
  }

  String _limitText(String type) {
    final t = _limits[type] ?? const TimeOfDay(hour: 7, minute: 15);
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickLimit(String type) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _limits[type] ?? TimeOfDay.now(),
      helpText: 'Batas tepat waktu (WIB)',
    );
    if (picked != null) setState(() => _limits[type] = picked);
  }

  Future<void> _open(String type) async {
    final label = type == 'PAGI' ? 'Presensi Pagi' : 'Salat Zuhur';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Buat QR $label?'),
        content: Text(
          'QR hanya dapat dibuat satu kali hari ini dan berlaku untuk seluruh '
          'siswa sampai sesi ditutup. Batas tepat waktu: ${_limitText(type)} WIB.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buat QR'),
          ),
        ],
      ),
    );
    if (ok == true) await _openConfirmed(type);
  }

  Future<void> _openConfirmed(String type) => _guard(() async {
    final (session, token) = await widget.api.open(type, _limitText(type));
    if (!mounted) return;
    await _showQr(session, token);
  });

  Future<void> _showQr(SchoolSession session, [QrToken? token]) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _QrPage(
            api: widget.api,
            session: session,
            initialToken: token,
          ),
        ),
      );

  Future<void> _manual(SchoolSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ManualAttendancePage(api: widget.api, session: session),
      ),
    );
    await _reload();
  }

  Future<void> _close(SchoolSession session) async {
    final pending = session.summary['BELUM_DIISI'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tutup ${session.label}?'),
        content: Text(
          'QR akan dinonaktifkan dan siswa tidak bisa memindai lagi.'
          '${pending > 0 ? '\n\n$pending siswa masih "Belum Diisi" dan tidak otomatis menjadi Alfa.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tutup Sesi'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _guard(() async {
        await widget.api.close(session.id);
        if (mounted) _toast(context, '${session.label} ditutup.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: const Text('Sesi Presensi Sekolah'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: day == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$_error', textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _reload,
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      HeroHeader(
                        icon: Icons.today_outlined,
                        title: formatYmd(day.date),
                        subtitle: 'Presensi sekolah hari ini',
                      ),
                      if (!day.hasSemester)
                        SectionCard(
                          title: 'Belum ada semester aktif',
                          icon: Icons.warning_amber_outlined,
                          color: sectionOrange,
                          child: const Text('Sesi belum dapat dibuka.'),
                        ),
                      for (final type in const ['PAGI', 'ZUHUR'])
                        _sessionCard(type, day.session(type), day.hasSemester),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sessionCard(String type, SchoolSession? session, bool canOpen) {
    final title = type == 'PAGI' ? 'Presensi Pagi' : 'Salat Zuhur';
    final icon = type == 'PAGI' ? Icons.wb_sunny_outlined : Icons.mosque_outlined;
    final (statusText, statusColor) = switch (session?.status) {
      null => ('Belum dibuka', muted),
      'AKTIF' => ('Aktif', sectionGreen),
      _ => ('Ditutup', sectionOrange),
    };
    return SectionCard(
      title: title,
      icon: icon,
      color: type == 'PAGI' ? sectionBlue : sectionGreen,
      trailing: ColorPill(statusText, color: statusColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session == null) ...[
            OutlinedButton.icon(
              onPressed: () => _pickLimit(type),
              icon: const Icon(Icons.schedule),
              label: Text('Batas tepat waktu ${_limitText(type)} WIB'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy || !canOpen ? null : () => _open(type),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Buat QR Sesi'),
            ),
          ] else ...[
            Text(
              'Buka ${_hhmm(session.openedAt)} • Batas ${_hhmm(session.onTimeLimit)}'
              '${session.isActive ? '' : ' • Tutup ${_hhmm(session.closedAt)}'}',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 8),
            // QR sesi ini sudah dibuat (1x per hari) — tampilkan siapa pembuatnya.
            Align(
              alignment: Alignment.centerLeft,
              child: ColorPill(
                session.isMine
                    ? 'QR dibuat oleh Anda'
                    : 'QR dibuat oleh ${session.openedBy ?? 'guru lain'}',
                color: session.isMine ? sectionBlue : sectionPurple,
                icon: Icons.lock_outline,
              ),
            ),
            const SizedBox(height: 12),
            _SummaryRow(summary: session.summary),
            if (session.isActive) ...[
              const SizedBox(height: 12),
              // Semua guru dapat melihat QR yang sama; tidak ada pembuatan QR baru.
              FilledButton.icon(
                onPressed: _busy ? null : () => _showQr(session),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Lihat QR'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _manual(session),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Input Manual'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _close(session),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Tutup Sesi'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = {
      'HADIR': summary['HADIR'],
      'TERLAMBAT': summary['TERLAMBAT'],
      'IZIN': summary['IZIN'] + summary['SAKIT'],
      'BELUM_DIISI': summary['BELUM_DIISI'],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: summary.total == 0 ? 0 : summary.recorded / summary.total,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: _soft,
          color: _teal,
        ),
        const SizedBox(height: 6),
        Text(
          '${summary.recorded}/${summary.total} tercatat',
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (i, e) in items.entries.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AttendanceCountTile(status: e.key, count: e.value),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Layar QR statis: satu QR per sesi, tidak berganti, untuk dibagikan ke
/// seluruh siswa. Halaman ini hanya menampilkan QR yang sudah dibuat.
class _QrPage extends StatefulWidget {
  const _QrPage({required this.api, required this.session, this.initialToken});
  final SchoolAttendanceApi api;
  final SchoolSession session;
  final QrToken? initialToken;

  @override
  State<_QrPage> createState() => _QrPageState();
}

class _QrPageState extends State<_QrPage> {
  QrToken? _token;
  AttendanceSummary? _summary;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _summary = widget.session.summary;
    _token = widget.initialToken;
    _refresh();
  }

  /// Ambil QR (sama seperti sebelumnya) dan ringkasan terbaru.
  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final token = _token ?? await widget.api.qr(widget.session.id);
      final day = await widget.api.today();
      if (!mounted) return;
      setState(() {
        _token = token;
        _error = null;
        for (final s in day.sessions) {
          if (s.id == widget.session.id) _summary = s.summary;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy() async {
    final token = _token;
    if (token == null) return;
    await Clipboard.setData(ClipboardData(text: token.code));
    if (mounted) _toast(context, 'Kode QR disalin.');
  }

  @override
  Widget build(BuildContext context) {
    final token = _token;
    final summary = _summary;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: Text('QR ${widget.session.label}'),
        actions: [
          IconButton(
            tooltip: 'Perbarui jumlah',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ColorPill(
                  widget.session.isMine
                      ? 'QR dibuat oleh Anda'
                      : 'QR dibuat oleh ${widget.session.openedBy ?? 'guru lain'}',
                  color: widget.session.isMine ? sectionBlue : sectionPurple,
                  icon: Icons.lock_outline,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _teal.withValues(alpha: .3)),
                  ),
                  child: token == null
                      ? const SizedBox(
                          width: 280,
                          height: 280,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : QrImageView(
                          data: token.code,
                          size: 280,
                          backgroundColor: Colors.white,
                          semanticsLabel: 'QR presensi ${widget.session.label}',
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  token == null
                      ? 'Memuat QR...'
                      : 'Berlaku untuk seluruh siswa sampai sesi ditutup',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: token == null ? null : _copy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Salin kode QR'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Coba lagi'),
                  ),
                ],
                if (summary != null) ...[
                  const SizedBox(height: 24),
                  SizedBox(width: 320, child: _SummaryRow(summary: summary)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
