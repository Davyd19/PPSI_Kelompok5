import 'support/ui_test_fonts.dart';
import 'package:mobile/screens/teacher/teacher_home.dart';
import 'package:mobile/app/account_capabilities.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/network/auth_api.dart';
import 'package:mobile/screens/account_home_screen.dart';
import 'package:mobile/screens/pembina_screen.dart';
import 'package:mobile/theme.dart';

class _Memory implements SessionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    value = text;
  }
}

http.Response _json(Object value) => http.Response(
  jsonEncode({'data': value}),
  200,
  headers: {'content-type': 'application/json'},
);
AuthApi _api(String primary, List<String> duties) => AuthApi(
  storage: _Memory(),
  client: MockClient((r) async {
    final path = r.url.path;
    if (path.endsWith('/auth/login')) {
      return _json({
        'access_token': 'test-access',
        'refresh_token': 'test-refresh',
        'user': {
          'name': 'Akun Pengujian',
          'identitas_login': 'pengujian',
          'primary_role': primary,
          'duties': duties,
          'available_roles': [
            primary,
            ...(primary == 'GURU_BK' ? ['GURU'] : []),
            ...duties,
          ],
        },
      });
    }
    if (path.endsWith('/student/dashboard')) {
      return _json({
        'student': {
          'name': 'Siswa Pengujian',
          'classroom': 'XI 1',
          'nisn': '0000000001',
        },
        'attendance_summary': {'on_time_days': 0, 'weekly_grid': []},
        'metrics': {'earned_badges': 0, 'violation_cases': 0},
        'recent_activities': [],
        'unread_notifications': 0,
      });
    }
    if (path.endsWith('/parent/dashboard')) {
      return _json({
        'children': [],
        'child': null,
        'month_name': 'November',
        'attendance_summary': {},
        'points_summary': {},
        'discipline_summary': {},
        'extracurricular_summary': {},
      });
    }
    if (path.endsWith('/guru/presensi/sesi')) {
      return _json({
        'tanggal': '2026-11-25',
        'semester': null,
        'sesi': [],
        'batas_bawaan': {'PAGI': '07:00', 'ZUHUR': '12:30'},
      });
    }
    if (path.endsWith('/pembina/kegiatan')) {
      return _json({'activities': [], 'sessions_today': []});
    }
    return http.Response(
      jsonEncode({
        'error': {'message': 'Belum ada data pengujian.'},
      }),
      503,
      headers: {'content-type': 'application/json'},
    );
  }),
);
void main() {
  setUpAll(loadUiTestFonts);
  testWidgets(
    'meeting form retains entered data after API failure and retries without duplication',
    (tester) async {
      var posts = 0;
      final api = AuthApi(
        storage: _Memory(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return _json({
              'access_token': 'test',
              'refresh_token': 'test-refresh',
              'user': {
                'name': 'Guru',
                'identitas_login': 'test',
                'primary_role': 'GURU',
                'available_roles': ['GURU', 'PEMBINA_EKSTRAKURIKULER'],
              },
            });
          }
          if (request.method == 'POST' &&
              request.url.path.endsWith('/pertemuan')) {
            posts++;
            if (posts == 1) {
              return http.Response(
                jsonEncode({
                  'error': {'message': 'Penyimpanan belum berhasil'},
                }),
                503,
                headers: {'content-type': 'application/json'},
              );
            }
            expect(
              (jsonDecode(request.body) as Map)['lokasi'],
              'Aula pengujian',
            );
            return _json({'id': 1});
          }
          return _json([]);
        }),
      );
      addTearDown(api.close);
      await api.login('test', 'test');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: PembinaActivityScreen(
            api: api,
            activity: const {'id': 1, 'nama': 'Pramuka'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Pertemuan'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Lokasi'),
        'Aula pengujian',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(find.text('Penyimpanan belum berhasil'), findsOneWidget);
      expect(find.text('Aula pengujian'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(posts, 2);
      expect(find.text('Tambah pertemuan'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final primary in ['SISWA', 'ORANG_TUA', 'GURU', 'GURU_BK']) {
    for (final width in [360.0, 390.0]) {
      testWidgets('$primary remains usable at $width dp with larger text', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final duties = ['GURU', 'GURU_BK'].contains(primary)
            ? ['WALI_KELAS', 'PEMBINA_EKSTRAKURIKULER']
            : <String>[];
        final api = _api(primary, duties);
        addTearDown(api.close);
        final profile = await api.login('pengujian', 'pengujian');
        expect(profile.primaryRole, primary);
        expect(profile.duties, duties);
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              theme: appTheme,
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 390 ? 1.3 : 1),
                ),
                child: child!,
              ),
              home: AccountHomeScreen(
                api: api,
                profile: profile,
                onLogout: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pilih peran'), findsNothing);
        expect(tester.takeException(), isNull);
        if (primary == 'GURU_BK') {
          expect(find.text('Beranda Guru BK'), findsOneWidget);
        }
        final dir = Platform.environment['PPSI_UI_CAPTURE_DIR'];
        if (dir != null) {
          await tester.runAsync(() async {
            await Directory(dir).create(recursive: true);
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final picture = await boundary.toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$dir/$primary-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        if (duties.isNotEmpty) {
          tester
              .widget<TeacherHome>(find.byType(TeacherHome))
              .onOpenFeature(TeacherFeature.extracurricular);
          await tester.pumpAndSettle();
          expect(find.text('Ekskul Binaan'), findsOneWidget);
          expect(find.text('Scan QR Presensi'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
