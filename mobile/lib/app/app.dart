import 'dart:async';
import 'package:flutter/material.dart';
import '../network/auth_api.dart';
import '../screens/account_home_screen.dart';
import '../screens/account_dashboard.dart';
import '../widgets/shared.dart';
import '../screens/login_screen.dart';
import '../theme.dart';

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
      if (mounted && profile != null) _selectProfile(profile);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _selectProfile(AccountProfile profile) =>
      setState(() => _profile = profile);
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
      screen = LoginScreen(
        onLogin: (identity, password) async {
          final profile = await _api.login(identity, password);
          if (mounted) _selectProfile(profile);
        },
      );
    } else if (profile.roles.isEmpty) {
      screen = Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const SchoolIdentity(),
        ),
        body: SafeArea(
          child: PortalList(
            children: [
              AppPanel(
                child: Text(
                  'Akun ${profile.name} tidak memiliki akses di aplikasi mobile.',
                ),
              ),
              TextButton(onPressed: _logout, child: const Text('Keluar')),
            ],
          ),
        ),
      );
    } else {
      screen = AccountHomeScreen(
        key: ValueKey(profile.identity),
        api: _api,
        profile: profile,
        onLogout: _logout,
      );
    }
    return MaterialApp(
      title: 'SIM Kesiswaan',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      // Login, beranda, dan layar status berganti dengan memudar.
      home: AnimatedSwitcher(
        duration: motionBase,
        switchInCurve: motionCurve,
        child: KeyedSubtree(
          key: ValueKey('${screen.runtimeType}${profile?.identity}'),
          child: screen,
        ),
      ),
    );
  }
}
