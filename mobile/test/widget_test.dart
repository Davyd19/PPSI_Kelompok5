import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart';
import 'package:mobile/network/auth_api.dart';
import 'package:mobile/screens/teacher/teacher_home.dart';

class MemoryStorage implements SessionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

final profile = {
  'name': 'Siswa Contoh',
  'identitas_login': 'contoh.siswa',
  'available_roles': ['SISWA'],
};
final teacher = {
  'name': 'Guru Contoh',
  'identitas_login': 'contoh.guru',
  'available_roles': ['GURU', 'WALI_KELAS'],
};
http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'Content-Type': 'application/json; charset=utf-8'},
);
Map<String, Object> tokens(String refresh, [Object? user]) => {
  'access_token': 'access',
  'refresh_token': refresh,
  'user': user ?? profile,
};
Future<void> press(WidgetTester tester, String text) async {
  final button = find.widgetWithText(FilledButton, text);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Endpoint fitur guru tidak relevan untuk tes alur masuk.
http.Response notFound() => jsonResponse({
  'error': {'message': 'Tidak ditemukan'},
}, 404);

void main() {
  testWidgets('non-guru account is rejected and its session is revoked', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final storage = MemoryStorage();
    final revoked = <String>[];
    final api = AuthApi(
      storage: storage,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          final body = jsonDecode(request.body) as Map;
          expect(body['identitas_akun'], 'contoh.siswa');
          expect(body['platform'], 'mobile');
          expect(body['kata_sandi'], 'Contoh123!');
          return jsonResponse({'data': tokens('session-refresh')});
        }
        if (request.url.path.endsWith('/auth/logout')) {
          revoked.add(
            (jsonDecode(request.body) as Map)['refresh_token'] as String,
          );
          return http.Response('', 204);
        }
        return notFound();
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(KesiswaanApp(api: api));
    await tester.pumpAndSettle();
    await press(tester, 'Masuk ke SIM Kesiswaan');
    expect(find.text('Identitas akun wajib diisi'), findsOneWidget);
    final identity = find.byKey(const Key('identity'));
    final password = find.byKey(const Key('password'));
    await tester.ensureVisible(identity);
    await tester.enterText(identity, 'contoh.siswa');
    await tester.ensureVisible(password);
    await tester.enterText(password, 'Contoh123!');
    await press(tester, 'Masuk ke SIM Kesiswaan');
    expect(
      find.textContaining('hanya untuk akun Guru'),
      findsOneWidget,
    );
    expect(find.text('Selamat Datang'), findsOneWidget);
    expect(revoked, ['session-refresh']);
    expect(storage.value, isNot(contains('Contoh123!')));
    expect((jsonDecode(storage.value!) as Map)['refresh'], isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('guru goes straight to home without role picker, then logs out', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 820);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final storage = MemoryStorage()
      ..value = jsonEncode({'refresh': 'old', 'logout': []});
    var loggedOut = false;
    final api = AuthApi(
      storage: storage,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/refresh')) {
          return jsonResponse({'data': tokens('new', teacher)});
        }
        if (request.url.path.endsWith('/logout')) {
          loggedOut = true;
          return http.Response('', 204);
        }
        if (request.url.path.endsWith('/me')) {
          return jsonResponse({'data': teacher});
        }
        return notFound();
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(KesiswaanApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Pilih peran'), findsNothing);
    expect(find.byType(TeacherHome), findsOneWidget);
    await tester.tap(find.byTooltip('Buka profil'));
    await tester.pumpAndSettle();
    expect(find.text('Ganti peran'), findsNothing);
    await press(tester, 'Keluar');
    expect(loggedOut, isTrue);
    expect(find.text('Selamat Datang'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'restore rotates token once, offline logout persists and retries after restart',
    () async {
      final storage = MemoryStorage()
        ..value = jsonEncode({'refresh': 'old', 'logout': []});
      var online = true;
      var refreshes = 0;
      final revoked = <String>[];
      MockClient transport() => MockClient((request) async {
        if (!online) throw http.ClientException('offline');
        if (request.url.path.endsWith('/refresh')) {
          refreshes++;
          return jsonResponse({'data': tokens('rotated')});
        }
        if (request.url.path.endsWith('/logout')) {
          revoked.add(
            (jsonDecode(request.body) as Map)['refresh_token'] as String,
          );
          return http.Response('', 204);
        }
        return jsonResponse({'data': profile});
      });
      final api = AuthApi(storage: storage, client: transport());
      expect((await api.restore())?.identity, 'contoh.siswa');
      expect(refreshes, 1);
      expect(storage.value, contains('rotated'));
      online = false;
      await api.logout();
      await api.retryPendingLogout();
      final saved = jsonDecode(storage.value!) as Map;
      expect(saved['refresh'], isNull);
      expect(saved['logout'], ['rotated']);
      api.close();
      online = true;
      final restarted = AuthApi(storage: storage, client: transport());
      expect(await restarted.restore(), isNull);
      await restarted.retryPendingLogout();
      expect(revoked, ['rotated']);
      expect((jsonDecode(storage.value!) as Map)['logout'], isEmpty);
      restarted.close();
    },
  );

  test(
    'connection failure keeps token while a rejected session clears it',
    () async {
      final storage = MemoryStorage()
        ..value = jsonEncode({'refresh': 'old', 'logout': []});
      var online = false;
      final api = AuthApi(
        storage: storage,
        client: MockClient((_) async {
          if (!online) throw http.ClientException('offline');
          return jsonResponse({
            'error': {'message': 'Sesi berakhir'},
          }, 401);
        }),
      );
      await expectLater(api.restore(), throwsA(isA<AuthError>()));
      expect(storage.value, contains('old'));
      online = true;
      expect(await api.restore(), isNull);
      expect((jsonDecode(storage.value!) as Map)['refresh'], isNull);
      api.close();
    },
  );
}
