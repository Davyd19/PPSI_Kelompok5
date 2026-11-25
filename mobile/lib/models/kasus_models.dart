// Model data untuk modul Kasus (Laporan & Penanganan Kasus).
// Digunakan oleh Guru BK dan Wali Kelas.

/// Status kasus yang menentukan warna badge.
enum StatusKasus {
  menungguVerifikasi('Menunggu Verifikasi'),
  dalamPembinaan('Dalam Pembinaan'),
  rencanaKonselingAktif('Rencana Konseling Aktif'),
  dirujukEskalasi('Dirujuk / Eskalasi'),
  selesaiDitutup('Selesai / Ditutup');

  const StatusKasus(this.label);
  final String label;

  static StatusKasus fromString(String value) => switch (value) {
    'MENUNGGU_VERIFIKASI' => menungguVerifikasi,
    'DALAM_PEMBINAAN' => dalamPembinaan,
    'RENCANA_KONSELING_AKTIF' => rencanaKonselingAktif,
    'DIRUJUK_ESKALASI' => dirujukEskalasi,
    'SELESAI_DITUTUP' => selesaiDitutup,
    _ => menungguVerifikasi,
  };

  String get apiValue => switch (this) {
    menungguVerifikasi => 'MENUNGGU_VERIFIKASI',
    dalamPembinaan => 'DALAM_PEMBINAAN',
    rencanaKonselingAktif => 'RENCANA_KONSELING_AKTIF',
    dirujukEskalasi => 'DIRUJUK_ESKALASI',
    selesaiDitutup => 'SELESAI_DITUTUP',
  };
}

/// Satu kasus siswa beserta laporan pelanggarannya.
class Kasus {
  const Kasus({
    required this.id,
    this.sumber = 'LAPORAN',
    required this.namaSiswa,
    required this.kelas,
    required this.kategori,
    required this.tanggalLaporan,
    required this.status,
    this.deskripsi,
    this.tempatKejadian,
    this.pelapor,
    this.catatanVerifikasi,
    this.riwayat = const [],
  });

  factory Kasus.fromJson(Map<String, dynamic> json) => Kasus(
    id: json['id'] as int,
    sumber: json['sumber'] as String? ?? 'LAPORAN',
    namaSiswa: json['nama_siswa'] as String? ?? '-',
    kelas: json['kelas'] as String? ?? '-',
    kategori: json['kategori'] as String? ?? '-',
    tanggalLaporan:
        DateTime.tryParse(
          json['tanggal_laporan'] as String? ?? '',
        )?.toLocal() ??
        DateTime.now(),
    status: StatusKasus.fromString(json['status'] as String? ?? ''),
    deskripsi: json['deskripsi'] as String?,
    tempatKejadian: json['tempat_kejadian'] as String?,
    pelapor: json['pelapor'] as String?,
    catatanVerifikasi: json['catatan_verifikasi'] as String?,
    riwayat:
        (json['riwayat'] as List?)
            ?.map((e) => RiwayatPenanganan.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  final int id;
  final String sumber;
  final String namaSiswa;
  final String kelas;
  final String kategori;
  final DateTime tanggalLaporan;
  final StatusKasus status;
  final String? deskripsi;
  final String? tempatKejadian;
  final String? pelapor;
  final String? catatanVerifikasi;
  final List<RiwayatPenanganan> riwayat;

  Kasus copyWith({StatusKasus? status, List<RiwayatPenanganan>? riwayat}) =>
      Kasus(
        id: id,
        sumber: sumber,
        namaSiswa: namaSiswa,
        kelas: kelas,
        kategori: kategori,
        tanggalLaporan: tanggalLaporan,
        status: status ?? this.status,
        deskripsi: deskripsi,
        tempatKejadian: tempatKejadian,
        pelapor: pelapor,
        catatanVerifikasi: catatanVerifikasi,
        riwayat: riwayat ?? this.riwayat,
      );
}

/// Satu entri riwayat penanganan kasus.
class RiwayatPenanganan {
  const RiwayatPenanganan({
    required this.id,
    required this.tanggal,
    required this.jenis,
    required this.deskripsi,
    required this.oleh,
  });

  factory RiwayatPenanganan.fromJson(Map<String, dynamic> json) =>
      RiwayatPenanganan(
        id: json['id'] as int? ?? 0,
        tanggal:
            DateTime.tryParse(json['tanggal'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        jenis: json['jenis'] as String? ?? '',
        deskripsi: json['deskripsi'] as String? ?? '',
        oleh: json['oleh'] as String? ?? '',
      );

  final int id;
  final DateTime tanggal;
  final String jenis;
  final String deskripsi;
  final String oleh;
}

/// Rencana konseling siswa.
class RencanaKonseling {
  const RencanaKonseling({
    required this.id,
    required this.idKasus,
    required this.tujuan,
    required this.bentukKegiatan,
    required this.jadwal,
    required this.rencanaTindakLanjut,
  });

  factory RencanaKonseling.fromJson(Map<String, dynamic> json) =>
      RencanaKonseling(
        id: json['id'] as int? ?? 0,
        idKasus: json['id_kasus'] as int? ?? 0,
        tujuan: json['tujuan'] as String? ?? '',
        bentukKegiatan: json['bentuk_kegiatan'] as String? ?? '',
        jadwal:
            DateTime.tryParse(json['jadwal'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        rencanaTindakLanjut: json['rencana_tindak_lanjut'] as String? ?? '',
      );

  final int id;
  final int idKasus;
  final String tujuan;
  final String bentukKegiatan;
  final DateTime jadwal;
  final String rencanaTindakLanjut;
}
