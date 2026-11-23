import 'dart:async';
import 'package:flutter/material.dart';
import '../network/auth_api.dart';
import '../screens/account_home_screen.dart';
import '../screens/login_screen.dart';
import '../theme.dart';

/// Aplikasi mobile ini khusus untuk Guru. Akun dibuat oleh Admin; tidak ada
/// pendaftaran mandiri dan tidak ada pemilihan peran.
const appRole = 'GURU';
const _notTeacher =
    'Aplikasi ini hanya untuk akun Guru. Hubungi Admin sekolah '
    'jika akun Anda seharusnya memiliki akses Guru.';

class KesiswaanApp extends StatefulWidget {
  const KesiswaanApp({super.key, this.api});
  final AuthApi? api;
  @override
  State<KesiswaanApp> createState() => _KesiswaanAppState();
}

class _KesiswaanAppState extends State<KesiswaanApp>
    with WidgetsBindingObserver {
  late final AuthApi _api = widget.api ?? AuthApi();
  AccountProfile? _profile;
  String? _error;
  bool _restoring = true;
  Timer? _retryLogout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api.onExpired = () {
      if (mounted) {
        setState(() => _profile = null);
      }
    };
    _retryLogout = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _api.retryPendingLogout(),
    );
    _restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_api.retryPendingLogout());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryLogout?.cancel();
    _api.onExpired = null;
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _error = null;
    });
    try {
      final profile = await _api.restore();
      if (profile != null && !profile.roles.contains(appRole)) {
        await _api.logout();
      } else if (mounted && profile != null) {
        setState(() => _profile = profile);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  /// Masuk hanya jika akun memiliki peran Guru; selain itu sesi langsung
  /// ditutup dan pesan ditampilkan di halaman masuk.
  Future<void> _login(String identity, String password) async {
    final profile = await _api.login(identity, password);
    if (!profile.roles.contains(appRole)) {
      await _api.logout();
      throw const AuthError(_notTeacher, 403);
    }
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _logout() async {
    await _api.logout();
    if (mounted) {
      setState(() {
        _profile = null;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final Widget screen;
    if (_restoring) {
      screen = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (_error != null) {
      screen = Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  FilledButton(
                    onPressed: _restore,
                    child: const Text('Coba lagi'),
                  ),
                  TextButton(
                    onPressed: _logout,
                    child: const Text('Keluar dari sesi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (profile == null) {
      screen = LoginScreen(onLogin: _login);
    } else {
      screen = AccountHomeScreen(
        api: _api,
        profile: profile,
        role: appRole,
        onLogout: _logout,
      );
    }
    return MaterialApp(
      title: 'SIM Kesiswaan',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: screen,
    );
  }
}
