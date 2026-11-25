import 'package:flutter/material.dart';

import '../../../models/kasus_models.dart';
import '../../../network/kasus_api.dart';
import '../../../theme.dart';
import '../../../widgets/attendance_widgets.dart';
import 'kasus_form_widgets.dart';

/// Formulir penutupan kasus (Guru BK).
class TutupKasusForm extends StatefulWidget {
  const TutupKasusForm({
    super.key,
    required this.api,
    required this.kasus,
    required this.onDone,
  });

  final KasusApi api;
  final Kasus kasus;
  final VoidCallback onDone;

  @override
  State<TutupKasusForm> createState() => _TutupKasusFormState();
}

class _TutupKasusFormState extends State<TutupKasusForm> {
  final _alasan = TextEditingController();
  final _pendukung = TextEditingController();
  final _akhir = TextEditingController();
  final _errors = <String, String>{};
  bool _busy = false;

  @override
  void dispose() {
    _alasan.dispose();
    _pendukung.dispose();
    _akhir.dispose();
    super.dispose();
  }

  Map<String, String> _validate() => {
    if (_alasan.text.trim().isEmpty)
      'alasan': 'Alasan penutupan kasus wajib diisi.',
    if (_pendukung.text.trim().isEmpty)
      'pendukung': 'Catatan pendukung wajib diisi.',
    if (_akhir.text.trim().isEmpty)
      'akhir': 'Catatan akhir penanganan wajib diisi.',
  };

  Future<void> _submit() async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(() => _errors
        ..clear()
        ..addAll(errors));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data penutupan kasus belum lengkap.')),
      );
      return;
    }
    setState(() {
      _errors.clear();
      _busy = true;
    });
    try {
      await widget.api.tutupKasus(
        widget.kasus.id,
        alasanPenutupan: _alasan.text.trim(),
        catatanPendukung: _pendukung.text.trim(),
        catatanAkhir: _akhir.text.trim(),
      );
      if (!mounted) return;
      widget.onDone();
      _showSuccess();
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

  void _showSuccess() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFE6F4EC),
          child: Icon(Icons.check_rounded, color: Color(0xFF1E7D4F), size: 34),
        ),
        title: const Text('Kasus Berhasil Ditutup'),
        content: Text(
          'Kasus ${widget.kasus.namaSiswa} telah ditutup dan status diperbarui '
          'menjadi "Selesai / Ditutup".',
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
      title: const Text('Tutup Kasus'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            HeroHeader(
              icon: Icons.lock_outlined,
              title: widget.kasus.namaSiswa,
              subtitle: '${widget.kasus.kelas} • ${widget.kasus.kategori}',
            ),
            SectionCard(
              title: 'Formulir Penutupan Kasus',
              icon: Icons.lock_outlined,
              color: const Color(0xFFC62828),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pastikan seluruh data dan riwayat penanganan telah lengkap '
                    'sebelum menutup kasus.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC62828)),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Alasan Penutupan Kasus *'),
                  TextField(
                    controller: _alasan,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) =>
                        setState(() => _errors.remove('alasan')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan alasan penutupan kasus...',
                      errorText: _errors['alasan'],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Catatan Pendukung *'),
                  TextField(
                    controller: _pendukung,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) =>
                        setState(() => _errors.remove('pendukung')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan kriteria keberhasilan / bukti pendukung...',
                      errorText: _errors['pendukung'],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Catatan Akhir Penanganan *'),
                  TextField(
                    controller: _akhir,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) =>
                        setState(() => _errors.remove('akhir')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan kesimpulan akhir penanganan...',
                      errorText: _errors['akhir'],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC62828),
          ),
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,
                  ))
              : const Icon(Icons.lock_outlined),
          label: Text(_busy ? 'Memproses...' : 'Tutup Kasus'),
        ),
      ),
    ),
  );
}
