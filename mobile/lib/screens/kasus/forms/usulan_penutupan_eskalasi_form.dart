import 'package:flutter/material.dart';

import '../../../models/kasus_models.dart';
import '../../../network/kasus_api.dart';
import '../../../theme.dart';
import '../../../widgets/attendance_widgets.dart';
import 'kasus_form_widgets.dart';

/// Formulir usulan penutupan atau eskalasi (Wali Kelas).
/// Status kasus tetap aktif sampai pihak berwenang memutuskan.
class UsulanPenutupanEskalasiForm extends StatefulWidget {
  const UsulanPenutupanEskalasiForm({
    super.key,
    required this.api,
    required this.kasus,
    required this.onDone,
  });

  final KasusApi api;
  final Kasus kasus;
  final VoidCallback onDone;

  @override
  State<UsulanPenutupanEskalasiForm> createState() =>
      _UsulanPenutupanEskalasiFormState();
}

class _UsulanPenutupanEskalasiFormState
    extends State<UsulanPenutupanEskalasiForm> {
  String? _jenis;
  final _alasan = TextEditingController();
  final _pendukung = TextEditingController();
  final _errors = <String, String>{};
  bool _busy = false;

  @override
  void dispose() {
    _alasan.dispose();
    _pendukung.dispose();
    super.dispose();
  }

  Map<String, String> _validate() => {
    if (_jenis == null) 'jenis': 'Jenis usulan wajib dipilih.',
    if (_alasan.text.trim().isEmpty) 'alasan': 'Alasan usulan wajib diisi.',
    if (_pendukung.text.trim().isEmpty)
      'pendukung': 'Catatan pendukung wajib diisi.',
  };

  Future<void> _submit() async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(() => _errors
        ..clear()
        ..addAll(errors));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data usulan belum lengkap.')),
      );
      return;
    }
    setState(() {
      _errors.clear();
      _busy = true;
    });
    try {
      await widget.api.usulkanPenutupanAtauEskalasi(
        widget.kasus.id,
        jenisUsulan: _jenis!,
        alasan: _alasan.text.trim(),
        catatanPendukung: _pendukung.text.trim(),
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
        title: const Text('Usulan Berhasil Dikirim'),
        content: Text(
          'Usulan $_jenis untuk kasus ${widget.kasus.namaSiswa} telah diteruskan '
          'kepada pihak berwenang.\n\nStatus kasus tetap aktif hingga keputusan '
          'ditetapkan.',
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
      title: const Text('Penutupan / Eskalasi'),
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
              title: 'Formulir Usulan',
              icon: Icons.call_made,
              color: const Color(0xFFE67E22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Status kasus akan tetap aktif hingga keputusan ditetapkan '
                    'oleh pihak berwenang.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE67E22)),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Jenis Usulan *'),
                  DropdownButtonFormField<String>(
                    value: _jenis,
                    isExpanded: true,
                    decoration: kasusInputDecoration(
                      hint: 'Pilih jenis usulan...',
                      prefixIcon: const Icon(Icons.category_outlined),
                      errorText: _errors['jenis'],
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'PENUTUPAN',
                        child: Text('Usulan Penutupan Kasus'),
                      ),
                      DropdownMenuItem(
                        value: 'ESKALASI',
                        child: Text('Usulan Eskalasi Kasus'),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _jenis = v;
                      _errors.remove('jenis');
                    }),
                  ),
                  const SizedBox(height: 14),
                  const KasusFieldLabel('Alasan Usulan *'),
                  TextField(
                    controller: _alasan,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) =>
                        setState(() => _errors.remove('alasan')),
                    decoration: kasusInputDecoration(
                      hint: 'Tuliskan alasan pengajuan usulan...',
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
                      hint: 'Tuliskan informasi/bukti pendukung...',
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
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,
                  ))
              : const Icon(Icons.send_rounded),
          label: Text(_busy ? 'Mengirim...' : 'Kirim Usulan'),
        ),
      ),
    ),
  );
}
