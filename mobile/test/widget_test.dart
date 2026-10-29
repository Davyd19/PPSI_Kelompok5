import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart';
import 'package:mobile/network/demo_api.dart';

final fixture =
    jsonDecode(File('test/fixtures/demo.json').readAsStringSync())
        as Map<String, dynamic>;
DemoApi api({
  bool fail = false,
  bool empty = false,
  bool failDashboard = false,
  void Function(Uri)? onRequest,
}) => DemoApi(
  client: MockClient((request) async {
    onRequest?.call(request.url);
    if (fail) throw const SocketException('offline');
    dynamic body;
    int status = 200;
    if (request.url.path.endsWith('/profiles')) {
      body = {'data': empty ? [] : fixture['profiles']};
    } else if (failDashboard) {
      status = 500;
      body = {
        'error': {'code': 'INTERNAL_ERROR', 'message': 'Données indisponibles'},
      };
    } else {
      final role = request.url.queryParameters['role'];
      final profile = (fixture['profiles'] as List).firstWhere(
        (p) => p['role'] == role,
      );
      body = {
        'data': {
          'simulation': true,
          'profile': profile,
          ...fixture['shared'] as Map<String, dynamic>,
          ...(fixture['dashboards'] as Map<String, dynamic>)[role]
              as Map<String, dynamic>,
        },
      };
    }
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);
Future<void> tap(WidgetTester tester, String text) async {
  final f = find.text(text);
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.4);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, {DemoApi? client}) async {
  await tester.pumpWidget(KesiswaanApp(api: client ?? api()));
  await tester.pumpAndSettle();
}

Future<void> login(
  WidgetTester tester,
  String identity, {
  String password = 'Contoh123!',
}) async {
  await tester.ensureVisible(find.byKey(const Key('identity')));
  await tester.enterText(find.byKey(const Key('identity')), identity);
  await tester.ensureVisible(find.byKey(const Key('password')));
  await tester.enterText(find.byKey(const Key('password')), password);
  await tap(tester, 'Masuk ke SIM Kesiswaan');
}

Future<void> logout(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profil'));
  await tester.pumpAndSettle();
  await tap(tester, 'Keluar');
}

void main() {
  testWidgets(
    'login has no demo selector and validates form and local credentials',
    (tester) async {
      final requests = <Uri>[];
      await open(tester, client: api(onRequest: requests.add));
      expect(find.textContaining('Coba sebagai'), findsNothing);
      await tap(tester, 'Masuk ke SIM Kesiswaan');
      expect(find.text('Identitas akun wajib diisi'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
      await login(tester, 'siswa', password: 'salah');
      expect(
        find.text('Identitas akun atau kata sandi salah.'),
        findsOneWidget,
      );
      expect(requests, isEmpty);
      await login(tester, 'admin');
      expect(find.text('Gunakan portal web untuk akun ini.'), findsOneWidget);
      expect(requests, isEmpty);
      await login(tester, 'tidak-ada');
      expect(
        find.text('Identitas akun atau kata sandi salah.'),
        findsOneWidget,
      );
      await login(tester, 'siswa');
      expect(find.text('Farhan Ramadhan'), findsOneWidget);
      expect(
        requests.every(
          (u) =>
              !u.toString().contains('Contoh123') &&
              !u.toString().contains('password'),
        ),
        isTrue,
      );
    },
  );
  testWidgets('password visibility and forgot-password information', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.byTooltip('Tampilkan kata sandi'));
    await tester.tap(find.byTooltip('Tampilkan kata sandi'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isFalse,
    );
    await tap(tester, 'Lupa Kata Sandi?');
    expect(
      find.textContaining('Pemulihan kata sandi belum tersedia'),
      findsOneWidget,
    );
  });
  for (final e in {
    'siswa': 'Siswa',
    'ortu': 'Orang Tua',
    'guru': 'Guru',
    'wali': 'Wali Kelas',
    'bk': 'Guru BK',
    'pembina': 'Pembina Ekstrakurikuler',
  }.entries) {
    testWidgets('${e.value} enters own dashboard and logs out', (tester) async {
      await open(tester);
      await login(tester, e.key);
      expect(find.text('Beranda ${e.value}'), findsOneWidget);
      await logout(tester);
      expect(find.text('Selamat Datang'), findsOneWidget);
    });
  }
  testWidgets('attendance prevents duplicates and resets on logout', (
    tester,
  ) async {
    await open(tester);
    await login(tester, 'siswa');
    expect(find.text('Belum presensi'), findsNWidgets(2));
    await tap(tester, 'Scan QR');
    await tap(tester, 'Konfirmasi');
    expect(find.text('Belum presensi'), findsOneWidget);
    await tap(tester, 'Scan QR');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Konfirmasi'))
          .onPressed,
      isNull,
    );
    await tap(tester, 'Zuhur');
    await tap(tester, 'Konfirmasi');
    expect(find.text('Belum presensi'), findsNothing);
    await logout(tester);
    await login(tester, 'siswa');
    expect(find.text('Belum presensi'), findsNWidgets(2));
  });
  testWidgets('student details and navigation remain interactive', (
    tester,
  ) async {
    await open(tester);
    await login(tester, 'siswa');
    await tester.tap(find.byTooltip('Notifikasi'));
    await tester.pumpAndSettle();
    expect(find.text('Latihan basket sore ini'), findsOneWidget);
    Navigator.of(tester.element(find.text('Notifikasi').first)).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Badge Aktif Berkegiatan'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(tester, 'Badge Aktif Berkegiatan');
    expect(find.textContaining('Tanpa verifikasi manual'), findsOneWidget);
    Navigator.of(tester.element(find.text('Aktif Berkegiatan'))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Basket'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(tester, 'Basket');
    expect(find.textContaining('Latihan teknik dasar'), findsOneWidget);
    Navigator.of(tester.element(find.text('Basket').last)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fitur belum tersedia'), findsOneWidget);
  });
  testWidgets('API and missing profiles fail without bypassing login', (
    tester,
  ) async {
    await open(tester, client: api(fail: true));
    await login(tester, 'siswa');
    expect(find.textContaining('API tidak dapat dihubungi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester, client: api(empty: true));
    await login(tester, 'siswa');
    expect(find.text('Profil belum tersedia.'), findsOneWidget);
  });
  testWidgets('dashboard failure offers retry and logout', (tester) async {
    await open(tester, client: api(failDashboard: true));
    await login(tester, 'guru');
    expect(find.text('Données indisponibles'), findsOneWidget);
    await tap(tester, 'Coba Lagi');
    expect(find.text('Données indisponibles'), findsOneWidget);
    await logout(tester);
    expect(find.text('Selamat Datang'), findsOneWidget);
  });
  testWidgets('all roles support 320px screen large text and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    await tester.ensureVisible(find.byKey(const Key('identity')));
    await tester.tap(find.byKey(const Key('identity')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    for (final id in ['siswa', 'ortu', 'guru', 'wali', 'bk', 'pembina']) {
      await login(tester, id);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await logout(tester);
    }
  });
}
