import '../../../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../../../models/kasus_models.dart';
import '../../../network/kasus_api.dart';
import '../../../theme.dart';
import '../../../widgets/attendance_widgets.dart';
import 'kasus_form_widgets.dart';

/// Formulir mencatat asesmen dan konseling (Guru BK).
class CatatanKonselingForm extends StatefulWidget {
  const CatatanKonselingForm({
    super.key,
    required this.api,
    required this.kasus,
    required this.onDone,
  });

  final KasusApi api;
  final Kasus kasus;
  final VoidCallback onDone;

  @override
  State<CatatanKonselingForm> createState() => _CatatanKonselingFormState();
}

class _CatatanKonselingFormState extends State<CatatanKonselingForm> {
  final _kondisi = TextEditingController();
  final _asesmen = TextEditingController();
  final _ringkasan = TextEditingController();
  final _tindakLanjut = TextEditingController();
  final _errors = <String, String>{};
  bool _busy = false;

  @override
  void dispose() {
    _kondisi.dispose();
    _asesmen.dispose();
    _ringkasan.dispose();
    _tindakLanjut.dispose();
    super.dispose();
  }

  Map<String, String> _validate() => {
    if (_kondisi.text.trim().isEmpty)
      'kondisi': 'Kondisi permasalahan wajib diisi.',
    if (_asesmen.text.trim().isEmpty) 'asesmen': 'Hasil asesmen wajib diisi.',
    if (_ringkasan.text.trim().isEmpty)
      'ringkasan': 'Ringkasan konseling wajib diisi.',
    if (_tindakLanjut.text.trim().isEmpty)
      'tindak_lanjut': 'Rencana tindak lanjut wajib diisi.',
  };

  Future<void> _submit() async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(
        () => _errors
          ..clear()
          ..addAll(errors),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data catatan konseling belum lengkap.')),
      );
      return;
    }
    setState(() {
      _errors.clear();
      _busy = true;
    });
    try {
      await widget.api.simpanCatatanKonseling(
        widget.kasus.id,
        kondisiPermasalahan: _kondisi.text.trim(),
        hasilAsesmen: _asesmen.text.trim(),
        ringkasanKonseling: _ringkasan.text.trim(),
        rencanaTindakLanjut: _tindakLanjut.text.trim(),
      );
      if (!mounted) return;
      widget.onDone();
      _showSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSuccess() async {
    final confirmed = await showSchoolSuccess(
      context,
      title: const Text('Catatan Konseling Tersimpan'),
      content: Text(
        'Catatan konseling untuk ${widget.kasus.namaSiswa} berhasil disimpan '
        'dan riwayat konseling telah diperbarui.',
        textAlign: TextAlign.center,
      ),
    );
    if (confirmed && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: navy,
      title: const Text('Catatan Konseling'),
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
              title: 'Formulir Catatan Konseling',
              icon: Icons.edit_note,
              color: sectionBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KasusFieldLabel('Kondisi Permasalahan *'),
                  TextField(
                    controller: _kondisi,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() => _errors.remove('kondisi')),
                    decoration: kasusInputDecoration(
                      hint: 'Jelaskan kondisi permasalahan siswa...',
                      errorText: _errors['kondisi'],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Hasil Asesmen *'),
                  TextField(
                    controller: _asesmen,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() => _errors.remove('asesmen')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan hasil asesmen/diagnosis...',
                      errorText: _errors['asesmen'],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Ringkasan Konseling *'),
                  TextField(
                    controller: _ringkasan,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) =>
                        setState(() => _errors.remove('ringkasan')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan ringkasan sesi konseling...',
                      errorText: _errors['ringkasan'],
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(_busy ? 'Menyimpan...' : 'Simpan Catatan Konseling'),
        ),
      ),
    ),
  );
}
