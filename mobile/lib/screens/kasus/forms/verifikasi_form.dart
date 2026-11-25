import 'package:flutter/material.dart';

import '../../../models/kasus_models.dart';
import '../../../network/kasus_api.dart';
import '../../../theme.dart';
import '../../../widgets/attendance_widgets.dart';
import 'kasus_form_widgets.dart';

/// Formulir verifikasi laporan pelanggaran (Guru BK).
class VerifikasiForm extends StatefulWidget {
  const VerifikasiForm({
    super.key,
    required this.api,
    required this.kasus,
    required this.onDone,
  });

  final KasusApi api;
  final Kasus kasus;
  final VoidCallback onDone;

  @override
  State<VerifikasiForm> createState() => _VerifikasiFormState();
}

class _VerifikasiFormState extends State<VerifikasiForm> {
  final _catatan = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _submit(bool terima) async {
    if (_catatan.text.trim().isEmpty) {
      setState(() => _error = 'Catatan verifikasi wajib diisi.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (terima) {
        await widget.api.verifikasiTerima(
          widget.kasus.id, _catatan.text.trim());
      } else {
        await widget.api.verifikasiTolak(
          widget.kasus.id, _catatan.text.trim());
      }
      if (!mounted) return;
      widget.onDone();
      _showSuccess(terima ? 'diterima' : 'ditolak');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSuccess(String hasil) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFE6F4EC),
          child: Icon(Icons.check_rounded, color: Color(0xFF1E7D4F), size: 34),
        ),
        title: const Text('Verifikasi Berhasil'),
        content: Text(
          'Laporan ${widget.kasus.namaSiswa} telah $hasil.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: navy,
      title: const Text('Verifikasi Laporan'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            SectionCard(
              title: 'Detail Laporan',
              icon: Icons.article_outlined,
              color: sectionBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Siswa', widget.kasus.namaSiswa),
                  _row('Kelas', widget.kasus.kelas),
                  _row('Kategori', widget.kasus.kategori),
                  _row('Deskripsi', widget.kasus.deskripsi ?? '-'),
                  _row('Pelapor', widget.kasus.pelapor ?? '-'),
                  _row('Tempat', widget.kasus.tempatKejadian ?? '-'),
                  _row('Tanggal',
                      formatDateId(widget.kasus.tanggalLaporan)),
                ],
              ),
            ),
            SectionCard(
              title: 'Catatan Verifikasi',
              icon: Icons.rate_review_outlined,
              color: const Color(0xFFB8860B),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KasusFieldLabel('Catatan Verifikasi *'),
                  TextField(
                    controller: _catatan,
                    minLines: 3,
                    maxLines: 6,
                    onChanged: (_) => setState(() => _error = null),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan hasil pemeriksaan / alasan verifikasi...',
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC62828),
                            side: const BorderSide(color: Color(0xFFC62828)),
                          ),
                          onPressed: _busy ? null : () => _submit(false),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Tolak / Revisi'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E7D4F),
                          ),
                          onPressed: _busy ? null : () => _submit(true),
                          icon: _busy
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white,
                                  ))
                              : const Icon(Icons.verified_outlined),
                          label: const Text('Terima'),
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
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: muted)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: navy, fontSize: 13)),
        ),
      ],
    ),
  );
}
