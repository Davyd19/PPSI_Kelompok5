import '../../../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../../../models/kasus_models.dart';
import '../../../network/kasus_api.dart';
import '../../../theme.dart';
import '../../../widgets/attendance_widgets.dart';
import 'kasus_form_widgets.dart';

/// Halaman pemantauan perkembangan kasus (Guru BK & Wali Kelas).
class PemantauanForm extends StatefulWidget {
  const PemantauanForm({
    super.key,
    required this.api,
    required this.kasus,
    required this.role,
    required this.onDone,
  });

  final KasusApi api;
  final Kasus kasus;
  final String role;
  final VoidCallback onDone;

  @override
  State<PemantauanForm> createState() => _PemantauanFormState();
}

class _PemantauanFormState extends State<PemantauanForm> {
  bool _showForm = false;
  final _catatan = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _tidakPerlu() async {
    setState(() => _busy = true);
    try {
      await widget.api.tidakPerluTindakLanjut(widget.kasus.id);
      if (!mounted) return;
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Keputusan dicatat: tidak perlu tindak lanjut tambahan.',
          ),
          backgroundColor: Color(0xFF1E7D4F),
        ),
      );
      Navigator.pop(context);
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

  Future<void> _simpanTindakLanjut() async {
    if (_catatan.text.trim().isEmpty) {
      setState(() => _error = 'Catatan tindak lanjut wajib diisi.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await widget.api.simpanTindakLanjutTambahan(
        widget.kasus.id,
        catatan: _catatan.text.trim(),
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
      title: const Text('Tindak Lanjut Tersimpan'),
      content: Text(
        'Catatan tindak lanjut tambahan untuk ${widget.kasus.namaSiswa} '
        'berhasil disimpan.',
        textAlign: TextAlign.center,
      ),
    );
    if (confirmed && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kasus;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: const Text('Pemantauan Perkembangan'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              HeroHeader(
                icon: Icons.trending_up,
                title: k.namaSiswa,
                subtitle: '${k.kelas} • ${k.kategori}',
              ),

              // Ringkasan perkembangan
              SectionCard(
                title: 'Ringkasan Perkembangan',
                icon: Icons.analytics_outlined,
                color: sectionGreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryRow('Status saat ini', k.status.label),
                    _summaryRow(
                      'Jumlah riwayat',
                      '${k.riwayat.length} catatan',
                    ),
                    _summaryRow(
                      'Riwayat terakhir',
                      k.riwayat.isNotEmpty
                          ? '${k.riwayat.last.jenis} - ${formatDateId(k.riwayat.last.tanggal)}'
                          : 'Belum ada',
                    ),
                    const Divider(height: 20),
                    if (k.riwayat.isNotEmpty) ...[
                      const Text(
                        'Riwayat Tindak Lanjut:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: navy,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final r in k.riwayat.reversed.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 8,
                                color: sectionGreen,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${r.jenis} • ${formatDateId(r.tanggal)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: navy,
                                      ),
                                    ),
                                    Text(
                                      r.deskripsi,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              // Keputusan
              SectionCard(
                title: 'Keputusan Pemantauan',
                icon: Icons.gavel_outlined,
                color: sectionPurple,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sectionGreen,
                        side: const BorderSide(color: Color(0xFF1E7D4F)),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 14,
                        ),
                      ),
                      onPressed: _busy ? null : _tidakPerlu,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        'Tidak Diperlukan Tindak Lanjut Tambahan',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sectionOrange,
                        side: const BorderSide(color: Color(0xFFB26A00)),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 14,
                        ),
                      ),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _showForm = true),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Diperlukan Tindak Lanjut Tambahan'),
                    ),
                    if (_showForm) ...[
                      const SizedBox(height: 14),
                      const KasusFieldLabel('Catatan Tindak Lanjut Tambahan *'),
                      TextField(
                        controller: _catatan,
                        minLines: 3,
                        maxLines: 6,
                        onChanged: (_) => setState(() => _error = null),
                        decoration: kasusInputDecoration(
                          hint: 'Tuliskan rencana tindak lanjut tambahan...',
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _simpanTindakLanjut,
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
                        label: Text(
                          _busy ? 'Menyimpan...' : 'Simpan Tindak Lanjut',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: navy,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
