import 'package:mobile/app/account_capabilities.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/network/auth_api.dart';
import 'package:mobile/screens/account_home_screen.dart';
import 'package:mobile/screens/pembina_screen.dart';
import 'package:mobile/screens/profile_view.dart';
import 'package:mobile/screens/parent/parent_attendance_screen.dart';
import 'package:mobile/screens/teacher/attendance_recap_screen.dart';
import 'package:mobile/screens/teacher/profile_screen.dart';
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

http.Response _json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
AuthApi _api(String role) => AuthApi(
  storage: _Memory(),
  client: MockClient((request) async {
    if (request.url.path.endsWith('/login')) {
      return _json({
        'data': {
          'access_token': 'merge-test',
          'refresh_token': 'merge-test-refresh',
          'user': {
            'name': 'Akun Pengujian',
            'identitas_login': 'contoh',
            'available_roles': [role],
          },
        },
      });
    }
    if (request.url.path.endsWith('/guru/profil')) {
      return _json({
        'data': {
          'nama': 'Guru Pengujian',
          'identitas_login': 'contoh.guru',
          'status_akun': 'AKTIF',
          'email': 'guru@example.test',
          'telepon': '081234567890',
          'peran': ['Guru'],
          'wali_kelas': [],
          'pembina_ekstrakurikuler': ['Pramuka'],
        },
      });
    }
    if (request.url.path.endsWith('/pembina/kegiatan')) {
      return _json({
        'data': {'activities': [], 'sessions_today': []},
      });
    }
    return _json({
      'error': {'message': 'Data pengujian belum tersedia.'},
    }, 503);
  }),
);

void main() {
  testWidgets(
    'Guru retains nested navigation, edited profile and extracurricular access after merge',
    (tester) async {
      final api = _api('GURU');
      addTearDown(api.close);
      await api.login('test', 'test');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: AccountHomeScreen(
            api: api,
            profile: const AccountProfile('Guru Pengujian', 'contoh.guru', [
              'GURU',
              'PEMBINA_EKSTRAKURIKULER',
            ]),
            onLogout: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TeacherHome), findsOneWidget);
      final recap = find.text('Rekap Kehadiran');
      await tester.scrollUntilVisible(
        recap,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(recap), alignment: .4);
      await tester.pumpAndSettle();
      await tester.tap(recap);
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceRecapScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Profil'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(ProfileView), findsNothing);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Beranda'));
      await tester.pumpAndSettle();
      expect(
        find.byType(AttendanceRecapScreen),
        findsOneWidget,
        reason: 'The Home tab keeps its own navigation stack.',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TeacherHome), findsOneWidget);
      tester
          .widget<TeacherHome>(find.byType(TeacherHome))
          .onOpenFeature(TeacherFeature.extracurricular);
      await tester.pumpAndSettle();
      expect(find.byType(PembinaHome), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TeacherHome), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Parent attendance and shared profile from main remain reachable',
    (tester) async {
      final api = _api('ORANG_TUA');
      addTearDown(api.close);
      await api.login('test', 'test');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: AccountHomeScreen(
            api: api,
            profile: const AccountProfile(
              'Orang Tua Pengujian',
              'contoh.ortu',
              ['ORANG_TUA'],
            ),
            onLogout: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Presensi'));
      await tester.pumpAndSettle();
      expect(find.byType(ParentAttendanceScreen), findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Profil'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileView), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
