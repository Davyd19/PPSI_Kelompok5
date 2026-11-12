import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/shared.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final Future<void> Function(String identity, String password) onLogin;
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
    final password = _password.text;
    _password.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onLogin(_identity.text, password);
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
          : 'Hubungi administrator sekolah jika memerlukan bantuan akun.',
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: Color(0xFFE6EFFF),
                    child: Icon(Icons.school_outlined, color: navy, size: 40),
                  ),
                ),
                const SizedBox(height: 7),
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
                        const SizedBox(height: 16),
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
                            fillColor: Color(0xFFEDF2FE),
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
                            fillColor: const Color(0xFFEDF2FE),
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
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF203B60),
                            minimumSize: const Size.fromHeight(48),
                          ),
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
