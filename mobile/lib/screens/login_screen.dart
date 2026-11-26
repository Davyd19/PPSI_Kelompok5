import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/school_ui.dart';
import '../widgets/shared.dart';

// Warna diambil dari logo: navy tua, biru buku, dan kuning matahari.
const _deep = Color(0xFF0A1F3A);
const _navyMid = Color(0xFF12365E);
const _logoBlue = Color(0xFF1E63A8);
const _sun = Color(0xFFF2C14E);
const _skyGlow = Color(0xFF5FA8E8);

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
    final identity = _identity.text.trim();
    final password = _password.text;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onLogin(identity, password);
      if (mounted) _password.clear();
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
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: _deep,
      body: Stack(
        children: [
          // Latar gradasi diagonal dari navy tua ke biru logo.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_deep, _navyMid, _logoBlue],
                  stops: [0, .55, 1],
                ),
              ),
            ),
          ),
          // Cahaya lembut (kuning matahari & biru langit) agar tidak kaku.
          const Positioned(top: -90, right: -70, child: _Glow(260, _sun, .22)),
          const Positioned(
            bottom: 60,
            left: -110,
            child: _Glow(300, _skyGlow, .22),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          children: [
                            // Logo + kartu diletakkan di tengah layar agar
                            // ruang kosong atas & bawah seimbang.
                            const Spacer(),
                            _brand(),
                            const SizedBox(height: 28),
                            _FadeUp(child: _card(context)),
                            const Spacer(),
                            const SizedBox(height: 16),
                            _footer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  /// Logo besar dalam lingkaran putih + sapaan.
  Widget _brand() => Column(
    children: [
      Container(
        width: 116,
        height: 116,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: .35), width: 6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .28),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: const SchoolLogo(size: 84),
      ),
      const SizedBox(height: 18),
      const Text(
        'SMAN 12 PADANG',
        style: TextStyle(
          color: _sun,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Selamat Datang',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -.5,
        ),
      ),
    ],
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: navy,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  /// Kartu putih melayang berisi formulir masuk.
  Widget _card(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .22),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
      ],
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: _sun,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Masuk ke akun',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Text(
              'Gunakan identitas akun dari Admin sekolah.',
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
          ),
          const SizedBox(height: 20),
          _label('Identitas akun'),
          TextFormField(
            key: const Key('identity'),
            controller: _identity,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              hintText: 'Contoh: nama.guru',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Identitas akun wajib diisi'
                : null,
          ),
          const SizedBox(height: 16),
          _label('Kata sandi'),
          TextFormField(
            key: const Key('password'),
            controller: _password,
            enabled: !_busy,
            obscureText: _hidden,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Masukkan kata sandi',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                tooltip: _hidden
                    ? 'Tampilkan kata sandi'
                    : 'Sembunyikan kata sandi',
                onPressed: () => setState(() => _hidden = !_hidden),
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
              style: TextButton.styleFrom(foregroundColor: _logoBlue),
              onPressed: () => _help('Lupa kata sandi'),
              child: const Text(
                'Lupa kata sandi?',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cBrick.$2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 18, color: cBrick.$1),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: cBrick.$1, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _navyMid,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Flexible(child: Text('Memproses…')),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text('Masuk ke SIM Kesiswaan')),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _footer() => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        'Belum punya akun?',
        style: TextStyle(
          fontSize: 12.5,
          color: Colors.white.withValues(alpha: .75),
        ),
      ),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: _sun),
        onPressed: () => _help('Bantuan akun'),
        child: const Text(
          'Hubungi Admin Sekolah',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

/// Lingkaran cahaya lembut (gradasi radial ke transparan).
class _Glow extends StatelessWidget {
  const _Glow(this.size, this.color, this.opacity);
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

/// Animasi masuk halus: memudar sambil naik sedikit.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 550),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
    ),
  );
}
