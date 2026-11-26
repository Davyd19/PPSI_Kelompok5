import '../../../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../../../models/kasus_models.dart';
import '../../../network/kasus_api.dart';
import '../../../theme.dart';
import '../../../widgets/attendance_widgets.dart';
import 'kasus_form_widgets.dart';

/// Formulir usul eskalasi atau rujukan kasus (Guru BK).
class EskalasiForm extends StatefulWidget {
  const EskalasiForm({
    super.key,
    required this.api,
    required this.kasus,
    required this.onDone,
  });

  final KasusApi api;
  final Kasus kasus;
  final VoidCallback onDone;

  @override
  State<EskalasiForm> createState() => _EskalasiFormState();
}

class _EskalasiFormState extends State<EskalasiForm> {
  final _pihak = TextEditingController();
  final _alasan = TextEditingController();
  final _evaluasi = TextEditingController();
  final _pendukung = TextEditingController();
  final _errors = <String, String>{};
  bool _busy = false;
  String _jenis = 'ESKALASI';

  @override
  void dispose() {
    _pihak.dispose();
    _alasan.dispose();
    _evaluasi.dispose();
    _pendukung.dispose();
    super.dispose();
  }

  Map<String, String> _validate() => {
    if (_pihak.text.trim().isEmpty)
      'pihak': 'Pihak berwenang tujuan wajib diisi.',
    if (_alasan.text.trim().isEmpty)
      'alasan': 'Alasan eskalasi/rujukan wajib diisi.',
    if (_evaluasi.text.trim().isEmpty)
      'evaluasi': 'Hasil evaluasi wajib diisi.',
    if (_pendukung.text.trim().isEmpty)
      'pendukung': 'Informasi pendukung wajib diisi.',
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
        const SnackBar(content: Text('Data eskalasi/rujukan belum lengkap.')),
      );
      return;
    }
    setState(() {
      _errors.clear();
      _busy = true;
    });
    try {
      await widget.api.usulkanEskalasi(
        widget.kasus.id,
        pihakTujuan: _pihak.text.trim(),
        jenisUsulan: _jenis,
        alasan: _alasan.text.trim(),
        hasilEvaluasi: _evaluasi.text.trim(),
        informasiPendukung: _pendukung.text.trim(),
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
      title: const Text('Eskalasi Berhasil Dikirim'),
      content: Text(
        'Usulan eskalasi/rujukan kasus ${widget.kasus.namaSiswa} telah '
        'diteruskan kepada pihak berwenang.',
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
      title: const Text('Eskalasi / Rujukan'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            HeroHeader(
              icon: Icons.call_made,
              title: widget.kasus.namaSiswa,
              subtitle: '${widget.kasus.kelas} • ${widget.kasus.kategori}',
            ),
            SectionCard(
              title: 'Formulir Eskalasi / Rujukan',
              icon: Icons.call_made,
              color: const Color(0xFFE67E22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KasusFieldLabel('Jenis Usulan *'),
                  DropdownButtonFormField<String>(
                    initialValue: _jenis,
                    items: const [
                      DropdownMenuItem(
                        value: 'ESKALASI',
                        child: Text('Eskalasi ke Kesiswaan'),
                      ),
                      DropdownMenuItem(
                        value: 'RUJUKAN',
                        child: Text('Usulan rujukan'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _jenis = value!),
                    decoration: kasusInputDecoration(
                      hint: 'Pilih jenis usulan',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tujuan dan alasan dibagikan untuk peninjauan. Hasil evaluasi dan informasi pendukung tetap menjadi catatan internal BK.',
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Pihak Berwenang Tujuan *'),
                  TextField(
                    controller: _pihak,
                    onChanged: (_) => setState(() => _errors.remove('pihak')),
                    decoration: kasusInputDecoration(
                      hint: 'Misal: Kepala Sekolah, Kesiswaan, Psikolog',
                      prefixIcon: const Icon(Icons.business_outlined),
                      errorText: _errors['pihak'],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Alasan Eskalasi/Rujukan *'),
                  TextField(
                    controller: _alasan,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() => _errors.remove('alasan')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan alasan alih tangan/eskalasi...',
                      errorText: _errors['alasan'],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Hasil Evaluasi *'),
                  TextField(
                    controller: _evaluasi,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) =>
                        setState(() => _errors.remove('evaluasi')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan hasil evaluasi pembinaan sebelumnya...',
                      errorText: _errors['evaluasi'],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Informasi Pendukung *'),
                  TextField(
                    controller: _pendukung,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) =>
                        setState(() => _errors.remove('pendukung')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan informasi/dokumen pendukung...',
                      errorText: _errors['pendukung'],
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
            backgroundColor: const Color(0xFFE67E22),
          ),
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
              : const Icon(Icons.send_rounded),
          label: Text(_busy ? 'Mengirim...' : 'Kirim Usulan Eskalasi'),
        ),
      ),
    ),
  );
}
