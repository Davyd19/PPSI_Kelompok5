import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../network/auth_api.dart';
import 'attendance_confirmation_screen.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key, this.api});
  final AuthApi? api;

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _flashOn = false;
  bool _loading = false;
  bool _scanned = false; // prevent double-trigger

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scanner.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed) {
      _scanner.start();
    } else if (state == AppLifecycleState.paused) {
      _scanner.stop();
    }
  }

  Future<void> _processQr(String? code, {String? manualCode}) async {
    if (_loading || _scanned) return;
    if (code != null && code.startsWith('EKSKUL:')) {
      _showError('Presensi ekstrakurikuler dicatat oleh Pembina.');
      return;
    }
    setState(() {
      _loading = true;
      _scanned = true;
    });

    try {
      final Map<String, dynamic> data;
      if (widget.api != null) {
        data = await widget.api!.studentScanAttendance(
          qrCode: code,
          manualCode: manualCode,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
        data = {
          'check_in_time': '06:43 WIB',
          'status_kehadiran': 'HADIR',
          'tolerance_limit': '',
          'student_name': 'Siswa Demo',
          'student_classroom': 'XI MIPA 1',
          'student_nisn': '0099990001',
          'date_formatted': 'Demo Mode',
          'streak_days': 1,
        };
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AttendanceConfirmationScreen(
            checkInTime: data['check_in_time'] as String? ?? '-',
            statusLabel: data['status_kehadiran'] as String? ?? '-',
            toleranceLimit: data['tolerance_limit'] as String? ?? '',
            studentName: data['student_name'] as String? ?? '-',
            studentInfo:
                '${data['student_classroom'] ?? ''} • NISN: ${data['student_nisn'] ?? ''}',
            dateFormatted: data['date_formatted'] as String? ?? '-',
            streakDays: '${data['streak_days'] ?? 0} Hari Berturut-turut',
          ),
        ),
      );
    } on AuthError catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _scanned = false;
        });
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _scanned = false;
        });
        _showError('Gagal memproses presensi. Coba lagi.');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showManualDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Input Kode Presensi',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan 6-digit kode harian dari Guru Piket Gerbang SMAN 12:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLength: 6,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 10,
                color: Color(0xFF0E2A47),
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '------',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  letterSpacing: 10,
                  fontSize: 22,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF0D9488),
                    width: 2,
                  ),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final code = ctrl.text.trim();
              if (code.length != 6) return;
              Navigator.pop(ctx);
              _processQr(null, manualCode: code);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
            ),
            child: const Text('Konfirmasi Presensi'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFlash() async {
    await _scanner.toggleTorch();
    setState(() => _flashOn = !_flashOn);
  }

  Future<void> _switchCamera() async {
    await _scanner.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera viewfinder ───────────────────────────────────────────
          MobileScanner(
            controller: _scanner,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue;
              if (raw != null && raw.isNotEmpty) {
                _processQr(raw);
              }
            },
            errorBuilder: (context, exception) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white54,
                      size: 56,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      exception.errorCode ==
                              MobileScannerErrorCode.permissionDenied
                          ? 'Izin kamera ditolak.\nBuka Pengaturan > Aplikasi untuk mengizinkan.'
                          : 'Kamera tidak tersedia.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _processQr(null, manualCode: null),
                      icon: const Icon(Icons.keyboard_alt_outlined),
                      label: const Text('Input Kode Manual'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Overlay: Header ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Scan Presensi QR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _flashOn ? Icons.flash_on : Icons.flash_off,
                          color: _flashOn ? Colors.amber : Colors.white,
                        ),
                        onPressed: _toggleFlash,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Arahkan kamera ke QR Code Gerbang SMAN 12 Padang',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),

                // ── QR frame overlay ──────────────────────────────────────
                const Spacer(),
                _QrFrameOverlay(),
                const Spacer(),

                // ── Status bar & manual button ────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Column(
                    children: [
                      if (_loading)
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF6DECB9),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Memproses presensi...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.qr_code_scanner,
                              color: Color(0xFF6DECB9),
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Menunggu QR Code...',
                              style: TextStyle(
                                color: Color(0xFF6DECB9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _loading ? null : _showManualDialog,
                              icon: const Icon(
                                Icons.keyboard_alt_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                'Kode Manual',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _loading ? null : _switchCamera,
                              icon: const Icon(
                                Icons.cameraswitch_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                'Ganti Kamera',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QR Frame Overlay Widget
// ---------------------------------------------------------------------------
class _QrFrameOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const size = 240.0;
    const corner = 20.0;
    const thickness = 4.0;
    const color = Color(0xFF6DECB9);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Semi-transparent fill
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          // Corners
          _Corner(
            top: 0,
            left: 0,
            size: corner,
            thickness: thickness,
            color: color,
          ),
          _Corner(
            top: 0,
            right: 0,
            size: corner,
            thickness: thickness,
            color: color,
          ),
          _Corner(
            bottom: 0,
            left: 0,
            size: corner,
            thickness: thickness,
            color: color,
          ),
          _Corner(
            bottom: 0,
            right: 0,
            size: corner,
            thickness: thickness,
            color: color,
          ),
          // Center crosshair dot
          const Center(
            child: Icon(Icons.crop_free, color: Colors.white24, size: 60),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.thickness,
    required this.color,
  });
  final double? top, bottom, left, right;
  final double size, thickness;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CornerPainter(
            color: color,
            thickness: thickness,
            isLeft: left != null,
            isTop: top != null,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.color,
    required this.thickness,
    required this.isLeft,
    required this.isTop,
  });
  final Color color;
  final double thickness;
  final bool isLeft, isTop;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square;
    final len = size.width;
    if (isLeft && isTop) {
      canvas.drawLine(Offset(0, 0), Offset(len, 0), paint);
      canvas.drawLine(Offset(0, 0), Offset(0, len), paint);
    } else if (!isLeft && isTop) {
      canvas.drawLine(Offset(0, 0), Offset(len, 0), paint);
      canvas.drawLine(Offset(len, 0), Offset(len, len), paint);
    } else if (isLeft && !isTop) {
      canvas.drawLine(Offset(0, 0), Offset(0, len), paint);
      canvas.drawLine(Offset(0, len), Offset(len, len), paint);
    } else {
      canvas.drawLine(Offset(len, 0), Offset(len, len), paint);
      canvas.drawLine(Offset(0, len), Offset(len, len), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) =>
      old.color != color || old.thickness != thickness;
}
