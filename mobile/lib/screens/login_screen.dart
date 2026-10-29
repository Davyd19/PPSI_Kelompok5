import 'package:flutter/material.dart';
import '../models/example_accounts.dart';
import '../network/demo_api.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import 'role_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api});
  final DemoApi api;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _identity = TextEditingController(),
      _password = TextEditingController();
  bool _hidden = true, _busy = false;
  String? _error;
  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    final error = accountError(_identity.text, _password.text);
    _password.clear();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final role = exampleAccounts[_identity.text.trim().toLowerCase()];
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profiles = await widget.api.profiles();
      if (!mounted) return;
      final matches = profiles.where((p) => p.role == role);
      if (matches.isEmpty) {
        setState(() => _error = 'Profil belum tersedia.');
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              RoleHomeScreen(api: widget.api, profile: matches.first),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _help(String title) => showDetails(
    context,
    title: title,
    child: Text(
      title == 'Lupa kata sandi'
          ? 'Pemulihan kata sandi belum tersedia. Hubungi administrator setelah akun sekolah diterbitkan.'
          : 'Bantuan akun sekolah belum terhubung. Gunakan akun contoh yang tercantum pada panduan pengembangan.',
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xFFE6EFFF),
                    child: Icon(Icons.school_outlined, color: navy, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Chip(
                    label: Text(
                      'PORTAL KESISWAAN',
                      style: TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Color(0xFFACEEFB),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SIM Kesiswaan',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                const Text(
                  'SMAN 12 Padang',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF236A7C),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Sistem Informasi Kedisiplinan, Kehadiran, & Ekstrakurikuler',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 24),
                AppPanel(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Selamat Datang',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Gunakan identitas akun Anda untuk melanjutkan.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Identitas akun',
                          style: TextStyle(
                            color: navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('identity'),
                          controller: _identity,
                          enabled: !_busy,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            hintText: 'Masukkan identitas akun',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Identitas akun wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Kata sandi',
                          style: TextStyle(
                            color: navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('password'),
                          controller: _password,
                          enabled: !_busy,
                          obscureText: _hidden,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'Masukkan kata sandi akun',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _hidden
                                  ? 'Tampilkan kata sandi'
                                  : 'Sembunyikan kata sandi',
                              onPressed: () =>
                                  setState(() => _hidden = !_hidden),
                              icon: Icon(
                                _hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Kata sandi wajib diisi'
                              : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _help('Lupa kata sandi'),
                            child: const Text(
                              'Lupa Kata Sandi?',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFAD2F3C),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _busy
                                      ? 'Memproses…'
                                      : 'Masuk ke SIM Kesiswaan',
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (!_busy)
                                const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFEAFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: Color(0xFF236A7C),
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Presensi Sekolah Melalui QR',
                              style: TextStyle(
                                color: navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Akses kehadiran, kegiatan, dan perkembangan siswa dalam satu aplikasi.',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Butuh bantuan akun?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11),
                ),
                TextButton(
                  onPressed: () => _help('Bantuan akun'),
                  child: const Text(
                    'Hubungi Admin Sekolah',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const Text(
                  'Prototipe • Gunakan akun contoh, bukan kredensial sekolah.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
