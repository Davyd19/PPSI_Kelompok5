import '../../widgets/school_ui.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../network/auth_api.dart';
import '../../network/violation_report_api.dart';
import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';

const _red = Color(0xFFC62828);

/// Use case Guru: "Menginput Laporan Pelanggaran".
/// Pilih siswa -> isi waktu, tempat, jenis, deskripsi, bukti (opsional) ->
/// kirim -> validasi kelengkapan -> notifikasi berhasil (menunggu verifikasi).
class ViolationReportScreen extends StatefulWidget {
  const ViolationReportScreen({super.key, required this.api, this.onOpenMine});
  final ViolationReportApi api;
  final VoidCallback? onOpenMine;

  @override
  State<ViolationReportScreen> createState() => _ViolationReportScreenState();
}

class _ViolationReportScreenState extends State<ViolationReportScreen> {
  static const _places = [
    'Ruang kelas',
    'Kantin',
    'Lapangan',
    'Toilet',
    'Musala',
    'Gerbang sekolah',
  ];

  ViolationForm? _form;
  Object? _loadError;
  ReportableStudent? _student;
  ViolationCategory? _category;
  DateTime _time = DateTime.now();
  final _place = TextEditingController();
  final _description = TextEditingController();
  final _evidence = <({String name, Uint8List bytes})>[];
  Map<String, String> _errors = {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    _place.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() => _loadError = null);
    try {
      final form = await widget.api.form();
      if (mounted) setState(() => _form = form);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _toast(Object m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$m')));

  // ---------- input ----------

  Future<void> _pickStudent() async {
    final picked = await showModalBottomSheet<ReportableStudent>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _StudentPicker(api: widget.api, classes: _form!.classes),
    );
    if (picked != null) {
      setState(() {
        _student = picked;
        _errors.remove('id_siswa');
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _time,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      helpText: 'Tanggal kejadian',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
      helpText: 'Jam kejadian',
    );
    if (time == null) return;
    setState(() {
      _time = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _errors.remove('waktu_kejadian');
    });
  }

  Future<void> _addEvidence(ImageSource source) async {
    final max = _form?.maxAttachments ?? 3;
    if (_evidence.length >= max) {
      _toast('Maksimal $max bukti.');
      return;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _toast('Ukuran foto maksimal 5 MB.');
        return;
      }
      setState(() => _evidence.add((name: file.name, bytes: bytes)));
    } catch (e) {
      _toast('Tidak dapat mengambil foto: $e');
    }
  }

  // ---------- kirim ----------

  /// Validasi kelengkapan di perangkat (server tetap memvalidasi ulang).
  Map<String, String> _validate() => {
    if (_student == null) 'id_siswa': 'Pilih siswa yang dilaporkan.',
    if (_time.isAfter(DateTime.now().add(const Duration(minutes: 1))))
      'waktu_kejadian': 'Waktu kejadian tidak boleh di masa depan.',
    if (_place.text.trim().length < 3)
      'tempat_kejadian': 'Isi tempat kejadian.',
    if (_category == null)
      'id_kategori_pelanggaran': 'Pilih jenis pelanggaran.',
    if (_description.text.trim().length < 10)
      'uraian': 'Isi deskripsi minimal 10 karakter.',
  };

  Future<void> _submit() async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      _toast('Data laporan belum lengkap.');
      return;
    }
    setState(() {
      _errors = {};
      _sending = true;
    });
    try {
      final id = await widget.api.submit(
        studentId: _student!.id,
        categoryId: _category!.id,
        occurredAt: _time,
        place: _place.text,
        description: _description.text,
      );
      var failedUploads = 0;
      for (final e in _evidence) {
        try {
          await widget.api.uploadEvidence(id, bytes: e.bytes, filename: e.name);
        } catch (_) {
          failedUploads++;
        }
      }
      if (!mounted) return;
      await _showSuccess(failedUploads);
    } on AuthError catch (e) {
      if (!mounted) return;
      // Tidak lengkap -> kembali ke formulir dengan pesan per kolom.
      final details = e.details;
      if (details != null) {
        setState(
          () => _errors = details.map((k, v) => MapEntry(k, v.toString())),
        );
      }
      _toast(e.message);
    } catch (e) {
      if (mounted) _toast(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showSuccess(int failedUploads) async {
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SchoolDialog(
        icon: const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFE6F4EC),
          child: Icon(Icons.check_rounded, color: sectionGreen, size: 34),
        ),
        title: const Text('Laporan berhasil dikirim'),
        content: Text(
          'Laporan untuk ${_student!.name} menunggu verifikasi Kesiswaan.'
          '${failedUploads > 0 ? '\n\n$failedUploads bukti gagal diunggah.' : ''}',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'new'),
            child: const Text('Lapor lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'done'),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'new') {
      setState(() {
        _student = null;
        _category = null;
        _time = DateTime.now();
        _place.clear();
        _description.clear();
        _evidence.clear();
      });
    } else {
      Navigator.of(context).pop(true);
    }
  }

  // ---------- tampilan ----------

  @override
  Widget build(BuildContext context) {
    final form = _form;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: const Text('Lapor Pelanggaran'),
        actions: [
          if (widget.onOpenMine != null)
            TextButton.icon(
              onPressed: widget.onOpenMine,
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Laporan Saya'),
            ),
        ],
      ),
      body: form == null
          ? Center(
              child: _loadError == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_loadError', textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _loadForm,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    _studentSection(),
                    _incidentSection(form),
                    _evidenceSection(form),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: form == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _red),
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'Mengirim...' : 'Kirim Laporan'),
                ),
              ),
            ),
    );
  }

  Widget _errorText(String key) => _errors[key] == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _errors[key]!,
            style: const TextStyle(color: _red, fontSize: 12),
          ),
        );

  Widget _studentSection() {
    final s = _student;
    return SectionCard(
      title: 'Siswa yang Dilaporkan',
      icon: Icons.person_search_outlined,
      color: sectionBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s == null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _errors.containsKey('id_siswa')
                      ? _red
                      : const Color(0xFFDCE6F3),
                ),
              ),
              onPressed: _pickStudent,
              icon: const Icon(Icons.search),
              label: const Text('Pilih siswa'),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: sectionBlue,
                foregroundColor: Colors.white,
                child: Text(s.name.characters.first.toUpperCase()),
              ),
              title: Text(
                s.name,
                style: const TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text('${s.classroom} • NIS ${s.nis ?? '-'}'),
              trailing: TextButton(
                onPressed: _pickStudent,
                child: const Text('Ganti'),
              ),
            ),
          _errorText('id_siswa'),
        ],
      ),
    );
  }

  Widget _incidentSection(ViolationForm form) => SectionCard(
    title: 'Informasi Kejadian',
    icon: Icons.report_outlined,
    color: sectionOrange,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _pickDateTime,
          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
          icon: const Icon(Icons.event),
          label: Text('${formatDateId(_time)} • ${formatHhmm(_time)} WIB'),
        ),
        _errorText('waktu_kejadian'),
        const SizedBox(height: 12),
        TextField(
          controller: _place,
          maxLength: 191,
          onChanged: (_) => setState(() => _errors.remove('tempat_kejadian')),
          decoration: InputDecoration(
            labelText: 'Tempat kejadian',
            prefixIcon: const Icon(Icons.place_outlined),
            counterText: '',
            errorText: _errors['tempat_kejadian'],
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in _places)
              ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(p, style: const TextStyle(fontSize: 11)),
                onPressed: () => setState(() {
                  _place.text = p;
                  _errors.remove('tempat_kejadian');
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ViolationCategory>(
          initialValue: _category,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Jenis pelanggaran',
            prefixIcon: const Icon(Icons.category_outlined),
            errorText: _errors['id_kategori_pelanggaran'],
          ),
          items: [
            for (final c in form.categories)
              DropdownMenuItem(value: c, child: Text(c.name)),
          ],
          onChanged: (c) => setState(() {
            _category = c;
            _errors.remove('id_kategori_pelanggaran');
          }),
        ),
        if (form.categories.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Belum ada jenis pelanggaran aktif. Hubungi Kesiswaan.',
              style: TextStyle(color: _red, fontSize: 12),
            ),
          ),
        if (_category?.description case final d? when d.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(d, style: const TextStyle(fontSize: 11)),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 3,
          maxLines: 6,
          maxLength: 5000,
          onChanged: (_) => setState(() => _errors.remove('uraian')),
          decoration: InputDecoration(
            labelText: 'Deskripsi kejadian',
            alignLabelWithHint: true,
            errorText: _errors['uraian'],
          ),
        ),
      ],
    ),
  );

  Widget _evidenceSection(ViolationForm form) => SectionCard(
    title: 'Bukti Pendukung (opsional)',
    icon: Icons.photo_library_outlined,
    color: sectionPurple,
    trailing: ColorPill(
      '${_evidence.length}/${form.maxAttachments}',
      color: sectionPurple,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_evidence.isNotEmpty)
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _evidence.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _evidence[i].bytes,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: InkWell(
                      onTap: () => setState(() => _evidence.removeAt(i)),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_evidence.isNotEmpty) const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addEvidence(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Kamera'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addEvidence(ImageSource.gallery),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Galeri'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Lembar pemilihan siswa: cari nama/NIS + filter kelas.
class _StudentPicker extends StatefulWidget {
  const _StudentPicker({required this.api, required this.classes});
  final ViolationReportApi api;
  final List<({int id, String name})> classes;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  final _query = TextEditingController();
  int? _classId;
  Timer? _debounce;
  List<ReportableStudent>? _rows;
  Object? _error;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    setState(() => _error = null);
    try {
      final rows = await widget.api.students(
        query: _query.text,
        classId: _classId,
      );
      if (mounted && ticket == _ticket) setState(() => _rows = rows);
    } catch (e) {
      if (mounted && ticket == _ticket) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .8,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pilih Siswa', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          TextField(
            controller: _query,
            autofocus: true,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _load);
            },
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search),
              hintText: 'Cari nama atau NIS',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _classId,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.groups_outlined),
            ),
            items: [
              const DropdownMenuItem<int?>(child: Text('Semua kelas')),
              for (final c in widget.classes)
                DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) {
              _classId = v;
              _load();
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _rows == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : Text('$_error'),
                  )
                : _rows!.isEmpty
                ? const Center(child: Text('Siswa tidak ditemukan.'))
                : ListView.separated(
                    itemCount: _rows!.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _rows![i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: attendanceSoft,
                          foregroundColor: sectionBlue,
                          child: Text(s.name.characters.first.toUpperCase()),
                        ),
                        title: Text(s.name),
                        subtitle: Text('${s.classroom} • NIS ${s.nis ?? '-'}'),
                        onTap: () => Navigator.pop(context, s),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
