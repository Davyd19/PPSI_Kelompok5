import 'dart:async';
import 'dart:ui' as ui;

import '../../widgets/school_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
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

String _two(int n) => n.toString().padLeft(2, '0');

/// Sisa waktu berlaku, mis. "09:58" atau "1:00:00".
String _countdown(Duration d) => d.inHours > 0
    ? '${d.inHours}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}'
    : '${_two(d.inMinutes)}:${_two(d.inSeconds % 60)}';

String _dmy(DateTime? t) =>
    t == null ? '-' : '${_two(t.day)}-${_two(t.month)}-${t.year}';

/// Pilih waktu berlaku QR (5 menit s.d. 1 jam).
Future<int?> _pickDuration(
  BuildContext context, {
  required String title,
  int initial = defaultQrMinutes,
}) => showModalBottomSheet<int>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final MapEntry(key: minutes, value: label)
            in qrDurationOptions.entries)
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(label),
            trailing: minutes == initial
                ? const Icon(Icons.check, color: _teal)
                : null,
            onTap: () => Navigator.pop(context, minutes),
          ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);

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
          _limits.putIfAbsent(entry.key, () => TimeOfDay(hour: h, minute: m));
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
    var minutes = defaultQrMinutes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => SchoolDialog(
          title: Text('Buat QR $label?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QR hanya dapat dibuat satu kali hari ini dan sama untuk '
                'seluruh siswa. Batas tepat waktu: ${_limitText(type)} WIB.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: minutes,
                decoration: const InputDecoration(
                  labelText: 'Waktu berlaku QR',
                  prefixIcon: Icon(Icons.timer_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final MapEntry(key: value, value: text)
                      in qrDurationOptions.entries)
                    DropdownMenuItem(value: value, child: Text(text)),
                ],
                onChanged: (v) => setDialog(() => minutes = v ?? minutes),
              ),
              const SizedBox(height: 8),
              const Text(
                'QR dapat ditutup lebih awal atau diaktifkan lagi kapan saja.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
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
      ),
    );
    if (ok == true) await _openConfirmed(type, minutes);
  }

  Future<void> _openConfirmed(String type, int minutes) => _guard(() async {
    final (session, token) = await widget.api.open(
      type,
      _limitText(type),
      minutes: minutes,
    );
    if (!mounted) return;
    await _showQr(session, token);
  });

  Future<void> _showQr(SchoolSession session, [QrToken? token]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _QrPage(api: widget.api, session: session, initialToken: token),
      ),
    );
    // Status QR (ditutup / diaktifkan lagi) mungkin berubah di halaman QR.
    if (mounted) await _reload();
  }

  Future<void> _manual(SchoolSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManualAttendancePage(api: widget.api, session: session),
      ),
    );
    await _reload();
  }

  Future<void> _close(SchoolSession session) async {
    final pending = session.summary['BELUM_DIISI'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => SchoolDialog(
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
        title: const SchoolPageTitle(title: 'Sesi Presensi Sekolah'),
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
    final icon = type == 'PAGI'
        ? Icons.wb_sunny_outlined
        : Icons.mosque_outlined;
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
            if (session.isActive) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: ColorPill(
                  session.isQrActive
                      ? 'QR berlaku s.d. ${_hhmm(session.qrValidUntil)}'
                      : 'QR tidak aktif',
                  color: session.isQrActive ? sectionGreen : sectionOrange,
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
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

/// Layar QR sesi: satu QR per sesi untuk dibagikan ke seluruh siswa.
/// Menampilkan sisa waktu berlaku, dan guru dapat menutup QR lebih awal,
/// mengaktifkannya lagi dengan durasi baru, atau mengunduhnya sebagai gambar.
class _QrPage extends StatefulWidget {
  const _QrPage({required this.api, required this.session, this.initialToken});
  final SchoolAttendanceApi api;
  final SchoolSession session;
  final QrToken? initialToken;

  @override
  State<_QrPage> createState() => _QrPageState();
}

class _QrPageState extends State<_QrPage> {
  final _qrKey = GlobalKey();
  QrToken? _token;
  AttendanceSummary? _summary;
  bool _loading = false;
  bool _busy = false;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _summary = widget.session.summary;
    _token = widget.initialToken;
    // Hitung mundur sisa waktu berlaku QR setiap detik.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _token != null) setState(() {});
    });
    _refresh();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Ambil QR (kode sama, masa berlaku terbaru) dan ringkasan terbaru.
  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final token = await widget.api.qr(widget.session.id);
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

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _toast(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final token = _token;
    if (token == null) return;
    await Clipboard.setData(ClipboardData(text: token.code));
    if (mounted) _toast(context, 'Kode QR disalin.');
  }

  Future<void> _closeQr() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => SchoolDialog(
        title: const Text('Tutup QR sekarang?'),
        content: const Text(
          'Siswa tidak dapat memindai QR ini lagi. Sesi tetap aktif, jadi Anda '
          'masih bisa menginput presensi manual atau mengaktifkan QR lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tutup QR'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final token = await widget.api.closeQr(widget.session.id);
      if (!mounted) return;
      setState(() => _token = token);
      _toast(context, 'QR ditutup.');
    });
  }

  Future<void> _setDuration() async {
    final active = _token?.isActive ?? false;
    final minutes = await _pickDuration(
      context,
      title: active
          ? 'Atur ulang waktu berlaku (mulai sekarang)'
          : 'Aktifkan QR lagi selama',
    );
    if (minutes == null) return;
    await _run(() async {
      final token = await widget.api.extendQr(widget.session.id, minutes);
      if (!mounted) return;
      setState(() => _token = token);
      _toast(context, 'QR berlaku sampai ${_hhmm(token.validUntil)}.');
    });
  }

  /// Simpan kartu QR (beserta nama sesi & masa berlaku) ke galeri sebagai PNG.
  Future<void> _download() => _run(() async {
    final boundary =
        _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw 'Gagal membuat gambar QR.';
    try {
      // Gal meminta izin galeri sendiri bila belum diberikan.
      final type = widget.session.type == 'PAGI' ? 'Pagi' : 'Zuhur';
      final opened = widget.session.openedAt ?? DateTime.now();
      await Gal.putImageBytes(
        data.buffer.asUint8List(),
        album: 'SIM Kesiswaan',
        name:
            'QR_Presensi_${type}_${opened.year}${_two(opened.month)}'
            '${_two(opened.day)}_${_two(DateTime.now().hour)}'
            '${_two(DateTime.now().minute)}${_two(DateTime.now().second)}',
      );
    } on GalException catch (e) {
      throw switch (e.type) {
        GalExceptionType.permissionDenied =>
          'Izin menyimpan ke galeri ditolak. Aktifkan di Pengaturan aplikasi.',
        GalExceptionType.notEnoughSpace => 'Penyimpanan perangkat penuh.',
        _ => 'Gagal menyimpan QR ke galeri.',
      };
    }
    if (mounted) _toast(context, 'QR tersimpan di galeri (album SIM Kesiswaan).');
  });

  @override
  Widget build(BuildContext context) {
    final token = _token;
    final summary = _summary;
    final active = token?.isActive ?? false;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: SchoolPageTitle(title: 'QR ${widget.session.label}'),
        actions: [
          IconButton(
            tooltip: 'Unduh QR',
            onPressed: token == null || _busy ? null : _download,
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Perbarui',
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
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Bagian ini yang disimpan saat QR diunduh.
                    RepaintBoundary(
                      key: _qrKey,
                      child: _QrCard(session: widget.session, token: token),
                    ),
                    if (token != null && !active)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .88),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_off_outlined,
                                size: 48,
                                color: sectionOrange,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'QR tidak aktif',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: navy,
                                ),
                              ),
                              Text(
                                'Siswa tidak dapat memindai QR ini.',
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (token == null)
                  const Text(
                    'Memuat QR...',
                    style: TextStyle(fontSize: 12, color: muted),
                  )
                else
                  _ValidityBanner(token: token),
                const SizedBox(height: 16),
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: token == null || _busy ? null : _download,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Unduh QR'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: token == null || _busy
                                  ? null
                                  : _setDuration,
                              icon: Icon(
                                active ? Icons.more_time : Icons.play_arrow,
                                size: 18,
                              ),
                              label: Text(active ? 'Atur Waktu' : 'Aktifkan'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                              ),
                              onPressed: !active || _busy ? null : _closeQr,
                              icon: const Icon(Icons.timer_off_outlined,
                                  size: 18),
                              label: const Text('Tutup QR'),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: token == null ? null : _copy,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Salin kode QR'),
                      ),
                    ],
                  ),
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

/// Kartu QR yang ditampilkan sekaligus disimpan saat diunduh: identitas
/// sekolah, nama sesi, tanggal, QR, dan batas berlaku.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.session, required this.token});
  final SchoolSession session;
  final QrToken? token;

  @override
  Widget build(BuildContext context) {
    final token = this.token;
    return Container(
      width: 304,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _teal.withValues(alpha: .3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SMAN 12 PADANG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _teal,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'QR ${session.label}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          Text(
            _dmy(session.openedAt),
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 8),
          token == null
              ? const SizedBox(
                  width: 280,
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                )
              : QrImageView(
                  data: token.code,
                  size: 280,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'QR presensi ${session.label}',
                ),
          if (token != null)
            Text(
              'Berlaku s.d. ${_hhmm(token.validUntil)} WIB',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
            ),
        ],
      ),
    );
  }
}

/// Status masa berlaku: hitung mundur saat aktif, atau keterangan tidak aktif.
class _ValidityBanner extends StatelessWidget {
  const _ValidityBanner({required this.token});
  final QrToken token;

  @override
  Widget build(BuildContext context) {
    final active = token.isActive;
    final color = active ? sectionGreen : sectionOrange;
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.timer_outlined : Icons.timer_off_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? 'Sisa waktu ${_countdown(token.remaining)}'
                      : 'QR tidak aktif',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                Text(
                  active
                      ? 'Berlaku sampai ${_hhmm(token.validUntil)} WIB'
                      : 'Berakhir ${_hhmm(token.validUntil)} WIB • '
                            'tekan Aktifkan untuk membuka lagi',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
