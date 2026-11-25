import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/kasus_models.dart';
import 'package:mobile/network/auth_api.dart';
import 'package:mobile/network/kasus_api.dart';
import 'package:mobile/screens/kasus/kasus_list_screen.dart';
import 'package:mobile/screens/kasus/forms/verifikasi_form.dart';
import 'package:mobile/screens/kasus/forms/rencana_konseling_form.dart';
import 'package:mobile/screens/kasus/forms/catatan_konseling_form.dart';
import 'package:mobile/screens/kasus/forms/tindak_lanjut_ortu_form.dart';
import 'package:mobile/screens/kasus/forms/catatan_pembinaan_form.dart';
import 'package:mobile/screens/kasus/forms/usulan_penutupan_eskalasi_form.dart';

class _FakeSessionStorage implements SessionStorage {
  String? _val;
  @override
  Future<String?> read() async => _val;
  @override
  Future<void> write(String value) async => _val = value;
}

void main() {
  late KasusApi bkApi;
  late KasusApi waliApi;
  final recordedRequests = <http.Request>[];

  setUp(() async {
    recordedRequests.clear();
    final mockClient = MockClient((request) async {
      recordedRequests.add(request);
      final p = request.url.path;

      // Login endpoint
      if (p.endsWith('/auth/login') && request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'data': {
              'access_token': 'fake-access-token',
              'refresh_token': 'fake-refresh-token',
              'expires_in': 900,
              'user': {
                'id': 2,
                'name': 'Guru Contoh',
                'identitas_login': 'contoh.guru',
                'available_roles': ['GURU', 'GURU_BK', 'WALI_KELAS'],
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      // GET /guru-bk/kasus or /wali-kelas/kasus
      if ((p.endsWith('/guru-bk/kasus') || p.endsWith('/wali-kelas/kasus')) &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 1,
                'nama_siswa': 'Andi Pratama',
                'kelas': 'X Contoh',
                'kategori': 'Terlambat Berulang',
                'tanggal_laporan': '2026-11-20T08:00:00.000Z',
                'status': 'MENUNGGU_VERIFIKASI',
                'deskripsi': 'Terlambat 5 kali',
                'pelapor': 'Pak Budi',
              },
              {
                'id': 2,
                'nama_siswa': 'Budi Santoso',
                'kelas': 'X Contoh',
                'kategori': 'Berkelahi',
                'tanggal_laporan': '2026-11-18T08:00:00.000Z',
                'status': 'DALAM_PEMBINAAN',
                'deskripsi': 'Berkelahi di kantin',
                'pelapor': 'Ibu Sari',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      // GET detail kasus
      if (RegExp(r'/kasus/\d+$').hasMatch(p) && request.method == 'GET') {
        final id = int.parse(request.url.pathSegments.last);
        return http.Response(
          jsonEncode({
            'data': {
              'id': id,
              'nama_siswa': id == 1 ? 'Andi Pratama' : 'Budi Santoso',
              'kelas': 'X Contoh',
              'kategori': 'Ketertiban',
              'tanggal_laporan': '2026-11-20T08:00:00.000Z',
              'status': id == 1 ? 'MENUNGGU_VERIFIKASI' : 'DALAM_PEMBINAAN',
              'deskripsi': 'Laporan deskripsi',
              'pelapor': 'Pak Budi',
              'riwayat': [
                {
                  'id': 1,
                  'tanggal': '2026-11-20T08:00:00.000Z',
                  'jenis': 'Laporan Masuk',
                  'deskripsi': 'Laporan diterima',
                  'oleh': 'Pak Budi',
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      // GET rencana konseling
      if (p.endsWith('/rencana-konseling') && request.method == 'GET') {
        if (p.contains('/kasus/1/')) {
          return http.Response(
            jsonEncode({'data': null}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'data': {
              'id': 10,
              'id_kasus': 2,
              'tujuan': 'Mengubah pola keterlambatan',
              'bentuk_kegiatan': 'KONSELING_INDIVIDU',
              'jadwal': '2026-12-01T09:00:00.000Z',
              'rencana_tindak_lanjut': 'Check in harian',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      // All POST mutations return { data: { success: true } }
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'data': {'success': true},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode({
          'error': {
            'code': 'NOT_FOUND',
            'message': 'Endpoint tidak ditemukan.',
          },
        }),
        404,
        headers: {'content-type': 'application/json'},
      );
    });

    final storage = _FakeSessionStorage();
    final authApi = AuthApi(client: mockClient, storage: storage);
    await authApi.login('contoh.guru', 'Contoh123!');
    bkApi = KasusApi(authApi, role: 'GURU_BK');
    waliApi = KasusApi(authApi, role: 'WALI_KELAS');
  });

  group('KasusApi real HTTP calls', () {
    test('daftarKasus sends GET and parses response', () async {
      final list = await bkApi.daftarKasus();
      expect(list.length, 2);
      expect(list[0].namaSiswa, 'Andi Pratama');
      expect(list[0].status, StatusKasus.menungguVerifikasi);
      expect(
        recordedRequests.any((r) => r.url.path.contains('/guru-bk/kasus')),
        isTrue,
      );
    });

    test('detailKasus sends GET and parses detail with riwayat', () async {
      final k = await bkApi.detailKasus(1);
      expect(k.id, 1);
      expect(k.namaSiswa, 'Andi Pratama');
      expect(k.riwayat.length, 1);
      expect(k.riwayat[0].jenis, 'Laporan Masuk');
    });

    test(
      'verifikasiTerima sends POST /guru-bk/kasus/1/verifikasi with payload',
      () async {
        await bkApi.verifikasiTerima(1, 'Catatan verifikasi valid');
        final req = recordedRequests.firstWhere(
          (r) => r.url.path.endsWith('/verifikasi'),
        );
        expect(req.method, 'POST');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['hasil'], 'TERIMA');
        expect(body['catatan'], 'Catatan verifikasi valid');
      },
    );

    test('simpanRencanaKonseling sends POST with full plan data', () async {
      await bkApi.simpanRencanaKonseling(
        1,
        tujuan: 'Mengendalikan emosi',
        bentukKegiatan: 'Konseling individu',
        jadwal: DateTime(2026, 12, 1, 9),
        rencanaTindakLanjut: 'Evaluasi mingguan',
      );
      final req = recordedRequests.firstWhere(
        (r) => r.url.path.endsWith('/rencana-konseling'),
      );
      expect(req.method, 'POST');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['tujuan'], 'Mengendalikan emosi');
      expect(body['bentuk_kegiatan'], 'Konseling individu');
      expect(body['rencana_tindak_lanjut'], 'Evaluasi mingguan');
    });

    test('simpanCatatanKonseling sends POST to /catatan-konseling', () async {
      await bkApi.simpanCatatanKonseling(
        1,
        kondisiPermasalahan: 'Sering begadang',
        hasilAsesmen: 'Kurang disiplin tidur',
        ringkasanKonseling: 'Siswa sepakat tidur teratur',
        rencanaTindakLanjut: 'Cek presensi pekan depan',
      );
      final req = recordedRequests.firstWhere(
        (r) => r.url.path.endsWith('/catatan-konseling'),
      );
      expect(req.method, 'POST');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['kondisi_permasalahan'], 'Sering begadang');
    });

    test('simpanTindakLanjutOrtu sends POST to /tindak-lanjut-ortu', () async {
      await bkApi.simpanTindakLanjutOrtu(
        1,
        hasilKomunikasi: 'Orang tua menyetujui',
        tanggalKomunikasi: DateTime(2026, 11, 25),
        bentukKeterlibatan: 'Panggilan Sekolah',
        rencanaTindakLanjut: 'Memonitor di rumah',
      );
      final req = recordedRequests.firstWhere(
        (r) => r.url.path.endsWith('/tindak-lanjut-ortu'),
      );
      expect(req.method, 'POST');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['bentuk_keterlibatan'], 'Panggilan Sekolah');
    });

    test('eskalasi sends POST to /eskalasi', () async {
      await bkApi.usulkanEskalasi(
        1,
        pihakTujuan: 'Kepala Sekolah',
        alasan: 'Butuh mediasi pimpinan',
        hasilEvaluasi: 'Belum ada progres',
        informasiPendukung: 'Dokumen bukti',
      );
      final req = recordedRequests.firstWhere(
        (r) => r.url.path.endsWith('/eskalasi'),
      );
      expect(req.method, 'POST');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['pihak_tujuan'], 'Kepala Sekolah');
    });

    test('tutupKasus sends POST to /tutup', () async {
      await bkApi.tutupKasus(
        1,
        alasanPenutupan: 'Target tercapai',
        catatanPendukung: 'Kehadiran 100%',
        catatanAkhir: 'Kasus selesai',
      );
      final req = recordedRequests.firstWhere(
        (r) => r.url.path.endsWith('/tutup'),
      );
      expect(req.method, 'POST');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['alasan_penutupan'], 'Target tercapai');
    });

    test('Wali Kelas simpanCatatanPembinaan sends POST', () async {
      await waliApi.simpanCatatanPembinaan(
        1,
        hasilPembinaan: 'Siswa ditegur',
        tindakanDiberikan: 'Tugas refleksi',
        rencanaTindakLanjut: 'Cek esok hari',
      );
      final req = recordedRequests.firstWhere(
        (r) => r.url.path.contains('/catatan-pembinaan'),
      );
      expect(req.method, 'POST');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['hasil_pembinaan'], 'Siswa ditegur');
    });

    test(
      'Wali Kelas usulanPenutupanAtauEskalasi sends POST to /usulan',
      () async {
        await waliApi.usulkanPenutupanAtauEskalasi(
          1,
          jenisUsulan: 'PENUTUPAN',
          alasan: 'Siswa sudah tertib',
          catatanPendukung: 'Catatan mapel lengkap',
        );
        final req = recordedRequests.firstWhere(
          (r) => r.url.path.endsWith('/usulan'),
        );
        expect(req.method, 'POST');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['jenis_usulan'], 'PENUTUPAN');
      },
    );

    test('Server error throws AuthError with server message', () async {
      final errorClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'data': {
                'access_token': 'tok',
                'refresh_token': 'ref',
                'expires_in': 900,
                'user': {
                  'id': 2,
                  'name': 'Guru',
                  'identitas_login': 'guru',
                  'available_roles': ['GURU_BK'],
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Pesan error asli dari backend.',
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });
      final errAuth = AuthApi(
        client: errorClient,
        storage: _FakeSessionStorage(),
      );
      await errAuth.login('guru', 'pass');
      final errorApi = KasusApi(errAuth, role: 'GURU_BK');

      expect(
        () => errorApi.verifikasiTerima(1, 'catatan'),
        throwsA(
          isA<AuthError>().having(
            (e) => e.message,
            'message',
            'Pesan error asli dari backend.',
          ),
        ),
      );
    });
  });

  group('UI Widgets & Forms Validation', () {
    testWidgets('KasusListScreen displays badge status and student names', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: KasusListScreen(api: bkApi, role: 'GURU_BK'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Laporan & Penanganan Kasus'), findsOneWidget);
      expect(find.text('Menunggu Verifikasi'), findsWidgets);
      expect(find.text('Andi Pratama'), findsOneWidget);
    });

    testWidgets('VerifikasiForm validates empty notes', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final kasus = await bkApi.detailKasus(1);
      await tester.pumpWidget(
        MaterialApp(
          home: VerifikasiForm(api: bkApi, kasus: kasus, onDone: () {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terima'));
      await tester.pumpAndSettle();

      expect(find.text('Catatan verifikasi wajib diisi.'), findsOneWidget);
    });

    testWidgets('RencanaKonselingForm validates required fields', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final kasus = await bkApi.detailKasus(1);
      await tester.pumpWidget(
        MaterialApp(
          home: RencanaKonselingForm(api: bkApi, kasus: kasus, onDone: () {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan Rencana'));
      await tester.pumpAndSettle();

      expect(find.text('Tujuan konseling wajib diisi.'), findsOneWidget);
      expect(find.text('Bentuk kegiatan wajib diisi.'), findsOneWidget);
      expect(find.text('Rencana tindak lanjut wajib diisi.'), findsOneWidget);
    });

    testWidgets(
      'RencanaKonselingForm opens date picker even when existing schedule is in the past',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final kasus = await bkApi.detailKasus(2);
        await tester.pumpWidget(
          MaterialApp(
            home: RencanaKonselingForm(api: bkApi, kasus: kasus, onDone: () {}),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ubah'));
        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsOneWidget);
      },
    );

    testWidgets('CatatanKonselingForm validates required fields', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final kasus = await bkApi.detailKasus(1);
      await tester.pumpWidget(
        MaterialApp(
          home: CatatanKonselingForm(api: bkApi, kasus: kasus, onDone: () {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan Catatan Konseling'));
      await tester.pumpAndSettle();

      expect(find.text('Kondisi permasalahan wajib diisi.'), findsOneWidget);
      expect(find.text('Hasil asesmen wajib diisi.'), findsOneWidget);
      expect(find.text('Ringkasan konseling wajib diisi.'), findsOneWidget);
      expect(find.text('Rencana tindak lanjut wajib diisi.'), findsOneWidget);
    });

    testWidgets('TindakLanjutOrtuForm validates required fields', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final kasus = await bkApi.detailKasus(1);
      await tester.pumpWidget(
        MaterialApp(
          home: TindakLanjutOrtuForm(api: bkApi, kasus: kasus, onDone: () {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan Tindak Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('Hasil komunikasi wajib diisi.'), findsOneWidget);
      expect(find.text('Bentuk keterlibatan wajib dipilih.'), findsOneWidget);
      expect(find.text('Rencana tindak lanjut wajib diisi.'), findsOneWidget);
    });

    testWidgets('CatatanPembinaanForm validates required fields (Wali Kelas)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final kasus = await waliApi.detailKasus(1);
      await tester.pumpWidget(
        MaterialApp(
          home: CatatanPembinaanForm(api: waliApi, kasus: kasus, onDone: () {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan Catatan'));
      await tester.pumpAndSettle();

      expect(find.text('Hasil pembinaan wajib diisi.'), findsOneWidget);
      expect(find.text('Tindakan yang diberikan wajib diisi.'), findsOneWidget);
      expect(find.text('Rencana tindak lanjut wajib diisi.'), findsOneWidget);
    });

    testWidgets(
      'UsulanPenutupanEskalasiForm validates required fields (Wali Kelas)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final kasus = await waliApi.detailKasus(1);
        await tester.pumpWidget(
          MaterialApp(
            home: UsulanPenutupanEskalasiForm(
              api: waliApi,
              kasus: kasus,
              onDone: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Kirim Usulan'));
        await tester.pumpAndSettle();

        expect(find.text('Jenis usulan wajib dipilih.'), findsOneWidget);
        expect(find.text('Alasan usulan wajib diisi.'), findsOneWidget);
        expect(find.text('Catatan pendukung wajib diisi.'), findsOneWidget);
      },
    );
  });
}
