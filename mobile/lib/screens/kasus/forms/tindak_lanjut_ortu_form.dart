import 'package:flutter/material.dart';

import '../../../models/kasus_models.dart';
import '../../../network/kasus_api.dart';
import '../../../theme.dart';
import '../../../widgets/attendance_widgets.dart';
import 'kasus_form_widgets.dart';

/// Formulir tindak lanjut & keterlibatan orang tua (Guru BK & Wali Kelas).
class TindakLanjutOrtuForm extends StatefulWidget {
  const TindakLanjutOrtuForm({
    super.key,
    required this.api,
    required this.kasus,
    required this.onDone,
  });

  final KasusApi api;
  final Kasus kasus;
  final VoidCallback onDone;

  @override
  State<TindakLanjutOrtuForm> createState() => _TindakLanjutOrtuFormState();
}

class _TindakLanjutOrtuFormState extends State<TindakLanjutOrtuForm> {
  static const _bentukOptions = [
    'Panggilan Sekolah',
    'Telepon',
    'WhatsApp',
    'Home Visit',
  ];

  final _hasil = TextEditingController();
  final _tindakLanjut = TextEditingController();
  DateTime _tanggal = DateTime.now();
  String? _bentuk;
  final _errors = <String, String>{};
  bool _busy = false;

  @override
  void dispose() {
    _hasil.dispose();
    _tindakLanjut.dispose();
    super.dispose();
  }

  Map<String, String> _validate() => {
    if (_hasil.text.trim().isEmpty) 'hasil': 'Hasil komunikasi wajib diisi.',
    if (_bentuk == null) 'bentuk': 'Bentuk keterlibatan wajib dipilih.',
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
        const SnackBar(content: Text('Data tindak lanjut belum lengkap.')),
      );
      return;
    }
    setState(() {
      _errors.clear();
      _busy = true;
    });
    try {
      await widget.api.simpanTindakLanjutOrtu(
        widget.kasus.id,
        hasilKomunikasi: _hasil.text.trim(),
        tanggalKomunikasi: _tanggal,
        bentukKeterlibatan: _bentuk!,
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
        title: const Text('Tindak Lanjut Tersimpan'),
        content: Text(
          'Catatan tindak lanjut dan keterlibatan orang tua untuk '
          '${widget.kasus.namaSiswa} berhasil disimpan.',
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2, 1, 1);
    final lastDate = DateTime(now.year + 1, 12, 31);
    final safeInitial = _tanggal.isBefore(firstDate)
        ? now
        : _tanggal.isAfter(lastDate)
        ? lastDate
        : _tanggal;
    final date = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Tanggal Komunikasi',
    );
    if (date != null && mounted) {
      setState(() => _tanggal = date);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: navy,
      title: const Text('Tindak Lanjut Orang Tua'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            HeroHeader(
              icon: Icons.family_restroom_outlined,
              title: widget.kasus.namaSiswa,
              subtitle: '${widget.kasus.kelas} • ${widget.kasus.kategori}',
            ),
            SectionCard(
              title: 'Formulir Tindak Lanjut',
              icon: Icons.family_restroom_outlined,
              color: sectionOrange,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KasusFieldLabel('Hasil Komunikasi *'),
                  TextField(
                    controller: _hasil,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() => _errors.remove('hasil')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan ringkasan hasil komunikasi...',
                      errorText: _errors['hasil'],
                    ),
                  ),
                  const SizedBox(height: 14),
                  KasusDatePickerField(
                    label: 'Tanggal Komunikasi *',
                    valueText: formatDateId(_tanggal),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Bentuk Keterlibatan Orang Tua *'),
                  DropdownButtonFormField<String>(
                    value: _bentuk,
                    isExpanded: true,
                    decoration: kasusInputDecoration(
                      hint: 'Pilih bentuk keterlibatan...',
                      prefixIcon: const Icon(Icons.people_outline),
                      errorText: _errors['bentuk'],
                    ),
                    items: [
                      for (final b in _bentukOptions)
                        DropdownMenuItem(value: b, child: Text(b)),
                    ],
                    onChanged: (v) => setState(() {
                      _bentuk = v;
                      _errors.remove('bentuk');
                    }),
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
                      hint: 'Tuliskan rencana tindak lanjut...',
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
          label: Text(_busy ? 'Menyimpan...' : 'Simpan Tindak Lanjut'),
        ),
      ),
    ),
  );
}
