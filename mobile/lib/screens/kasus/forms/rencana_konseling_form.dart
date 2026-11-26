import '../../../widgets/shared.dart';
import '../../../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../../../models/kasus_models.dart';
import '../../../network/kasus_api.dart';
import '../../../theme.dart';
import '../../../widgets/attendance_widgets.dart';
import 'kasus_form_widgets.dart';

/// Formulir tambah/ubah rencana konseling (Guru BK).
class RencanaKonselingForm extends StatefulWidget {
  const RencanaKonselingForm({
    super.key,
    required this.api,
    required this.kasus,
    required this.onDone,
  });

  final KasusApi api;
  final Kasus kasus;
  final VoidCallback onDone;

  @override
  State<RencanaKonselingForm> createState() => _RencanaKonselingFormState();
}

class _RencanaKonselingFormState extends State<RencanaKonselingForm> {
  final _tujuan = TextEditingController();
  final _bentuk = TextEditingController();
  final _tindakLanjut = TextEditingController();
  DateTime _jadwal = DateTime.now().add(const Duration(days: 1));
  final _errors = <String, String>{};
  bool _busy = false;
  bool _loadingExisting = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() {
      _loadingExisting = true;
      _loadError = null;
    });
    try {
      final existing = await widget.api.getRencanaKonseling(widget.kasus.id);
      if (existing != null && mounted) {
        setState(() {
          _tujuan.text = existing.tujuan;
          _bentuk.text = existing.bentukKegiatan;
          _jadwal = existing.jadwal;
          _tindakLanjut.text = existing.rencanaTindakLanjut;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    _tujuan.dispose();
    _bentuk.dispose();
    _tindakLanjut.dispose();
    super.dispose();
  }

  Map<String, String> _validate() => {
    if (_tujuan.text.trim().isEmpty) 'tujuan': 'Tujuan konseling wajib diisi.',
    if (_bentuk.text.trim().isEmpty) 'bentuk': 'Bentuk kegiatan wajib diisi.',
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
        const SnackBar(content: Text('Data rencana konseling belum lengkap.')),
      );
      return;
    }
    setState(() {
      _errors.clear();
      _busy = true;
    });
    try {
      await widget.api.simpanRencanaKonseling(
        widget.kasus.id,
        tujuan: _tujuan.text.trim(),
        bentukKegiatan: _bentuk.text.trim(),
        jadwal: _jadwal,
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
      title: const Text('Rencana Konseling Tersimpan'),
      content: Text(
        'Rencana konseling untuk ${widget.kasus.namaSiswa} berhasil disimpan.',
        textAlign: TextAlign.center,
      ),
    );
    if (confirmed && mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2, 1, 1);
    final lastDate = DateTime(now.year + 2, 12, 31);
    final safeInitial = _jadwal.isBefore(firstDate)
        ? now
        : _jadwal.isAfter(lastDate)
        ? lastDate
        : _jadwal;

    final date = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Pilih Jadwal Konseling',
    );
    if (date != null && mounted) {
      setState(
        () => _jadwal = DateTime(
          date.year,
          date.month,
          date.day,
          _jadwal.hour,
          _jadwal.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: navy,
      title: const Text('Rencana Konseling'),
    ),
    body: _loadingExisting
        ? const SchoolLoading()
        : _loadError != null
        ? LoadErrorView(message: '$_loadError', onRetry: _loadExisting)
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  HeroHeader(
                    icon: Icons.event_note_outlined,
                    title: widget.kasus.namaSiswa,
                    subtitle:
                        '${widget.kasus.kelas} • ${widget.kasus.kategori}',
                  ),
                  SectionCard(
                    title: 'Formulir Rencana Konseling',
                    icon: Icons.event_note_outlined,
                    color: sectionPurple,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const KasusFieldLabel('Tujuan Konseling *'),
                        TextField(
                          controller: _tujuan,
                          minLines: 2,
                          maxLines: 4,
                          onChanged: (_) =>
                              setState(() => _errors.remove('tujuan')),
                          decoration: kasusInputDecoration(
                            hint: 'Tuliskan tujuan konseling siswa...',
                            errorText: _errors['tujuan'],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const KasusFieldLabel('Bentuk Kegiatan *'),
                        TextField(
                          controller: _bentuk,
                          minLines: 2,
                          maxLines: 3,
                          onChanged: (_) =>
                              setState(() => _errors.remove('bentuk')),
                          decoration: kasusInputDecoration(
                            hint: 'Misal: Konseling Individu, Mediasi, dll.',
                            errorText: _errors['bentuk'],
                          ),
                        ),
                        const SizedBox(height: 14),
                        KasusDatePickerField(
                          label: 'Jadwal Konseling *',
                          valueText: formatDateId(_jadwal),
                          onTap: _pickDate,
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
                            hint:
                                'Tuliskan langkah tindak lanjut berikutnya...',
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
    bottomNavigationBar: _loadingExisting || _loadError != null
        ? null
        : SafeArea(
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
                label: Text(_busy ? 'Menyimpan...' : 'Simpan Rencana'),
              ),
            ),
          ),
  );
}
