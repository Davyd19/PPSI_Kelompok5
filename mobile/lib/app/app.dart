import 'package:flutter/material.dart';
import '../network/demo_api.dart';
import '../screens/login_screen.dart';
import '../theme.dart';

class KesiswaanApp extends StatefulWidget {
  const KesiswaanApp({super.key, this.api});
  final DemoApi? api;
  @override
  State<KesiswaanApp> createState() => _KesiswaanAppState();
}

class _KesiswaanAppState extends State<KesiswaanApp> {
  late final DemoApi _api = widget.api ?? DemoApi();
  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SIM Kesiswaan',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    home: LoginScreen(api: _api),
  );
}
