import 'auth_api.dart';
import '../models/kasus_models.dart';

/// Klien API modul "Kasus" (Laporan & Penanganan Kasus).
/// Berfungsi untuk Guru BK dan Wali Kelas.
/// Terhubung langsung ke backend API Node.js & database MySQL.
class KasusApi {
  KasusApi(this._api, {required this.role});
  final AuthApi _api;
  final String role;

  // ─── Daftar & Detail Kasus ───

  /// Ambil daftar kasus dari backend.
  /// Guru BK mengambil seluruh kasus sesuai kewenangan.
  /// Wali Kelas mengambil kasus siswa di kelas perwaliannya.
  Future<List<Kasus>> daftarKasus({String? filterStatus}) async {
    final path = role == 'GURU_BK' ? '/guru-bk/kasus' : '/wali-kelas/kasus';
    final query = filterStatus != null && filterStatus.isNotEmpty
        ? '?status=$filterStatus'
        : '';
    final rows = await _api.send('$path$query') as List;
    return rows
        .map((r) => Kasus.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Ambil detail kasus termasuk timeline riwayat penanganan lengkap.
  Future<Kasus> detailKasus(int id) async {
    final path = role == 'GURU_BK'
        ? '/guru-bk/kasus/$id'
        : '/wali-kelas/kasus/$id';
    final data = await _api.send(path) as Map<String, dynamic>;
    return Kasus.fromJson(data);
  }

  // ─── Verifikasi (Guru BK) ───

  Future<void> verifikasiTerima(int idKasus, String catatan) async {
    await _api.send(
      '/guru-bk/kasus/$idKasus/verifikasi',
      body: {'hasil': 'TERIMA', 'catatan': catatan},
    );
  }

  Future<void> verifikasiTolak(int idKasus, String catatan) async {
    await _api.send(
      '/guru-bk/kasus/$idKasus/verifikasi',
      body: {'hasil': 'TOLAK', 'catatan': catatan},
    );
  }

  // ─── Rencana Konseling (Guru BK) ───

  Future<RencanaKonseling?> getRencanaKonseling(int idKasus) async {
    final data = await _api.send('/guru-bk/kasus/$idKasus/rencana-konseling')
        as Map<String, dynamic>?;
    return data != null ? RencanaKonseling.fromJson(data) : null;
  }

  Future<void> simpanRencanaKonseling(
    int idKasus, {
    required String tujuan,
    required String bentukKegiatan,
    required DateTime jadwal,
    required String rencanaTindakLanjut,
  }) async {
    await _api.send(
      '/guru-bk/kasus/$idKasus/rencana-konseling',
      body: {
        'tujuan': tujuan,
        'bentuk_kegiatan': bentukKegiatan,
        'jadwal': jadwal.toIso8601String(),
        'rencana_tindak_lanjut': rencanaTindakLanjut,
      },
    );
  }

  // ─── Catatan Konseling & Asesmen (Guru BK) ───

  Future<void> simpanCatatanKonseling(
    int idKasus, {
    required String kondisiPermasalahan,
    required String hasilAsesmen,
    required String ringkasanKonseling,
    required String rencanaTindakLanjut,
  }) async {
    await _api.send(
      '/guru-bk/kasus/$idKasus/catatan-konseling',
      body: {
        'kondisi_permasalahan': kondisiPermasalahan,
        'hasil_asesmen': hasilAsesmen,
        'ringkasan_konseling': ringkasanKonseling,
        'rencana_tindak_lanjut': rencanaTindakLanjut,
      },
    );
  }

  // ─── Tindak Lanjut & Keterlibatan Orang Tua (Guru BK & Wali Kelas) ───

  Future<void> simpanTindakLanjutOrtu(
    int idKasus, {
    required String hasilKomunikasi,
    required DateTime tanggalKomunikasi,
    required String bentukKeterlibatan,
    required String rencanaTindakLanjut,
  }) async {
    final path = role == 'GURU_BK'
        ? '/guru-bk/kasus/$idKasus/tindak-lanjut-ortu'
        : '/wali-kelas/kasus/$idKasus/tindak-lanjut-ortu';
    await _api.send(
      path,
      body: {
        'hasil_komunikasi': hasilKomunikasi,
        'tanggal_komunikasi': tanggalKomunikasi.toIso8601String(),
        'bentuk_keterlibatan': bentukKeterlibatan,
        'rencana_tindak_lanjut': rencanaTindakLanjut,
      },
    );
  }

  // ─── Pemantauan Perkembangan (Guru BK & Wali Kelas) ───

  Future<void> tidakPerluTindakLanjut(int idKasus) async {
    final path = role == 'GURU_BK'
        ? '/guru-bk/kasus/$idKasus/pemantauan'
        : '/wali-kelas/kasus/$idKasus/pemantauan';
    await _api.send(path, body: {'keputusan': 'TIDAK_PERLU'});
  }

  Future<void> simpanTindakLanjutTambahan(
    int idKasus, {
    required String catatan,
  }) async {
    final path = role == 'GURU_BK'
        ? '/guru-bk/kasus/$idKasus/tindak-lanjut'
        : '/wali-kelas/kasus/$idKasus/tindak-lanjut';
    await _api.send(path, body: {'catatan': catatan});
  }

  // ─── Usulan Eskalasi / Rujukan (Guru BK) ───

  Future<void> usulkanEskalasi(
    int idKasus, {
    required String pihakTujuan,
    required String alasan,
    required String hasilEvaluasi,
    required String informasiPendukung,
  }) async {
    await _api.send(
      '/guru-bk/kasus/$idKasus/eskalasi',
      body: {
        'pihak_tujuan': pihakTujuan,
        'alasan': alasan,
        'hasil_evaluasi': hasilEvaluasi,
        'informasi_pendukung': informasiPendukung,
      },
    );
  }

  // ─── Tutup Kasus (Guru BK) ───

  Future<void> tutupKasus(
    int idKasus, {
    required String alasanPenutupan,
    required String catatanPendukung,
    required String catatanAkhir,
  }) async {
    await _api.send(
      '/guru-bk/kasus/$idKasus/tutup',
      body: {
        'alasan_penutupan': alasanPenutupan,
        'catatan_pendukung': catatanPendukung,
        'catatan_akhir': catatanAkhir,
      },
    );
  }

  // ─── Catatan Pembinaan (Wali Kelas) ───

  Future<void> simpanCatatanPembinaan(
    int idKasus, {
    required String hasilPembinaan,
    required String tindakanDiberikan,
    required String rencanaTindakLanjut,
  }) async {
    await _api.send(
      '/wali-kelas/kasus/$idKasus/catatan-pembinaan',
      body: {
        'hasil_pembinaan': hasilPembinaan,
        'tindakan_diberikan': tindakanDiberikan,
        'rencana_tindak_lanjut': rencanaTindakLanjut,
      },
    );
  }

  // ─── Usulan Penutupan/Eskalasi (Wali Kelas) ───

  Future<void> usulkanPenutupanAtauEskalasi(
    int idKasus, {
    required String jenisUsulan,
    required String alasan,
    required String catatanPendukung,
  }) async {
    await _api.send(
      '/wali-kelas/kasus/$idKasus/usulan',
      body: {
        'jenis_usulan': jenisUsulan,
        'alasan': alasan,
        'catatan_pendukung': catatanPendukung,
      },
    );
  }
}
