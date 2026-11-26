import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../network/auth_api.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import 'account_dashboard.dart' show PortalList;

/// Legacy screen, not used by current navigation. Extracurricular attendance is manual.
/// Pembina: QR presensi yang diperbarui otomatis selama sesi dibuka.
/// Token baru diminta sebelum yang lama kedaluwarsa, sehingga foto QR tidak bisa dipakai lama.
class PembinaQrScreen extends StatefulWidget {
  const PembinaQrScreen({
    super.key,
    required this.api,
    required this.meetingId,
    required this.title,
  });

  final AuthApi api;
  final String meetingId, title;

  @override
  State<PembinaQrScreen> createState() => _PembinaQrScreenState();
}

class _PembinaQrScreenState extends State<PembinaQrScreen> {
  String? _code, _error;
  DateTime? _expires;
  int _ttl = 60;
  Timer? _tick, _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _refresh?.cancel();
    try {
      final data = Map<String, dynamic>.from(
        await widget.api.pembinaSend('/pertemuan/${widget.meetingId}/qr')
            as Map,
      );
      if (!mounted) return;
      setState(() {
        _code = data['kode'] as String;
        _ttl = (data['berlaku_detik'] as num?)?.toInt() ?? 60;
        // Pakai jam perangkat agar hitung mundur tidak terganggu selisih jam server.
        _expires = DateTime.now().add(Duration(seconds: _ttl));
        _error = null;
      });
      _refresh = Timer(Duration(seconds: (_ttl - 10).clamp(5, _ttl)), _load);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      _refresh = Timer(const Duration(seconds: 5), _load);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = PortalTone.of(context);
    final left = _expires == null
        ? 0
        : _expires!.difference(DateTime.now()).inSeconds.clamp(0, _ttl);
    return Scaffold(
      appBar: AppBar(title: const Text('QR Presensi')),
      body: PortalList(
        children: [
          BrandBand(
            child: Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SESI PRESENSI DIBUKA',
                        style: TextStyle(
                          color: Color(0xFFB9C8DA),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .8,
                        ),
                      ),
                      Text(
                        widget.title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppPanel(
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedSwitcher(
                    duration: motionBase,
                    switchInCurve: motionCurve,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: .96, end: 1.0).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _code == null
                        ? Center(
                            key: const ValueKey('loading'),
                            child: _error == null
                                ? const CircularProgressIndicator()
                                : Text(_error!, textAlign: TextAlign.center),
                          )
                        : QrImageView(
                            key: ValueKey(_code),
                            data: _code!,
                            padding: const EdgeInsets.all(6),
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: navy,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: navy,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: _ttl == 0 ? 0 : left / _ttl),
                        duration: const Duration(milliseconds: 900),
                        builder: (context, value, _) =>
                            CircularProgressIndicator(
                              value: value,
                              strokeWidth: 3,
                              color: tone.color,
                              backgroundColor: tone.soft,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _code == null
                            ? 'Menyiapkan QR…'
                            : 'Diperbarui otomatis · berlaku $left detik lagi',
                        style: const TextStyle(color: muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppPanel(
            color: tone.soft,
            child: const Text(
              'Minta anggota membuka menu Ekskul lalu pilih "Scan QR Presensi". '
              'Anggota yang memindai tercatat Hadir. Yang tidak hadir tetap bisa '
              'dicatat manual oleh Pembina; Belum Diisi tidak otomatis menjadi Alfa.',
              style: TextStyle(color: navy, height: 1.45),
            ),
          ),
          if (_code != null)
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _code!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Kode disalin. Berguna bila kamera siswa bermasalah.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Salin kode cadangan'),
            ),
        ],
      ),
    );
  }
}

/// Siswa: memindai QR pembina. Bila kamera tidak tersedia (misalnya emulator),
/// kode cadangan dari pembina bisa ditempel secara manual.
class StudentScanScreen extends StatefulWidget {
  const StudentScanScreen({super.key, required this.api});
  final AuthApi api;

  @override
  State<StudentScanScreen> createState() => _StudentScanScreenState();
}

class _StudentScanScreenState extends State<StudentScanScreen>
    with SingleTickerProviderStateMixin {
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  bool _busy = false;

  @override
  void dispose() {
    _line.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _submit(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _scanner.stop();
    try {
      final result = await widget.api.scanEkskulAttendance(code);
      if (!mounted) return;
      await showAppDialog<void>(
        context,
        title: 'Presensi tercatat',
        icon: Icons.check_rounded,
        iconColor: cGreen.$1,
        iconBackground: cGreen.$2,
        child: Text(
          'Kamu tercatat Hadir di ${result['kegiatan'] ?? 'kegiatan ini'}'
          '${result['lokasi'] == null ? '' : ' (${result['lokasi']})'}.',
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      await showAppDialog<void>(
        context,
        title: 'Presensi gagal',
        icon: Icons.error_outline_rounded,
        iconColor: cBrick.$1,
        iconBackground: cBrick.$2,
        child: Text(error.toString()),
      );
      if (mounted) {
        setState(() => _busy = false);
        await _scanner.start();
      }
    }
  }

  Future<void> _manual() async {
    final controller = TextEditingController();
    final code = await showAppDialog<String>(
      context,
      title: 'Masukkan kode',
      icon: Icons.keyboard_alt_outlined,
      child: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'EKSKUL:…'),
      ),
      actions: [
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
        ),
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Kirim'),
          ),
        ),
      ],
    );
    controller.dispose();
    if (code != null && code.isNotEmpty) await _submit(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        shape: const Border(),
        title: const Text('Scan QR Presensi'),
        actions: [
          IconButton(
            tooltip: 'Senter',
            onPressed: _scanner.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final box = (constraints.maxWidth * .68).clamp(180.0, 320.0);
          final window = Rect.fromCenter(
            center: Offset(
              constraints.maxWidth / 2,
              constraints.maxHeight * .42,
            ),
            width: box,
            height: box,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: MobileScanner(
                  controller: _scanner,
                  scanWindow: window,
                  onDetect: (capture) {
                    final raw = capture.barcodes.firstOrNull?.rawValue;
                    if (raw != null && raw.startsWith('EKSKUL:')) _submit(raw);
                  },
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Kamera tidak dapat dibuka (${error.errorCode.name}). '
                        'Izinkan akses kamera atau gunakan kode cadangan.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _ScanMask(window)),
                ),
              ),
              Positioned.fromRect(
                rect: window,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _line,
                    builder: (context, _) => Align(
                      alignment: Alignment(0, _line.value * 2 - 1),
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7FD3C4),
                          boxShadow: const [
                            BoxShadow(color: Color(0x997FD3C4), blurRadius: 10),
                          ],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: window.bottom + 24,
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: motionBase,
                      child: _busy
                          ? const SizedBox(
                              key: ValueKey('busy'),
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              key: ValueKey('hint'),
                              'Arahkan kamera ke QR di layar pembina',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB9C8DA),
                      ),
                      onPressed: _busy ? null : _manual,
                      icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                      label: const Text('Masukkan kode cadangan'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Menggelapkan area di luar jendela pindai dan menggambar sudut bingkai.
class _ScanMask extends CustomPainter {
  _ScanMask(this.window);
  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(window, const Radius.circular(20));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = const Color(0xB30E2A47),
    );
    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 26.0;
    final r = window;
    for (final (p, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(p, p.translate(len * dx, 0), corner);
      canvas.drawLine(p, p.translate(0, len * dy), corner);
    }
  }

  @override
  bool shouldRepaint(_ScanMask old) => old.window != window;
}
