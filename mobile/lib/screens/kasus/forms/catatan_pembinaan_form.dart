import 'package:flutter/material.dart';

import '../../../models/kasus_models.dart';
import '../../../network/kasus_api.dart';
import '../../../theme.dart';
import '../../../widgets/attendance_widgets.dart';
import 'kasus_form_widgets.dart';

/// Formulir catatan pembinaan (Wali Kelas).
class CatatanPembinaanForm extends StatefulWidget {
  const CatatanPembinaanForm({
    super.key,
    required this.api,
    required this.kasus,
    required this.onDone,
  });

  final KasusApi api;
  final Kasus kasus;
  final VoidCallback onDone;

  @override
  State<CatatanPembinaanForm> createState() => _CatatanPembinaanFormState();
}

class _CatatanPembinaanFormState extends State<CatatanPembinaanForm> {
  final _hasil = TextEditingController();
  final _tindakan = TextEditingController();
  final _tindakLanjut = TextEditingController();
  final _errors = <String, String>{};
  bool _busy = false;

  @override
  void dispose() {
    _hasil.dispose();
    _tindakan.dispose();
    _tindakLanjut.dispose();
    super.dispose();
  }

  Map<String, String> _validate() => {
    if (_hasil.text.trim().isEmpty)
      'hasil': 'Hasil pembinaan wajib diisi.',
    if (_tindakan.text.trim().isEmpty)
      'tindakan': 'Tindakan yang diberikan wajib diisi.',
    if (_tindakLanjut.text.trim().isEmpty)
      'tindak_lanjut': 'Rencana tindak lanjut wajib diisi.',
  };

  Future<void> _submit() async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(() => _errors
        ..clear()
        ..addAll(errors));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data catatan pembinaan belum lengkap.')),
      );
      return;
    }
    setState(() {
      _errors.clear();
      _busy = true;
    });
    try {
      await widget.api.simpanCatatanPembinaan(
        widget.kasus.id,
        hasilPembinaan: _hasil.text.trim(),
        tindakanDiberikan: _tindakan.text.trim(),
        rencanaTindakLanjut: _tindakLanjut.text.trim(),
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
        title: const Text('Catatan Pembinaan Tersimpan'),
        content: Text(
          'Catatan pembinaan untuk ${widget.kasus.namaSiswa} berhasil disimpan '
          'dan riwayat penanganan telah diperbarui.',
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
      title: const Text('Catatan Pembinaan'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            HeroHeader(
              icon: Icons.edit_note,
              title: widget.kasus.namaSiswa,
              subtitle: '${widget.kasus.kelas} • ${widget.kasus.kategori}',
            ),
            SectionCard(
              title: 'Formulir Catatan Pembinaan',
              icon: Icons.edit_note,
              color: sectionBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KasusFieldLabel('Hasil Pembinaan *'),
                  TextField(
                    controller: _hasil,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) =>
                        setState(() => _errors.remove('hasil')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan hasil pembinaan siswa...',
                      errorText: _errors['hasil'],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Tindakan yang Diberikan *'),
                  TextField(
                    controller: _tindakan,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) =>
                        setState(() => _errors.remove('tindakan')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan tindakan/arahan yang diberikan...',
                      errorText: _errors['tindakan'],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Rencana Tindak Lanjut *'),
                  TextField(
                    controller: _tindakLanjut,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) =>
                        setState(() => _errors.remove('tindak_lanjut')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan langkah tindak lanjut berikutnya...',
                      errorText: _errors['tindak_lanjut'],
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
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,
                  ))
              : const Icon(Icons.save),
          label: Text(_busy ? 'Menyimpan...' : 'Simpan Catatan'),
        ),
      ),
    ),
  );
}
