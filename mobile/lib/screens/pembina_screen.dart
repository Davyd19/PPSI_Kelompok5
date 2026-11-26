import '../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../network/auth_api.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import 'ekskul_qr.dart';

String _s(dynamic v) => v?.toString() ?? '';
List<Map<String, dynamic>> _list(dynamic v) => List<Map<String, dynamic>>.from(
  (v as List).map((e) => Map<String, dynamic>.from(e as Map)),
);
String _today() => DateTime.now().toIso8601String().substring(0, 10);
String _hm(dynamic v) => _s(v).length >= 5 ? _s(v).substring(0, 5) : _s(v);

/// Menjalankan aksi ke API dan menampilkan pesan hasilnya; mengembalikan true bila berhasil.
Future<bool> _act(
  BuildContext context,
  Future<dynamic> Function() run, {
  String? ok,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await run();
    if (ok != null) messenger.showSnackBar(SnackBar(content: Text(ok)));
    return true;
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    return false;
  }
}

/// Memuat data async dengan state loading/error dan tombol coba lagi.
class _Async extends StatefulWidget {
  const _Async({required this.load, required this.builder});
  final Future<dynamic> Function() load;
  final Widget Function(
    BuildContext context,
    dynamic data,
    Future<void> Function() reload,
  )
  builder;
  @override
  State<_Async> createState() => _AsyncState();
}

class _AsyncState extends State<_Async> {
  late Future<dynamic> _future = widget.load();

  Future<void> _reload() async {
    final next = widget.load();
    if (!mounted) return;
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SchoolLoading();
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(snapshot.error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _reload,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        );
      }
      return widget.builder(context, snapshot.data, _reload);
    },
  );
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SchoolDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    ) ??
    false;

class _FormDialog extends StatefulWidget {
  const _FormDialog({
    required this.title,
    required this.labels,
    this.initial = const [],
    this.optional = const {},
    this.action = 'Simpan',
    this.onSave,
    this.fullPage = false,
  });
  final String title, action;
  final List<String> labels, initial;
  final Set<int> optional;
  final Future<void> Function(List<String>)? onSave;
  final bool fullPage;
  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  late final _controllers = [
    for (var i = 0; i < widget.labels.length; i++)
      TextEditingController(
        text: i < widget.initial.length ? widget.initial[i] : '',
      ),
  ];
  bool _busy = false;
  String? _error;
  bool get _dirty => List.generate(
    _controllers.length,
    (i) =>
        _controllers[i].text !=
        (i < widget.initial.length ? widget.initial[i] : ''),
  ).any((v) => v);
  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_dirty &&
        !await _confirm(
          context,
          'Buang perubahan?',
          'Isian belum disimpan. Buang perubahan dan kembali?',
        )) {
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_busy) return;
    final values = _controllers.map((c) => c.text.trim()).toList();
    for (var i = 0; i < values.length; i++) {
      if (values[i].isEmpty && !widget.optional.contains(i)) {
        setState(() => _error = '${widget.labels[i]} wajib diisi.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave?.call(values);
      if (mounted) Navigator.pop(context, values);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _controllers[i],
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: widget.labels[i]),
            ),
          ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: danger)),
      ],
    );
    final actions = [
      TextButton(onPressed: _busy ? null : _close, child: const Text('Batal')),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Menyimpan…' : widget.action),
      ),
    ];
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: widget.fullPage
          ? Scaffold(
              appBar: AppBar(
                title: Text(widget.title),
                leading: IconButton(
                  onPressed: _close,
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SchoolCard(child: fields),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: actions,
                    ),
                  ],
                ),
              ),
            )
          : SchoolDialog(
              title: Text(widget.title),
              content: SingleChildScrollView(child: fields),
              actions: actions,
            ),
    );
  }
}

Future<List<String>?> _form(
  BuildContext context,
  String title,
  List<String> labels, {
  List<String> initial = const [],
  Set<int> optional = const {},
  String action = 'Simpan',
  Future<void> Function(List<String>)? onSave,
}) {
  final form = _FormDialog(
    title: title,
    labels: labels,
    initial: initial,
    optional: optional,
    action: action,
    onSave: onSave,
    fullPage: labels.length > 3,
  );
  return labels.length > 3
      ? Navigator.of(
          context,
        ).push<List<String>>(MaterialPageRoute(builder: (_) => form))
      : showDialog<List<String>>(
          context: context,
          barrierDismissible: false,
          builder: (_) => form,
        );
}

class PembinaHome extends StatelessWidget {
  const PembinaHome({super.key, required this.api, required this.name});
  final AuthApi api;
  final String name;

  @override
  Widget build(BuildContext context) => _Async(
    load: () => api.pembinaGet('/kegiatan'),
    builder: (context, raw, reload) {
      final data = Map<String, dynamic>.from(raw as Map);
      final activities = _list(data['activities']);
      final today = _list(data['sessions_today']);
      final members = activities.fold<int>(
        0,
        (a, e) => a + (int.tryParse(_s(e['anggota_aktif'])) ?? 0),
      );
      Future<void> open(Map<String, dynamic> activity) async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PembinaActivityScreen(api: api, activity: activity),
          ),
        );
        await reload();
      }

      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SchoolGreeting(
              name: name,
              first: (
                icon: Icons.groups_outlined,
                value: '${activities.length} ekskul',
                label: 'Kegiatan dibina',
              ),
              second: (
                icon: Icons.event_available_outlined,
                value: '${today.length} sesi',
                label: 'Hari ini',
              ),
            ),
            const SizedBox(height: 16),
            AppPanel(
              child: Row(
                children: [
                  Expanded(
                    child: _Count('${activities.length}', 'Ekskul Dibina'),
                  ),
                  Expanded(child: _Count('$members', 'Anggota Aktif')),
                  Expanded(child: _Count('${today.length}', 'Sesi Hari Ini')),
                ],
              ),
            ),
            if (today.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Pertemuan Hari Ini',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final m in today)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AppPanel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_s(m['ekskul'])),
                      subtitle: Text(
                        '${_hm(m['jam_mulai'])}–${_hm(m['jam_selesai'])} • ${_s(m['lokasi'])}\nPresensi: ${_s(m['status_presensi'])}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        final a = activities.where(
                          (e) => e['id'] == m['id_periode_ekstrakurikuler'],
                        );
                        if (a.isNotEmpty) open(a.first);
                      },
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              'Kegiatan yang Dibina',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (activities.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Belum ada penugasan pembina yang aktif.'),
              ),
            for (final a in activities)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AppPanel(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.groups_outlined,
                      color: Color(0xFF226A75),
                    ),
                    title: Text(_s(a['nama'])),
                    subtitle: Text(
                      '${_s(a['anggota_aktif'])} anggota'
                      '${a['kapasitas'] == null ? '' : ' / ${_s(a['kapasitas'])}'}'
                      ' • ${_s(a['tahun_ajaran'])}',
                    ),
                    trailing:
                        (int.tryParse(_s(a['pendaftar_menunggu'])) ?? 0) > 0
                        ? Badge(label: Text(_s(a['pendaftar_menunggu'])))
                        : const Icon(Icons.chevron_right),
                    onTap: () => open(a),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _Count extends StatelessWidget {
  const _Count(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10),
      ),
    ],
  );
}

class PembinaActivityScreen extends StatelessWidget {
  const PembinaActivityScreen({
    super.key,
    required this.api,
    required this.activity,
  });
  final AuthApi api;
  final Map<String, dynamic> activity;

  @override
  Widget build(BuildContext context) {
    final id = _s(activity['id']);
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_s(activity['nama'])),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Pertemuan'),
              Tab(text: 'Pendaftaran'),
              Tab(text: 'Anggota'),
              Tab(text: 'Rekap'),
              Tab(text: 'Prestasi'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Meetings(api: api, periodId: id),
            _Registrations(api: api, periodId: id),
            _Members(api: api, periodId: id),
            _Recap(api: api, periodId: id),
            _Achievements(api: api, periodId: id),
          ],
        ),
      ),
    );
  }
}

// ---- Pertemuan, sesi, dan presensi ----
class _Meetings extends StatelessWidget {
  const _Meetings({required this.api, required this.periodId});
  final AuthApi api;
  final String periodId;

  @override
  Widget build(BuildContext context) => _Async(
    load: () => api.pembinaGet('/kegiatan/$periodId/pertemuan'),
    builder: (context, raw, reload) {
      final rows = _list(raw);
      Future<void> run(Future<dynamic> Function() call, String ok) async {
        if (!await _confirm(
          context,
          'Konfirmasi sesi presensi',
          ok.startsWith('Sesi ditutup')
              ? 'Tutup sesi? Data yang belum dicatat tetap Belum Diisi.'
              : 'Buka sesi untuk pencatatan presensi manual?',
        )) {
          return;
        }
        if (!context.mounted) return;
        if (await _act(context, call, ok: ok)) await reload();
      }

      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Pertemuan'),
          onPressed: () async {
            final saved = await _form(
              context,
              'Tambah pertemuan',
              [
                'Tanggal (YYYY-MM-DD)',
                'Jam mulai (HH:MM)',
                'Jam selesai (HH:MM)',
                'Lokasi',
                'Agenda (opsional)',
              ],
              initial: [_today(), '15:00', '16:30', '', ''],
              optional: {4},
              onSave: (v) async {
                await api.pembinaSend(
                  '/kegiatan/$periodId/pertemuan',
                  body: {
                    'tanggal': v[0],
                    'jam_mulai': v[1],
                    'jam_selesai': v[2],
                    'lokasi': v[3],
                    if (v[4].isNotEmpty) 'agenda': v[4],
                  },
                );
              },
            );
            if (saved != null) await reload();
          },
        ),
        body: RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              if (rows.isEmpty) const Text('Belum ada pertemuan.'),
              for (final m in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_s(m['tanggal'])} • ${_hm(m['jam_mulai'])}–${_hm(m['jam_selesai'])}',
                          style: const TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_s(m['lokasi'])}${m['agenda'] == null ? '' : ' • ${_s(m['agenda'])}'}',
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            Chip(label: Text(_s(m['status_pertemuan']))),
                            Chip(
                              label: Text(
                                'Presensi: ${_s(m['status_presensi'])}',
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (m['status_pertemuan'] == 'TERJADWAL' &&
                                m['status_presensi'] == 'BELUM_DIBUKA') ...[
                              FilledButton(
                                onPressed: () => run(
                                  () => api.pembinaSend(
                                    '/pertemuan/${m['id']}/buka',
                                  ),
                                  'Sesi presensi dibuka.',
                                ),
                                child: const Text('Buka Sesi'),
                              ),
                              OutlinedButton(
                                onPressed: () async {
                                  final saved = await _form(
                                    context,
                                    'Batalkan pertemuan',
                                    ['Alasan pembatalan'],
                                    action: 'Batalkan',
                                    onSave: (v) async {
                                      await api.pembinaSend(
                                        '/pertemuan/${m['id']}/batal',
                                        body: {'alasan_batal': v[0]},
                                      );
                                    },
                                  );
                                  if (saved != null) await reload();
                                },
                                child: const Text('Batalkan'),
                              ),
                            ],
                            if (m['status_presensi'] == 'DIBUKA') ...[
                              FilledButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PembinaQrScreen(
                                      api: api,
                                      meetingId: _s(m['id']),
                                      title:
                                          '${_s(m['agenda']).isEmpty ? 'Pertemuan' : _s(m['agenda'])} · ${_hm(m['jam_mulai'])}',
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.qr_code_2_rounded),
                                label: const Text('Tampilkan QR'),
                              ),
                              OutlinedButton(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => _AttendanceScreen(
                                        api: api,
                                        meetingId: _s(m['id']),
                                      ),
                                    ),
                                  );
                                  await reload();
                                },
                                child: const Text('Isi Presensi'),
                              ),
                              OutlinedButton(
                                onPressed: () => run(
                                  () => api.pembinaSend(
                                    '/pertemuan/${m['id']}/tutup',
                                  ),
                                  'Sesi ditutup. Presensi yang belum dicatat tetap Belum Diisi.',
                                ),
                                child: const Text('Tutup Sesi'),
                              ),
                            ],
                            if (m['status_presensi'] == 'DITUTUP')
                              OutlinedButton(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => _AttendanceScreen(
                                        api: api,
                                        meetingId: _s(m['id']),
                                      ),
                                    ),
                                  );
                                  await reload();
                                },
                                child: const Text('Koreksi Presensi'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _AttendanceScreen extends StatefulWidget {
  const _AttendanceScreen({required this.api, required this.meetingId});
  final AuthApi api;
  final String meetingId;
  @override
  State<_AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<_AttendanceScreen> {
  static const statuses = ['HADIR', 'IZIN', 'SAKIT', 'ALFA'];
  static const _statusColor = {
    'HADIR': cGreen,
    'IZIN': cAmber,
    'SAKIT': cHeather,
    'ALFA': cBrick,
  };
  final _changes = <String, String>{};
  bool _saving = false;
  String _reason = '';

  Future<void> _save() async {
    if (_changes.isEmpty || _saving) return;
    final reason = await _form(
      context,
      'Simpan presensi',
      ['Keterangan / alasan koreksi'],
      initial: [_reason],
      action: 'Simpan',
    );
    if (reason == null || !mounted) return;
    _reason = reason.first;
    setState(() => _saving = true);
    final ok = await _act(
      context,
      () => widget.api.pembinaSend(
        '/pertemuan/${widget.meetingId}/presensi',
        method: 'PUT',
        body: {
          'presensi': [
            for (final e in _changes.entries)
              {
                'id_keanggotaan': int.parse(e.key),
                'status_kehadiran': e.value,
                'keterangan': _reason,
              },
          ],
        },
      ),
      ok: 'Presensi disimpan.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Presensi Anggota')),
    body: _Async(
      load: () =>
          widget.api.pembinaGet('/pertemuan/${widget.meetingId}/presensi'),
      builder: (context, raw, reload) {
        final members = _list((raw as Map)['anggota']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Anggota yang memindai QR otomatis tercatat Hadir. Isi manual untuk yang izin, sakit, atau tidak bisa memindai. Yang belum tercatat saat sesi ditutup otomatis Alfa.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _s(m['nama']),
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final s in statuses)
                            ChoiceChip(
                              label: Text(s),
                              // Warna tiap status berbeda agar pilihan mudah dibaca sekilas.
                              selectedColor: _statusColor[s]!.$2,
                              checkmarkColor: _statusColor[s]!.$1,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    (_changes[_s(m['id_keanggotaan'])] ??
                                            m['status_kehadiran']) ==
                                        s
                                    ? _statusColor[s]!.$1
                                    : navy,
                              ),
                              selected:
                                  (_changes[_s(m['id_keanggotaan'])] ??
                                      m['status_kehadiran']) ==
                                  s,
                              onSelected: (_) => setState(
                                () => _changes[_s(m['id_keanggotaan'])] = s,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _changes.isEmpty || _saving ? null : _save,
              child: Text(
                _saving
                    ? 'Menyimpan…'
                    : 'Simpan Presensi (${_changes.length})',
              ),
            ),
          ],
        );
      },
    ),
  );
}

// ---- Pendaftaran & keanggotaan ----
class _Registrations extends StatelessWidget {
  const _Registrations({required this.api, required this.periodId});
  final AuthApi api;
  final String periodId;
  @override
  Widget build(BuildContext context) => _Async(
    load: () => api.pembinaGet('/kegiatan/$periodId/pendaftaran'),
    builder: (context, raw, reload) {
      final rows = _list(raw);
      Future<void> decide(Map<String, dynamic> r, String decision) async {
        if (decision == 'TOLAK') {
          final saved = await _form(
            context,
            'Tolak pendaftaran',
            ['Alasan'],
            action: 'Tolak',
            onSave: (v) async {
              await api.pembinaSend(
                '/pendaftaran/${r['id']}/keputusan',
                body: {'keputusan': decision, 'alasan': v[0]},
              );
            },
          );
          if (saved != null) await reload();
          return;
        }
        if (!await _confirm(
          context,
          'Terima pendaftaran?',
          'Siswa akan menjadi anggota kegiatan ini.',
        )) {
          return;
        }
        if (!context.mounted) return;
        if (await _act(
          context,
          () => api.pembinaSend(
            '/pendaftaran/${r['id']}/keputusan',
            body: {'keputusan': decision},
          ),
          ok: 'Pendaftar diterima.',
        )) {
          await reload();
        }
      }

      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (rows.isEmpty) const Text('Belum ada pendaftar.'),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _s(r['siswa']),
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'NISN ${_s(r['nisn'])} • ${_s(r['status_keputusan'])}',
                      ),
                      if (r['status_keputusan'] == 'MENUNGGU')
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () => decide(r, 'TERIMA'),
                              child: const Text('Terima'),
                            ),
                            OutlinedButton(
                              onPressed: () => decide(r, 'TOLAK'),
                              child: const Text('Tolak'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _Members extends StatelessWidget {
  const _Members({required this.api, required this.periodId});
  final AuthApi api;
  final String periodId;
  @override
  Widget build(BuildContext context) => _Async(
    load: () => api.pembinaGet('/kegiatan/$periodId/anggota'),
    builder: (context, raw, reload) {
      final rows = _list(raw);
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (rows.isEmpty) const Text('Belum ada anggota.'),
            for (final m in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppPanel(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_s(m['nama'])),
                    subtitle: Text(
                      m['aktif'] == true
                          ? 'Aktif sejak ${_s(m['tanggal_mulai'])}'
                          : 'Berakhir ${_s(m['tanggal_selesai'])} • ${_s(m['alasan_berakhir'])}',
                    ),
                    trailing: m['aktif'] == true
                        ? TextButton(
                            onPressed: () async {
                              final saved = await _form(
                                context,
                                'Akhiri keanggotaan',
                                ['Alasan'],
                                action: 'Akhiri',
                                onSave: (v) async {
                                  await api.pembinaSend(
                                    '/anggota/${m['id']}/akhiri',
                                    body: {'alasan': v[0]},
                                  );
                                },
                              );
                              if (saved != null) await reload();
                            },
                            child: const Text('Akhiri'),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

// ---- Rekap kehadiran ----
class _Recap extends StatelessWidget {
  const _Recap({required this.api, required this.periodId});
  final AuthApi api;
  final String periodId;
  @override
  Widget build(BuildContext context) => _Async(
    load: () => api.pembinaGet('/kegiatan/$periodId/rekap'),
    builder: (context, raw, reload) {
      final data = Map<String, dynamic>.from(raw as Map);
      final rows = _list(data['anggota']);
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${_s(data['total_pertemuan'])} pertemuan selesai',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _s(r['nama']),
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Hadir ${_s(r['hadir'])} • Izin ${_s(r['izin'])} • Sakit ${_s(r['sakit'])} • Alfa ${_s(r['alfa'])}',
                      ),
                      Text(
                        r['persen_hadir'] == null
                            ? 'Belum ada presensi'
                            : 'Kehadiran ${_s(r['persen_hadir'])}%',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

// ---- Prestasi ----
class _Achievements extends StatelessWidget {
  const _Achievements({required this.api, required this.periodId});
  final AuthApi api;
  final String periodId;
  static const levels = [
    'SEKOLAH',
    'KECAMATAN',
    'KOTA',
    'PROVINSI',
    'NASIONAL',
    'INTERNASIONAL',
  ];

  @override
  Widget build(BuildContext context) => _Async(
    load: () => api.pembinaGet('/kegiatan/$periodId/prestasi'),
    builder: (context, raw, reload) {
      final rows = _list(raw);
      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.emoji_events_outlined),
          label: const Text('Catat Prestasi'),
          onPressed: () async {
            final done = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _AchievementForm(api: api, periodId: periodId),
            );
            if (done == true) await reload();
          },
        ),
        body: RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              if (rows.isEmpty) const Text('Belum ada prestasi tercatat.'),
              for (final a in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _s(a['judul']),
                          style: const TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_s(a['tingkat_prestasi'])} • ${_s(a['hasil_prestasi'])} • ${_s(a['tanggal'])}',
                        ),
                        Text(
                          ((a['peserta_id_portofolio'] as List?) ?? [])
                              .map((p) => _s((p as Map)['siswa']?['nama']))
                              .join(', '),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _AchievementForm extends StatefulWidget {
  const _AchievementForm({required this.api, required this.periodId});
  final AuthApi api;
  final String periodId;
  @override
  State<_AchievementForm> createState() => _AchievementFormState();
}

class _AchievementFormState extends State<_AchievementForm> {
  final _title = TextEditingController();
  final _result = TextEditingController();
  final _team = TextEditingController();
  final _date = TextEditingController(text: _today());
  final _search = TextEditingController();
  String _level = 'SEKOLAH';
  final _picked = <int, String>{};
  List<Map<String, dynamic>> _found = [];
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _result, _team, _date, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _lookup() async {
    try {
      final rows = _list(
        await widget.api.pembinaGet(
          '/siswa?q=${Uri.encodeQueryComponent(_search.text.trim())}',
        ),
      );
      if (mounted) setState(() => _found = rows);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await _act(
      context,
      () => widget.api.pembinaSend(
        '/kegiatan/${widget.periodId}/prestasi',
        body: {
          'judul': _title.text.trim(),
          'tanggal': _date.text.trim(),
          'tingkat_prestasi': _level,
          'hasil_prestasi': _result.text.trim(),
          if (_team.text.trim().isNotEmpty) 'nama_tim': _team.text.trim(),
          'peserta': _picked.keys.toList(),
        },
      ),
      ok: 'Prestasi dicatat.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Catat Prestasi', style: Theme.of(context).textTheme.titleLarge),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Judul lomba / prestasi',
            ),
          ),
          TextField(
            controller: _date,
            decoration: const InputDecoration(
              labelText: 'Tanggal (YYYY-MM-DD)',
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _level,
            decoration: const InputDecoration(labelText: 'Tingkat'),
            items: [
              for (final l in _Achievements.levels)
                DropdownMenuItem(value: l, child: Text(l)),
            ],
            onChanged: (v) => setState(() => _level = v ?? _level),
          ),
          TextField(
            controller: _result,
            decoration: const InputDecoration(
              labelText: 'Hasil (mis. Juara 1)',
            ),
          ),
          TextField(
            controller: _team,
            decoration: const InputDecoration(
              labelText: 'Nama tim (wajib bila peserta lebih dari satu)',
            ),
          ),
          const SizedBox(height: 12),
          const Text('Peserta (dapat siswa dari ekskul lain)'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Cari nama / NISN',
                  ),
                ),
              ),
              IconButton(onPressed: _lookup, icon: const Icon(Icons.search)),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final e in _picked.entries)
                InputChip(
                  label: Text(e.value),
                  onDeleted: () => setState(() => _picked.remove(e.key)),
                ),
            ],
          ),
          for (final s in _found)
            ListTile(
              dense: true,
              title: Text(_s(s['nama'])),
              subtitle: Text('NISN ${_s(s['nisn'])}'),
              onTap: () => setState(
                () => _picked[int.parse(_s(s['id']))] = _s(s['nama']),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving || _picked.isEmpty ? null : _save,
            child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
          ),
        ],
      ),
    ),
  );
}

// ---- Sisi siswa: daftar ekskul dan lihat presensi sendiri ----
class StudentEkskul extends StatelessWidget {
  const StudentEkskul({super.key, required this.api});
  final AuthApi api;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: PressScale(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StudentScanScreen(api: api),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan QR Presensi'),
            ),
          ),
        ),
        const TabBar(
          tabs: [
            Tab(text: 'Ekskul Saya'),
            Tab(text: 'Daftar Ekskul'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _MyClubs(api: api),
              _Catalog(api: api),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MyClubs extends StatelessWidget {
  const _MyClubs({required this.api});
  final AuthApi api;
  @override
  Widget build(BuildContext context) => _Async(
    load: () => api.siswaGet('/ekskul/saya'),
    builder: (context, raw, reload) {
      final data = Map<String, dynamic>.from(raw as Map);
      final clubs = _list(data['keanggotaan']);
      final regs = _list(data['pendaftaran']);
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (clubs.isEmpty)
              const Text(
                'Anda belum menjadi anggota ekskul. Buka tab Daftar Ekskul.',
              ),
            for (final c in clubs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppPanel(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_s(c['nama'])),
                    subtitle: Text(
                      'Hadir ${_s(c['hadir'])} • Izin ${_s(c['izin'])} • Sakit ${_s(c['sakit'])} • Alfa ${_s(c['alfa'])}\n'
                      '${c['persen_hadir'] == null ? 'Belum ada presensi' : 'Kehadiran ${_s(c['persen_hadir'])}%'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _MyHistory(
                          api: api,
                          periodId: _s(c['id_periode']),
                          title: _s(c['nama']),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (regs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Riwayat Pendaftaran',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final r in regs)
                ListTile(
                  dense: true,
                  title: Text(_s(r['nama'])),
                  subtitle: Text(
                    '${_s(r['status_keputusan'])}${r['alasan'] == null ? '' : ' • ${_s(r['alasan'])}'}',
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _MyHistory extends StatelessWidget {
  const _MyHistory({
    required this.api,
    required this.periodId,
    required this.title,
  });
  final AuthApi api;
  final String periodId, title;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Presensi $title')),
    body: _Async(
      load: () => api.siswaGet('/ekskul/$periodId/presensi'),
      builder: (context, raw, reload) {
        final rows = _list(raw);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (rows.isEmpty) const Text('Belum ada presensi tercatat.'),
            for (final r in rows)
              ListTile(
                title: Text(
                  '${_s(r['tanggal'])} • ${_hm(r['jam_mulai'])}',
                ),
                subtitle: Text(
                  '${_s(r['lokasi'])}${r['keterangan'] == null ? '' : ' • ${_s(r['keterangan'])}'}',
                ),
                trailing: Chip(label: Text(_s(r['status_kehadiran']))),
              ),
          ],
        );
      },
    ),
  );
}

class _Catalog extends StatelessWidget {
  const _Catalog({required this.api});
  final AuthApi api;
  @override
  Widget build(BuildContext context) => _Async(
    load: () => api.siswaGet('/ekskul'),
    builder: (context, raw, reload) {
      final rows = _list(raw);
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (rows.isEmpty) const Text('Belum ada kegiatan ekstrakurikuler.'),
            for (final c in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _s(c['nama']),
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (c['deskripsi'] != null) Text(_s(c['deskripsi'])),
                      Text(
                        '${_s(c['anggota_aktif'])} anggota${c['kapasitas'] == null ? '' : ' / ${_s(c['kapasitas'])}'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      if (c['anggota'] == true)
                        const Chip(label: Text('Anda anggota'))
                      else if (c['status_saya'] == 'MENUNGGU')
                        const Chip(label: Text('Menunggu keputusan pembina'))
                      else
                        FilledButton(
                          onPressed: c['status_pendaftaran'] != 'DIBUKA'
                              ? null
                              : () async {
                                  if (await _act(
                                    context,
                                    () => api.siswaSend(
                                      '/ekskul/${c['id']}/daftar',
                                    ),
                                    ok: 'Pendaftaran terkirim. Tunggu keputusan pembina.',
                                  )) {
                                    await reload();
                                  }
                                },
                          child: Text(
                            c['status_pendaftaran'] == 'DIBUKA'
                                ? 'Daftar'
                                : 'Pendaftaran ditutup',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
