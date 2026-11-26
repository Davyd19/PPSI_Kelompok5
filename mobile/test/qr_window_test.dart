import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/network/auth_api.dart';
import 'package:mobile/network/school_attendance_api.dart';
import 'package:mobile/screens/teacher/school_attendance_screen.dart';
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

http.Response _json(Object data) => http.Response(
  jsonEncode({'data': data}),
  200,
  headers: {'content-type': 'application/json'},
);
void main() {
  test(
    'new manual choices exclude late while retaining the historical label',
    () {
      expect(manualAttendanceStatuses.containsKey('TERLAMBAT'), isFalse);
      expect(
        classAttendanceOptions.keys,
        containsAll(['HADIR', 'IZIN', 'SAKIT', 'ALFA', 'PENGECUALIAN_SAH']),
      );
      expect(attendanceStatusLabels['TERLAMBAT'], contains('riwayat'));
    },
  );
  test(
    'QR scheduled/expired states follow server time, even with a wrong device clock',
    () {
      final token = QrToken.fromJson({
        'kode': 'same-code',
        'berlaku_mulai': '2026-11-26T07:00:00+07:00',
        'berlaku_sampai': '2026-11-26T08:00:00+07:00',
        'waktu_server': '2026-11-26T06:59:00+07:00',
      });
      expect(token.isScheduled, isTrue);
      expect(token.isActive, isFalse);
      final expired = QrToken.fromJson({
        'kode': 'same-code',
        'berlaku_mulai': '2026-11-26T07:00:00+07:00',
        'berlaku_sampai': '2026-11-26T08:00:00+07:00',
        'waktu_server': '2026-11-26T08:00:01+07:00',
      });
      expect(expired.isScheduled, isFalse);
      expect(expired.isActive, isFalse);
    },
  );
  testWidgets('small-screen QR create and edit reuse the WIB schedule form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now().toUtc();
    var exists = false;
    final bodies = <Map<String, dynamic>>[];
    final row = <String, dynamic>{
      'id': 1,
      'jenis_sesi': 'PAGI',
      'status': 'AKTIF',
      'waktu_buka': now.toIso8601String(),
      'qr_aktif_mulai': now
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
      'token_kedaluwarsa': now
          .add(const Duration(minutes: 15))
          .toIso8601String(),
      'milik_saya': true,
      'guru_pembuka': 'Guru Uji',
      'ringkasan': {'total': 1, 'BELUM_DIISI': 1},
    };
    Map<String, dynamic> qr() => {
      'kode': 'same-code',
      'berlaku_mulai': row['qr_aktif_mulai'],
      'berlaku_sampai': row['token_kedaluwarsa'],
      'waktu_server': DateTime.now().toUtc().toIso8601String(),
    };
    final auth = AuthApi(
      storage: _Memory(),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/auth/login')) {
          return _json({
            'access_token': 'unit-access',
            'refresh_token': 'unit-refresh',
            'user': {
              'name': 'Guru Uji',
              'identitas_login': 'unit',
              'primary_role': 'GURU',
              'available_roles': ['GURU'],
            },
          });
        }
        if (r.method == 'POST' && r.url.path.endsWith('/qr/berlaku')) {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          bodies.add(body);
          row['qr_aktif_mulai'] = body['qr_aktif_mulai'];
          row['token_kedaluwarsa'] = body['qr_aktif_sampai'];
          return _json(qr());
        }
        if (r.method == 'POST' && r.url.path.endsWith('/presensi/sesi')) {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          bodies.add(body);
          exists = true;
          row['qr_aktif_mulai'] = body['qr_aktif_mulai'];
          row['token_kedaluwarsa'] = body['qr_aktif_sampai'];
          return _json({'sesi': row, 'qr': qr()});
        }
        if (r.url.path.endsWith('/qr')) return _json(qr());
        return _json({
          'tanggal': now
              .add(const Duration(hours: 7))
              .toIso8601String()
              .substring(0, 10),
          'semester': {'id': 1},
          'sesi': exists ? [row] : [],
        });
      }),
    );
    addTearDown(auth.close);
    await auth.login('unit', 'unit');
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: SchoolAttendanceScreen(api: SchoolAttendanceApi(auth)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat QR Sesi').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Batas tepat waktu'), findsNothing);
    expect(find.textContaining('Mulai:'), findsOneWidget);
    expect(find.textContaining('Tutup:'), findsOneWidget);
    await tester.tap(find.text('Simpan Jadwal'));
    await tester.pumpAndSettle();
    expect(bodies, hasLength(1));
    expect(bodies.first.containsKey('berlaku_menit'), isFalse);
    expect(
      DateTime.parse(
        bodies.first['qr_aktif_sampai'] as String,
      ).isAfter(DateTime.parse(bodies.first['qr_aktif_mulai'] as String)),
      isTrue,
    );
    final edit = find.text('Ubah Jadwal');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Jadwal'));
    await tester.pumpAndSettle();
    expect(bodies, hasLength(2));
    expect(find.text('QR Presensi Pagi'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
