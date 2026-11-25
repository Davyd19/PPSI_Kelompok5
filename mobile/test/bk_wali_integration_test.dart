import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/kasus_models.dart';
import 'package:mobile/network/auth_api.dart';
import 'package:mobile/network/kasus_api.dart';
import 'package:mobile/screens/account_home_screen.dart';
import 'package:mobile/screens/kasus/kasus_list_screen.dart';
import 'package:mobile/screens/teacher/teacher_home.dart';
import 'package:mobile/theme.dart';

class _Memory implements SessionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    value = next;
  }
}

AuthApi _api(List<String> roles, List<http.Request> calls) => AuthApi(
  storage: _Memory(),
  client: MockClient((request) async {
    calls.add(request);
    final data = request.url.path.endsWith('/login')
        ? {
            'access_token': 'test-access',
            'refresh_token': 'test-refresh',
            'user': {
              'name': 'Guru',
              'identitas_login': 'test',
              'available_roles': roles,
            },
          }
        : <Object>[];
    return http.Response(
      jsonEncode({'data': data}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

void main() {
  for (final role in ['GURU_BK', 'WALI_KELAS']) {
    testWidgets(
      '$role keeps TeacherHome and opens its authorized cases in the same workspace',
      (tester) async {
        final calls = <http.Request>[];
        final roles = ['GURU', role];
        final api = _api(roles, calls);
        addTearDown(api.close);
        await api.login('test', 'test');
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: AccountHomeScreen(
              api: api,
              profile: AccountProfile('Guru', 'test', roles),
              onLogout: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TeacherHome), findsOneWidget);
        final home = tester.widget<TeacherHome>(find.byType(TeacherHome));
        home.onUnavailable(
          role == 'GURU_BK' ? 'Penanganan Siswa' : 'Kelas Binaan',
        );
        await tester.pumpAndSettle();
        expect(find.byType(KasusListScreen), findsOneWidget);
        expect(
          calls.any(
            (call) => call.url.path.endsWith(
              role == 'GURU_BK' ? '/guru-bk/kasus' : '/wali-kelas/kasus',
            ),
          ),
          isTrue,
        );
        expect(find.byType(NavigationBar), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TeacherHome), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'BK who is also Wali can open both features without switching login role',
    (tester) async {
      final calls = <http.Request>[];
      const roles = ['GURU', 'GURU_BK', 'WALI_KELAS'];
      final api = _api(roles, calls);
      addTearDown(api.close);
      await api.login('test', 'test');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: AccountHomeScreen(
            api: api,
            profile: const AccountProfile('Guru', 'test', roles),
            onLogout: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final feature in ['Kelas Binaan', 'Penanganan Siswa']) {
        tester
            .widget<TeacherHome>(find.byType(TeacherHome))
            .onUnavailable(feature);
        await tester.pumpAndSettle();
        expect(find.byType(KasusListScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      expect(
        calls.any((call) => call.url.path.endsWith('/guru-bk/kasus')),
        isTrue,
      );
      expect(
        calls.any((call) => call.url.path.endsWith('/wali-kelas/kasus')),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'handling and report can share a numeric ID without losing their source',
    () async {
      final calls = <http.Request>[];
      final api = _api(['GURU_BK'], calls);
      addTearDown(api.close);
      await api.login('test', 'test');
      final model = Kasus.fromJson({
        'id': 7,
        'sumber': 'PENANGANAN',
        'nama_siswa': 'Siswa',
        'status': 'DALAM_PEMBINAAN',
      });
      final cases = KasusApi(api, role: 'GURU_BK').forKasus(model.copyWith());
      await cases.simpanTindakLanjutTambahan(7, catatan: 'Catatan');
      expect(calls.last.url.queryParameters['sumber'], 'PENANGANAN');
      expect(calls.last.url.path, endsWith('/guru-bk/kasus/7/tindak-lanjut'));
    },
  );
}
