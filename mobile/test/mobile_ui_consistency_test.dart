import 'support/ui_test_fonts.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/network/auth_api.dart';
import 'package:mobile/network/kasus_api.dart';
import 'package:mobile/network/attendance_recap_api.dart';
import 'package:mobile/network/school_attendance_api.dart';
import 'package:mobile/network/teacher_profile_api.dart';
import 'package:mobile/network/violation_report_api.dart';
import 'package:mobile/models/kasus_models.dart';
import 'package:mobile/widgets/school_ui.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/account_home_screen.dart';
import 'package:mobile/screens/profile_view.dart';
import 'package:mobile/screens/badge_collection.dart';
import 'package:mobile/screens/pembina_screen.dart';
import 'package:mobile/screens/kasus/kasus_list_screen.dart';
import 'package:mobile/screens/kasus/kasus_detail_screen.dart';
import 'package:mobile/screens/teacher/school_attendance_screen.dart';
import 'package:mobile/screens/teacher/manual_attendance_page.dart';
import 'package:mobile/screens/teacher/attendance_recap_screen.dart';
import 'package:mobile/screens/teacher/my_reports_screen.dart';
import 'package:mobile/screens/teacher/violation_report_screen.dart';
import 'package:mobile/screens/teacher/profile_screen.dart';
import 'package:mobile/screens/kasus/forms/verifikasi_form.dart';
import 'package:mobile/screens/kasus/forms/rencana_konseling_form.dart';
import 'package:mobile/screens/kasus/forms/catatan_konseling_form.dart';
import 'package:mobile/screens/kasus/forms/catatan_pembinaan_form.dart';
import 'package:mobile/screens/kasus/forms/tindak_lanjut_ortu_form.dart';
import 'package:mobile/screens/kasus/forms/pemantauan_form.dart';
import 'package:mobile/screens/kasus/forms/eskalasi_form.dart';
import 'package:mobile/screens/kasus/forms/tutup_kasus_form.dart';
import 'package:mobile/screens/kasus/forms/usulan_penutupan_eskalasi_form.dart';
import 'package:mobile/screens/parent/parent_achievements_badges_screen.dart';
import 'package:mobile/screens/parent/parent_attendance_screen.dart';
import 'package:mobile/screens/parent/parent_counseling_screen.dart';
import 'package:mobile/screens/parent/parent_extracurricular_screen.dart';
import 'package:mobile/screens/parent/parent_notifications_screen.dart';
import 'package:mobile/screens/student/achievements_screen.dart';
import 'package:mobile/screens/student/attendance_history_screen.dart';
import 'package:mobile/screens/student/counseling_status_screen.dart';
import 'package:mobile/screens/student/extracurricular_detail_screen.dart';
import 'package:mobile/screens/student/extracurricular_list_screen.dart';
import 'package:mobile/screens/student/notification_detail_screen.dart';
import 'package:mobile/screens/student/notifications_screen.dart';

class _Storage implements SessionStorage {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async {
    data = value;
  }
}

final _case = Kasus.fromJson({
  'id': 1,
  'sumber': 'LAPORAN',
  'nama_siswa': 'Siswa Pengujian',
  'kelas': 'XI 1',
  'kategori': 'Pembinaan kedisiplinan',
  'tanggal_laporan': '2026-11-25T01:00:00Z',
  'status': 'DALAM_PEMBINAAN',
  'pelapor': 'Guru Pengujian',
  'deskripsi': 'Informasi laporan yang diizinkan untuk penanganan.',
  'riwayat': [
    {
      'id': 1,
      'tanggal': '2026-11-25T02:00:00Z',
      'jenis': 'PEMBINAAN',
      'deskripsi': 'Pembinaan awal telah dilakukan.',
      'oleh': 'Wali Kelas',
    },
  ],
});
final _profile = AccountProfile.fromJson({
  'name': 'Guru Pengujian',
  'identitas_login': 'pengujian',
  'primary_role': 'GURU_BK',
  'duties': ['WALI_KELAS', 'PEMBINA_EKSTRAKURIKULER'],
  'available_roles': [
    'GURU',
    'GURU_BK',
    'WALI_KELAS',
    'PEMBINA_EKSTRAKURIKULER',
  ],
});
final _session = SchoolSession.fromJson({
  'id': 1,
  'jenis_sesi': 'PAGI',
  'status': 'AKTIF',
  'waktu_buka': '2026-11-25T00:00:00Z',
  'milik_saya': true,
  'ringkasan': {'total': 2, 'BELUM_DIISI': 2},
});
final _fixtures =
    jsonDecode(
          File(
            'test/fixtures/mobile_readonly_responses.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
AuthApi _api() => AuthApi(
  storage: _Storage(),
  client: MockClient((request) async {
    final path = request.url.path;
    final key = path.replaceFirst('/api/v1', '');
    if (_fixtures.containsKey(key)) {
      return http.Response(
        jsonEncode(_fixtures[key]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    Object? data;
    if (path.endsWith('/auth/login')) {
      data = {
        'access_token': 'test-access',
        'refresh_token': 'test-refresh',
        'user': {
          'name': 'Guru Pengujian',
          'identitas_login': 'pengujian',
          'available_roles': ['GURU', 'GURU_BK', 'WALI_KELAS'],
        },
      };
    } else if (path.endsWith('/rencana-konseling')) {
      data = {
        'id': 1,
        'id_kasus': 1,
        'tujuan': 'Pendampingan perkembangan siswa',
        'bentuk_kegiatan': 'Konseling individu',
        'jadwal': '2026-11-27T02:00:00Z',
        'rencana_tindak_lanjut': 'Evaluasi bersama wali kelas',
      };
    } else if (path.endsWith('/guru-bk/kasus/1') ||
        path.endsWith('/wali-kelas/kasus/1')) {
      data = {
        'id': 1,
        'nama_siswa': _case.namaSiswa,
        'kelas': _case.kelas,
        'kategori': _case.kategori,
        'tanggal_laporan': '2026-11-25T01:00:00Z',
        'status': 'DALAM_PEMBINAAN',
        'deskripsi': _case.deskripsi,
        'riwayat': [],
      };
    } else if (path.endsWith('/guru-bk/kasus') ||
        path.endsWith('/wali-kelas/kasus')) {
      data = [
        {
          'id': 1,
          'nama_siswa': _case.namaSiswa,
          'kelas': _case.kelas,
          'kategori': _case.kategori,
          'status': 'DALAM_PEMBINAAN',
        },
      ];
    } else if (path.endsWith('/guru/profil')) {
      data = {
        'nama': 'Guru Pengujian',
        'identitas_login': 'pengujian',
        'status_akun': 'AKTIF',
        'peran': ['Guru BK'],
        'wali_kelas': ['XI 1'],
        'pembina_ekstrakurikuler': ['Pramuka'],
      };
    } else if (path.endsWith('/guru/presensi/sesi')) {
      data = {'tanggal': '2026-11-25', 'sesi': []};
    } else if (path.endsWith('/guru/presensi/kelas') ||
        path.endsWith('/guru/presensi/sesi/1/kelas')) {
      data = [];
    } else if (path.endsWith('/pembina/kegiatan')) {
      data = {'activities': [], 'sessions_today': []};
    } else if (path.endsWith('/guru/pelanggaran/formulir')) {
      data = {'classes': [], 'categories': [], 'kelas': [], 'kategori': []};
    } else if (path.contains('/pembina/')) {
      data = [];
    } else {
      // Exercise the real retry state for screens whose business data belongs to another module.
      return http.Response(
        jsonEncode({
          'error': {'message': 'Data pengujian belum tersedia. Coba kembali.'},
        }),
        503,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      jsonEncode({'data': data}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

typedef _Builder = Widget Function(AuthApi api, KasusApi cases);
final _pages = <_Page>[
  _Page('Login', (api, cases) => LoginScreen(onLogin: (a, b) async {})),
  _Page(
    'BerandaGuru',
    (api, cases) =>
        AccountHomeScreen(api: api, profile: _profile, onLogout: () async {}),
  ),
  _Page(
    'BerandaSiswa',
    (api, cases) => AccountHomeScreen(
      api: api,
      profile: const AccountProfile('Siswa Contoh', 'contoh.siswa', [
        'SISWA',
      ], primaryRole: 'SISWA'),
      onLogout: () async {},
    ),
  ),
  _Page(
    'BerandaOrtu',
    (api, cases) => AccountHomeScreen(
      api: api,
      profile: const AccountProfile('Orang Tua Contoh', 'contoh.ortu', [
        'ORANG_TUA',
      ], primaryRole: 'ORANG_TUA'),
      onLogout: () async {},
    ),
  ),
  _Page(
    'Profil',
    (api, cases) =>
        ProfileView(profile: _profile, busy: false, onLogout: () async {}),
  ),
  _Page('Badge', (api, cases) => BadgeCollection(load: () async => [])),
  _Page(
    'KasusBK',
    (api, cases) => KasusListScreen(api: cases, role: 'GURU_BK'),
  ),
  _Page(
    'KasusWali',
    (api, cases) => KasusListScreen(
      api: KasusApi(api, role: 'WALI_KELAS'),
      role: 'WALI_KELAS',
    ),
  ),
  _Page(
    'DetailBK',
    (api, cases) => KasusDetailScreen(api: cases, kasusId: 1, role: 'GURU_BK'),
  ),
  _Page(
    'DetailWali',
    (api, cases) => KasusDetailScreen(
      api: KasusApi(api, role: 'WALI_KELAS'),
      kasusId: 1,
      role: 'WALI_KELAS',
    ),
  ),
  _Page(
    'SesiGuru',
    (api, cases) => SchoolAttendanceScreen(api: SchoolAttendanceApi(api)),
  ),
  _Page(
    'ManualGuru',
    (api, cases) =>
        ManualAttendancePage(api: SchoolAttendanceApi(api), session: _session),
  ),
  _Page(
    'RekapGuru',
    (api, cases) => AttendanceRecapScreen(api: AttendanceRecapApi(api)),
  ),
  _Page(
    'LaporanSaya',
    (api, cases) => MyReportsScreen(api: ViolationReportApi(api)),
  ),
  _Page(
    'LaporPelanggaran',
    (api, cases) =>
        ViolationReportScreen(api: ViolationReportApi(api), onOpenMine: () {}),
  ),
  _Page(
    'ProfilGuru',
    (api, cases) =>
        ProfileScreen(api: TeacherProfileApi(api), onLogout: () async {}),
  ),
  _Page(
    'Pembina',
    (api, cases) => PembinaHome(api: api, name: 'Guru Pengujian'),
  ),
  _Page(
    'KegiatanPembina',
    (api, cases) => PembinaActivityScreen(
      api: api,
      activity: const {'id': 1, 'nama': 'Pramuka'},
    ),
  ),
  _Page(
    'VerifikasiForm',
    (api, cases) => VerifikasiForm(api: cases, kasus: _case, onDone: () {}),
  ),
  _Page(
    'RencanaKonselingForm',
    (api, cases) =>
        RencanaKonselingForm(api: cases, kasus: _case, onDone: () {}),
  ),
  _Page(
    'CatatanKonselingForm',
    (api, cases) =>
        CatatanKonselingForm(api: cases, kasus: _case, onDone: () {}),
  ),
  _Page(
    'CatatanPembinaanForm',
    (api, cases) =>
        CatatanPembinaanForm(api: cases, kasus: _case, onDone: () {}),
  ),
  _Page(
    'TindakLanjutOrtuForm',
    (api, cases) =>
        TindakLanjutOrtuForm(api: cases, kasus: _case, onDone: () {}),
  ),
  _Page(
    'PemantauanForm',
    (api, cases) => PemantauanForm(
      api: cases,
      kasus: _case,
      onDone: () {},
      role: 'GURU_BK',
    ),
  ),
  _Page(
    'EskalasiForm',
    (api, cases) => EskalasiForm(api: cases, kasus: _case, onDone: () {}),
  ),
  _Page(
    'TutupKasusForm',
    (api, cases) => TutupKasusForm(api: cases, kasus: _case, onDone: () {}),
  ),
  _Page(
    'UsulanPenutupanEskalasiForm',
    (api, cases) =>
        UsulanPenutupanEskalasiForm(api: cases, kasus: _case, onDone: () {}),
  ),
  _Page('AchievementsScreen', (api, cases) => AchievementsScreen(api: api)),
  _Page(
    'AttendanceHistoryScreen',
    (api, cases) => AttendanceHistoryScreen(api: api),
  ),
  _Page(
    'CounselingStatusScreen',
    (api, cases) => CounselingStatusScreen(api: api),
  ),
  _Page(
    'ExtracurricularListScreen',
    (api, cases) => ExtracurricularListScreen(api: api),
  ),
  _Page(
    'ExtracurricularDetailScreen',
    (api, cases) => ExtracurricularDetailScreen(
      api: api,
      ekskulId: 1,
      name: 'Pramuka Contoh',
    ),
  ),
  _Page('NotificationsScreen', (api, cases) => NotificationsScreen(api: api)),
  _Page(
    'NotificationDetailScreen',
    (api, cases) => NotificationDetailScreen(api: api, notificationId: 1),
  ),
  _Page(
    'ParentAttendanceScreen',
    (api, cases) => ParentAttendanceScreen(api: api),
  ),
  _Page(
    'ParentAchievementsBadgesScreen',
    (api, cases) => ParentAchievementsBadgesScreen(api: api),
  ),
  _Page(
    'ParentCounselingScreen',
    (api, cases) => ParentCounselingScreen(api: api),
  ),
  _Page(
    'ParentExtracurricularScreen',
    (api, cases) => ParentExtracurricularScreen(api: api),
  ),
  _Page(
    'ParentNotificationsScreen',
    (api, cases) => ParentNotificationsScreen(api: api),
  ),
  _Page(
    'ParentNotificationDetailScreen',
    (api, cases) => ParentNotificationDetailScreen(api: api, notificationId: 1),
  ),
];

class _Page {
  const _Page(this.name, this.build);
  final String name;
  final _Builder build;
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String filename,
) async {
  final root = Platform.environment['PPSI_UI_CAPTURE_DIR'];
  if (root == null) return;
  await tester.runAsync(() async {
    final dir = Directory('$root/pages');
    await dir.create(recursive: true);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final picture = await boundary.toImage();
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${dir.path}/$filename.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

void main() {
  setUpAll(loadUiTestFonts);

  testWidgets(
    'shared success dialog reports acknowledgement and does not close a form on back',
    (tester) async {
      bool? confirmed;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  confirmed = await showSchoolSuccess(
                    context,
                    title: const Text('Tersimpan'),
                    content: const Text('Perubahan telah tersimpan.'),
                  );
                },
                child: const Text('Simpan contoh'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Simpan contoh'));
      await tester.pumpAndSettle();
      expect(find.byType(SchoolDialog), findsOneWidget);
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      await tester.tap(find.text('Simpan contoh'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
      expect(find.text('Simpan contoh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final page in _pages) {
    for (final width in [360.0, 390.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${page.name} at $width dp scale $scale', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 844);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final api = _api();
          addTearDown(api.close);
          await api.login('test', 'test');
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: appTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: page.build(api, KasusApi(api, role: 'GURU_BK')),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _capture(tester, key, '${page.name}-${width.toInt()}-$scale');
          final fields = find.byType(TextField);
          if (fields.evaluate().isNotEmpty) {
            final field = fields.first;
            await tester.ensureVisible(field);
            await tester.tap(field);
            await tester.pumpAndSettle();
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Keyboard must not overflow',
            );
            await _capture(
              tester,
              key,
              '${page.name}-${width.toInt()}-$scale-keyboard',
            );
            tester.view.resetViewInsets();
          }
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            final state = tester.state<ScrollableState>(scrollables.first);
            if (state.position.hasContentDimensions &&
                state.position.maxScrollExtent.isFinite) {
              state.position.jumpTo(state.position.maxScrollExtent);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await _capture(
                tester,
                key,
                '${page.name}-${width.toInt()}-$scale-bottom',
              );
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
      }
    }
  }
  testWidgets('long shared dialog scrolls with enlarged text and keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => SchoolDialog(
                    title: const Text('Konfirmasi perubahan'),
                    content: Text(
                      List.filled(
                        12,
                        'Periksa perubahan sebelum menyimpan.',
                      ).join(' '),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, key, 'Dialog-360-1.3');
  });
}
