import '../../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../../network/auth_api.dart';
import '../../network/teacher_profile_api.dart';
import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';

const _red = Color(0xFFC62828);

/// Halaman Profil Guru: data diri, kontak (bisa diubah), tugas,
/// keamanan (ganti kata sandi), info aplikasi, dan keluar.
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => SchoolDialog(
        icon: const Icon(Icons.logout, color: _red),
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda perlu masuk kembali untuk memakai aplikasi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, keluar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await widget.onLogout();
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: navy,
      title: const Text('Profil'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: _content(),
          ),
        ),
      ),
    ),
  );

  List<Widget> _content() {
    final p = _profile;
    if (p == null && _error != null) {
      return [
        const SizedBox(height: 40),
        Text('$_error', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Center(
          child: FilledButton(onPressed: _load, child: const Text('Coba lagi')),
        ),
        const SizedBox(height: 24),
        _logoutButton(),
      ];
    }
    if (p == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final tasks = [
      ...p.homeroomClasses.map((c) => ('Wali Kelas', c, Icons.class_outlined)),
      ...p.extracurriculars.map(
        (e) => ('Pembina Ekstrakurikuler', e, Icons.emoji_events_outlined),
      ),
    ];
    return [
      _header(p),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Data Diri',
        icon: Icons.badge_outlined,
        color: sectionBlue,
        child: Column(
          children: [
            _InfoRow(Icons.person_outline, 'Nama lengkap', p.name),
            _InfoRow(Icons.numbers, 'NIP', p.nip ?? '-'),
            _InfoRow(Icons.alternate_email, 'Identitas akun', p.login),
            _InfoRow(
              Icons.verified_user_outlined,
              'Status akun',
              p.status == 'AKTIF' ? 'Aktif' : 'Nonaktif',
            ),
            const SizedBox(height: 4),
            const Text(
              'Nama dan NIP hanya dapat diubah oleh Admin sekolah.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
      SectionCard(
        title: 'Kontak',
        icon: Icons.contact_phone_outlined,
        color: sectionGreen,
        trailing: TextButton.icon(
          onPressed: _editContact,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Ubah'),
        ),
        child: Column(
          children: [
            _InfoRow(Icons.email_outlined, 'Email', p.email ?? 'Belum diisi'),
            _InfoRow(Icons.phone_outlined, 'Telepon', p.phone ?? 'Belum diisi'),
          ],
        ),
      ),
      SectionCard(
        title: 'Tugas',
        icon: Icons.work_outline,
        color: sectionPurple,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                const ColorPill('Guru', color: sectionPurple),
                for (final r in p.roles)
                  if (r.toLowerCase() != 'guru')
                    ColorPill(r, color: sectionPurple),
              ],
            ),
            for (final (label, value, icon) in tasks)
              _InfoRow(icon, label, value),
          ],
        ),
      ),
      SectionCard(
        title: 'Keamanan',
        icon: Icons.lock_outline,
        color: sectionOrange,
        padding: EdgeInsets.zero,
        child: _Tappable(
          leading: const Icon(Icons.password, color: sectionOrange),
          title: const Text('Ganti kata sandi'),
          subtitle: const Text(
            'Perangkat lain akan otomatis dikeluarkan',
            style: TextStyle(fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _changePassword,
        ),
      ),
      SectionCard(
        title: 'Tentang',
        icon: Icons.info_outline,
        color: attendanceTeal,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            const _Tappable(
              dense: true,
              leading: Icon(Icons.school_outlined),
              title: Text('SIM Kesiswaan'),
              subtitle: Text('SMAN 12 Padang'),
            ),
            _Tappable(
              dense: true,
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Bantuan akun'),
              subtitle: const Text('Hubungi Admin sekolah'),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => SchoolDialog(
                  title: const Text('Bantuan akun'),
                  content: const Text(
                    'Untuk perubahan nama, NIP, peran, atau lupa kata sandi, '
                    'hubungi Admin sekolah.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      _logoutButton(),
    ];
  }

  Widget _logoutButton() => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: _red,
      side: const BorderSide(color: _red),
      minimumSize: const Size.fromHeight(48),
    ),
    onPressed: _loggingOut ? null : _logout,
    icon: const Icon(Icons.logout),
    label: Text(_loggingOut ? 'Keluar...' : 'Keluar'),
  );

  Widget _header(TeacherProfile p) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: const Color(0xFF0E2A47),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: Colors.white,
          child: Text(
            p.initials,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: navy,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                p.nip == null ? 'Guru • SMAN 12 Padang' : 'NIP ${p.nip}',
                style: const TextStyle(color: Color(0xFFD9E9FA), fontSize: 12),
              ),
              if (p.homeroomClasses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Wali Kelas ${p.homeroomClasses.join(', ')}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// ListTile dengan Material sendiri agar efek sentuh terlihat di atas
/// latar berwarna SectionCard.
class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dense = false,
  });
  final Widget leading, title;
  final Widget? subtitle, trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ListTile(
      dense: dense,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: muted)),
              Text(
                value,
                style: const TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
      title: const Text('Ubah Kontak'),
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
      title: const Text('Ganti Kata Sandi'),
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
