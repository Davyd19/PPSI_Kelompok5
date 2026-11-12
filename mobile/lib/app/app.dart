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
  String? _role, _error;
  bool _restoring = true, _choosing = false;
  Timer? _retryLogout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api.onExpired = () {
      if (mounted) {
        setState(() {
          _profile = null;
          _role = null;
          _choosing = false;
        });
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

  void _selectProfile(AccountProfile profile) => setState(() {
    _profile = profile;
    _role = profile.roles.length == 1 ? profile.roles.single : null;
    _choosing = false;
  });
  Future<void> _logout() async {
    await _api.logout();
    if (mounted) {
      setState(() {
        _profile = null;
        _role = null;
        _choosing = false;
        _error = null;
      });
    }
  }

  Future<void> _switchRole() async {
    final profile = await _api.profile();
    if (!mounted || _profile == null) return;
    if (profile.roles.length <= 1) {
      _selectProfile(profile);
      return;
    }
    setState(() {
      _profile = profile;
      _choosing = true;
    });
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
    } else if (_role == null || _choosing) {
      screen = Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const SchoolIdentity(),
        ),
        body: SafeArea(
          child: PortalList(
            children: [
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih peran',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              for (final role in profile.roles)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                  onPressed: () => setState(() {
                    _role = role;
                    _choosing = false;
                  }),
                  child: Row(
                    children: [
                      PortalIcon(roleIcons[role] ?? Icons.person_outline),
                      const SizedBox(width: 10),
                      Expanded(child: Text(roleNames[role] ?? role)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              if (profile.roles.isEmpty)
                const AppPanel(
                  child: Text(
                    'Akun ini tidak memiliki peran mobile yang aktif.',
                  ),
                ),
              if (_choosing && profile.roles.contains(_role))
                TextButton(
                  onPressed: () => setState(() => _choosing = false),
                  child: const Text('Kembali'),
                ),
              TextButton(onPressed: _logout, child: const Text('Keluar')),
            ],
          ),
        ),
      );
    } else {
      screen = AccountHomeScreen(
        key: ValueKey(_role),
        api: _api,
        profile: profile,
        role: _role!,
        onLogout: _logout,
        onSwitchRole: _switchRole,
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
