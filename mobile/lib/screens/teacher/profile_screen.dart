import '../../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../../network/auth_api.dart';
import '../../network/teacher_profile_api.dart';
import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';
import '../profile/profile_body.dart';

const _red = profileRed;

const _teacherGuide =
    '• Beranda: semua penugasan Anda tampil dalam satu halaman.\n'
    '• Presensi: buat QR sesi pagi/Zuhur, atur waktu berlakunya, unduh QR, '
    'dan input manual bila pemindaian gagal.\n'
    '• Rekap Kehadiran: lihat dan ubah presensi siswa bila ada kekeliruan.\n'
    '• Wali Kelas dan Pembina tersedia sesuai penugasan aktif dalam akun ini. Portal Kesiswaan memakai akun Kesiswaan.';

/// Halaman Profil Guru / Guru BK: memakai tampilan profil bersama
/// ([ProfileBody]) dengan data lengkap dari server, ubah kontak, dan
/// ganti kata sandi.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api, required this.onLogout});
  final TeacherProfileApi api;
  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  TeacherProfile? _profile;
  Object? _error;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final p = await widget.api.load();
      if (mounted) setState(() => _profile = p);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _editContact() async {
    final updated = await Navigator.of(context).push<TeacherProfile>(
      MaterialPageRoute(
        builder: (_) => _EditContactPage(api: widget.api, profile: _profile!),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _profile = updated);
      _toast('Profil berhasil diperbarui.');
    }
  }

  Future<void> _changePassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _ChangePasswordPage(api: widget.api)),
    );
    if (changed == true && mounted) {
      _toast('Kata sandi berhasil diganti. Perangkat lain telah dikeluarkan.');
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await widget.onLogout();
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  ProfileData _data(TeacherProfile p) => ProfileData(
    name: p.name,
    login: p.login,
    roleLabel: 'Guru',
    status: p.status,
    identities: [('NIP', p.nip)],
    identityNote: 'Nama dan NIP hanya dapat diubah oleh Admin sekolah.',
    email: p.email,
    phone: p.phone,
    roles: [
      'Guru',
      for (final r in p.roles)
        if (r.toLowerCase() != 'guru') r,
    ],
    tasks: [
      ...p.homeroomClasses.map((c) => ('Wali Kelas', c, Icons.class_outlined)),
      ...p.extracurriculars.map(
        (e) => ('Pembina Ekstrakurikuler', e, Icons.emoji_events_outlined),
      ),
    ],
    headerNote: p.homeroomClasses.isEmpty
        ? null
        : 'Wali Kelas ${p.homeroomClasses.join(', ')}',
    guide: _teacherGuide,
  );

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: const SchoolPageTitle(title: 'Profil'),
      ),
      body: p != null
          ? ProfileBody(
              data: _data(p),
              loggingOut: _loggingOut,
              onLogout: _logout,
              onEditContact: _editContact,
              onChangePassword: _changePassword,
              onRefresh: _load,
            )
          : _error != null
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 40),
                Text('$_error', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Center(
                  child: FilledButton(
                    onPressed: _load,
                    child: const Text('Coba lagi'),
                  ),
                ),
                const SizedBox(height: 24),
                ProfileLogoutButton(
                  loggingOut: _loggingOut,
                  onConfirmed: _logout,
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

/// Ubah email & telepon.
class _EditContactPage extends StatefulWidget {
  const _EditContactPage({required this.api, required this.profile});
  final TeacherProfileApi api;
  final TeacherProfile profile;

  @override
  State<_EditContactPage> createState() => _EditContactPageState();
}

class _EditContactPageState extends State<_EditContactPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.profile.email);
  late final _phone = TextEditingController(text: widget.profile.phone);
  Map<String, dynamic>? _serverErrors;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _serverErrors = null);
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final p = await widget.api.updateContact(
        email: _email.text,
        phone: _phone.text,
      );
      if (mounted) Navigator.pop(context, p);
    } on AuthError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _serverErrors = e.details;
        });
        _form.currentState!.validate();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: navy,
      title: const SchoolPageTitle(title: 'Ubah Kontak'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'nama@sekolah.sch.id',
            ),
            validator: (v) {
              if (_serverErrors?['email'] case final String m) return m;
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(t)
                  ? null
                  : 'Format email tidak valid.';
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Nomor telepon / WhatsApp',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: '08xxxxxxxxxx',
            ),
            validator: (v) {
              if (_serverErrors?['telepon'] case final String m) return m;
              final t = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
              if (t.isEmpty) return null;
              return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(t)
                  ? null
                  : 'Nomor telepon 8–15 digit.';
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Kosongkan kolom untuk menghapus data.',
            style: TextStyle(fontSize: 11, color: muted),
          ),
          if (_error != null && _serverErrors == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: _red)),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: attendanceTeal,
            ),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      ),
    ),
  );
}

/// Ganti kata sandi: lama, baru, konfirmasi.
class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage({required this.api});
  final TeacherProfileApi api;

  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController(),
      _new = TextEditingController(),
      _confirm = TextEditingController();
  bool _hidden = true, _saving = false;
  Map<String, dynamic>? _serverErrors;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _serverErrors = null);
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.changePassword(_old.text, _new.text);
      if (mounted) Navigator.pop(context, true);
    } on AuthError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _serverErrors = e.details;
        });
        _form.currentState!.validate();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    prefixIcon: const Icon(Icons.lock_outline),
    suffixIcon: IconButton(
      tooltip: _hidden ? 'Tampilkan' : 'Sembunyikan',
      onPressed: () => setState(() => _hidden = !_hidden),
      icon: Icon(
        _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: navy,
      title: const SchoolPageTitle(title: 'Ganti Kata Sandi'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _old,
            obscureText: _hidden,
            decoration: _decoration('Kata sandi lama'),
            validator: (v) {
              if (_serverErrors?['kata_sandi_lama'] case final String m) {
                return m;
              }
              return (v ?? '').isEmpty ? 'Wajib diisi.' : null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _new,
            obscureText: _hidden,
            decoration: _decoration('Kata sandi baru'),
            validator: (v) {
              if (_serverErrors?['kata_sandi_baru'] case final String m) {
                return m;
              }
              final t = v ?? '';
              if (t.length < 10) return 'Minimal 10 karakter.';
              if (t == _old.text) return 'Harus berbeda dari kata sandi lama.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirm,
            obscureText: _hidden,
            decoration: _decoration('Ulangi kata sandi baru'),
            validator: (v) => v == _new.text ? null : 'Konfirmasi tidak sama.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Minimal 10 karakter. Setelah diganti, akun Anda di perangkat '
            'lain akan otomatis keluar.',
            style: TextStyle(fontSize: 11, color: muted),
          ),
          if (_error != null && _serverErrors == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: _red)),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: attendanceTeal,
            ),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_saving ? 'Menyimpan...' : 'Ganti Kata Sandi'),
          ),
        ],
      ),
    ),
  );
}
