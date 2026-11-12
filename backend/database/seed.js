require('../src/config/env');
const {
  sequelize,
  models
} = require('../src/models');
const {
  hashPassword
} = require('../src/utils/security');
const mode = process.argv[2];
async function main() {
  if (!['required', 'development'].includes(mode)) throw new Error('Gunakan seed required atau development.');
  if (!['development', 'test'].includes(process.env.NODE_ENV || 'development')) throw new Error('Seed contoh hanya untuk development dan test.');
  const hash = await hashPassword('Contoh123!');
  await sequelize.transaction(async t => {
    async function add(key, where, defaults) {
      const [row] = await models[key].unscoped().findOrCreate({
        where,
        defaults: {
          ...defaults,
          ...where
        },
        transaction: t
      });
      return row;
    }
    {
      const rs = {};
      for (const [kode, nama] of [['ADMIN', 'Admin'], ['KESISWAAN', 'Kesiswaan'], ['KEPALA_SEKOLAH', 'Kepala Sekolah'], ['GURU_BK', 'Guru BK']]) rs[kode] = await add('peran', {
        kode
      }, {
        nama
      });
      const login = 'contoh.admin';
      for (const k of ['siswa', 'orang_tua']) if (await models[k].findOne({
        where: {
          identitas_login: login
        },
        transaction: t
      })) throw new Error('Identitas Admin sudah dipakai jenis akun lain.');
      const guru = await add('guru', {
        identitas_login: login
      }, {
        nama: 'Administrator Sekolah',
        hash_kata_sandi: hash,
        status_akun: 'AKTIF'
      });
      await add('guru_peran', {
        id_guru: guru.id,
        id_peran: rs.ADMIN.id,
        tanggal_mulai: '2026-01-01'
      }, {
        tanggal_selesai: null
      });
      if (mode === 'required') return;
    }
    const adminRole = await models.peran.findOne({
      where: {
        kode: 'ADMIN'
      },
      transaction: t
    });
    if (!adminRole) throw new Error('Jalankan seed wajib dahulu.');
    const guru = await add('guru', {
      identitas_login: 'contoh.guru'
    }, {
      nama: 'Guru Contoh',
      hash_kata_sandi: hash,
      status_akun: 'AKTIF',
      email: 'guru@example.invalid'
    });
    for (const kode of ['KESISWAAN', 'GURU_BK', 'KEPALA_SEKOLAH']) {
      const role = await models.peran.findOne({
        where: {
          kode
        },
        transaction: t
      });
      await add('guru_peran', {
        id_guru: guru.id,
        id_peran: role.id,
        tanggal_mulai: '2026-07-01'
      }, {
        tanggal_selesai: null
      });
    }
    const siswa = await add('siswa', {
      identitas_login: 'contoh.siswa'
    }, {
      nama: 'Siswa Contoh',
      nisn: '0099990001',
      nis: '90001',
      hash_kata_sandi: hash,
      status_siswa: 'AKTIF',
      status_akun: 'AKTIF'
    });
    const ortu = await add('orang_tua', {
      identitas_login: 'contoh.ortu'
    }, {
      nama: 'Orang Tua Contoh',
      hash_kata_sandi: hash,
      status_akun: 'AKTIF'
    });
    await add('hubungan', {
      id_orang_tua: ortu.id,
      id_siswa: siswa.id,
      tanggal_mulai: '2026-07-01'
    }, {
      jenis_hubungan: 'WALI',
      tanggal_selesai: null
    });
    const tahun = await add('tahun', {
      nama: '2026/2027'
    }, {
      tanggal_mulai: '2026-07-01',
      tanggal_selesai: '2027-06-30',
      aktif: !(await models.tahun.count({
        where: {
          aktif: true
        },
        transaction: t
      }))
    });
    const semester = await add('semester', {
      id_tahun_ajaran: tahun.id,
      nama: 'Ganjil'
    }, {
      tanggal_mulai: '2026-07-01',
      tanggal_selesai: '2026-12-31'
    });
    const next = await add('semester', {
      id_tahun_ajaran: tahun.id,
      nama: 'Genap'
    }, {
      tanggal_mulai: '2027-01-01',
      tanggal_selesai: '2027-06-30'
    });
    const kelas = await add('kelas', {
      id_tahun_ajaran: tahun.id,
      nama: 'X Contoh'
    }, {
      tingkat: 'X',
      status: 'AKTIF'
    });
    await add('riwayat_kelas', {
      id_siswa: siswa.id,
      id_kelas: kelas.id,
      tanggal_mulai: '2026-07-01'
    }, {
      tanggal_selesai: null
    });
    await add('wali', {
      id_guru: guru.id,
      id_kelas: kelas.id,
      tanggal_mulai: '2026-07-01'
    }, {
      tanggal_selesai: null
    });
    const sesi = await add('sesi', {
      id_semester: semester.id,
      jenis_sesi: 'PAGI',
      tanggal: '2026-10-22'
    }, {
      id_guru_pembuka: guru.id,
      waktu_buka: new Date('2026-10-21T23:30:00Z'),
      waktu_tutup: new Date('2026-10-22T01:00:00Z'),
      batas_tepat_waktu: new Date('2026-10-22T00:15:00Z'),
      status: 'DITUTUP'
    });
    await add('presensi', {
      id_sesi_presensi_sekolah: sesi.id,
      id_siswa: siswa.id
    }, {
      id_guru_pencatat: guru.id,
      status_kehadiran: 'HADIR',
      waktu_presensi: new Date('2026-10-22T00:00:00Z'),
      metode: 'MANUAL',
      keterangan: 'Data contoh pengembangan'
    });
    const ekskul = await add('ekskul', {
      nama: 'Pramuka Contoh'
    }, {
      deskripsi: 'Kegiatan contoh untuk pengembangan',
      status: 'AKTIF'
    });
    const periode = await add('periode_ekskul', {
      id_ekstrakurikuler: ekskul.id,
      id_tahun_ajaran: tahun.id
    }, {
      kapasitas: 30,
      status_pendaftaran: 'DIBUKA',
      status_kegiatan: 'AKTIF',
      pendaftaran_mulai: '2026-07-01',
      pendaftaran_selesai: '2026-12-31'
    });
    await add('pembina', {
      id_guru: guru.id,
      id_periode_ekstrakurikuler: periode.id,
      tanggal_mulai: '2026-07-01'
    }, {
      tanggal_selesai: null
    });
    await add('pendaftaran', {
      id_siswa: siswa.id,
      id_periode_ekstrakurikuler: periode.id,
      tanggal_daftar: new Date('2026-07-03T03:00:00Z')
    }, {
      status_keputusan: 'DITERIMA',
      id_guru_pemeriksa: guru.id,
      tanggal_keputusan: new Date('2026-07-04T03:00:00Z'),
      alasan: 'Contoh pendaftaran diterima'
    });
    const anggota = await add('anggota', {
      id_siswa: siswa.id,
      id_periode_ekstrakurikuler: periode.id
    }, {});
    await add('masa', {
      id_keanggotaan_ekstrakurikuler: anggota.id,
      tanggal_mulai: '2026-07-04'
    }, {
      tanggal_selesai: null
    });
    const pertemuan = await add('pertemuan', {
      id_periode_ekstrakurikuler: periode.id,
      tanggal: '2026-10-22',
      jam_mulai: '15:00:00'
    }, {
      jam_selesai: '16:30:00',
      lokasi: 'Lapangan sekolah',
      agenda: 'Latihan contoh',
      status_pertemuan: 'SELESAI',
      status_presensi: 'DITUTUP',
      id_guru_pembuka: guru.id,
      waktu_buka: new Date('2026-10-22T08:00:00Z'),
      id_guru_penutup: guru.id,
      waktu_tutup: new Date('2026-10-22T09:30:00Z')
    });
    await add('presensi_ekskul', {
      id_pertemuan_ekstrakurikuler: pertemuan.id,
      id_keanggotaan_ekstrakurikuler: anggota.id
    }, {
      id_guru_pencatat: guru.id,
      status_kehadiran: 'HADIR',
      waktu_pencatatan: new Date('2026-10-22T08:05:00Z')
    });
    const portfolio = await add('portofolio', {
      judul: 'Prestasi Tim Contoh',
      id_guru_pencatat: guru.id
    }, {
      id_periode_ekstrakurikuler: periode.id,
      jenis: 'PRESTASI',
      tanggal: '2026-10-22',
      tingkat_prestasi: 'SEKOLAH',
      hasil_prestasi: 'Juara contoh',
      nama_tim: 'Tim Contoh'
    });
    await add('peserta', {
      id_portofolio: portfolio.id,
      id_siswa: siswa.id
    }, {});
    await add('lampiran', {
      lokasi_berkas: 'seed://contoh-portofolio'
    }, {
      id_portofolio: portfolio.id,
      nama_berkas: 'contoh.txt',
      jenis_berkas: 'text/plain',
      waktu_unggah: new Date('2026-10-22T10:00:00Z')
    });
    const kategori = await add('kategori', {
      nama: 'Ketertiban Contoh'
    }, {
      deskripsi: 'Contoh tanpa poin atau sanksi otomatis',
      status: 'AKTIF'
    });
    const aturan = await add('aturan', {
      id_kategori_pelanggaran: kategori.id,
      nomor_versi: 1
    }, {
      ketentuan: 'Pendekatan pembinaan sesuai kewenangan',
      berlaku_mulai: '2026-07-01',
      berlaku_sampai: null
    });
    const penanganan = await add('penanganan', {
      id_siswa: siswa.id,
      alasan_pembukaan: 'Pendampingan contoh pengembangan'
    }, {
      id_guru_bk_penanggung_jawab: guru.id,
      tanggal_dibuka: '2026-10-22',
      sumber_pengajuan: 'WALI_KELAS',
      status: 'TERBUKA',
      ringkasan_diizinkan: 'Pendampingan sedang berjalan.'
    });
    const laporan = await add('laporan', {
      id_siswa: siswa.id,
      uraian: 'Laporan contoh pengembangan'
    }, {
      id_versi_aturan_penanganan: aturan.id,
      id_guru_pelapor: guru.id,
      waktu_kejadian: new Date('2026-10-22T00:30:00Z'),
      status_verifikasi: 'TERVERIFIKASI',
      id_guru_pemeriksa: guru.id,
      waktu_verifikasi: new Date('2026-10-22T02:00:00Z'),
      hasil_verifikasi: 'Contoh terverifikasi',
      status_tindak_lanjut: 'DALAM_PENANGANAN',
      id_penanganan_siswa: penanganan.id
    });
    const rencana = await add('rencana', {
      id_penanganan_siswa: penanganan.id,
      tujuan: 'Tujuan konseling contoh'
    }, {
      id_guru_penyusun: guru.id,
      bentuk_kegiatan: 'KONSELING_INDIVIDU',
      jadwal: new Date('2026-11-10T02:00:00Z'),
      rencana_tindak_lanjut: 'Evaluasi berikutnya',
      status: 'DIRENCANAKAN'
    });
    await add('riwayat', {
      id_penanganan_siswa: penanganan.id,
      jenis: 'ASESMEN',
      isi_internal: 'Catatan privat contoh, bukan data siswa nyata.'
    }, {
      id_laporan_pelanggaran: null,
      id_rencana_konseling: rencana.id,
      id_guru_pencatat: guru.id,
      waktu: new Date('2026-10-22T03:00:00Z'),
      ringkasan_diizinkan: 'Asesmen awal telah dilakukan.',
      orang_tua_dilibatkan: false
    });
    const badge = await add('badge', {
      nama: 'Rajin Contoh'
    }, {
      deskripsi: 'Contoh badge otomatis dari data kehadiran',
      status: 'AKTIF'
    });
    const versi = await add('versi_badge', {
      id_badge: badge.id,
      nomor_versi: 1
    }, {
      id_semester_mulai: semester.id,
      id_semester_selesai: semester.id,
      status: 'AKTIF'
    });
    const level = await add('level', {
      id_versi_aturan_badge: versi.id,
      urutan: 1
    }, {
      nama: 'Pemula',
      sumber_data: 'PRESENSI_SEKOLAH',
      cara_hitung: 'AKUMULASI',
      target: 1,
      jenis_presensi: 'PAGI',
      status_kehadiran_yang_dihitung: 'HADIR',
      cakupan_perhitungan: 'SEMESTER'
    });
    await add('pencapaian', {
      id_siswa: siswa.id,
      id_level_badge: level.id
    }, {
      waktu_diperoleh: new Date('2026-10-22T01:00:00Z')
    });
    await add('versi_badge', {
      id_badge: badge.id,
      nomor_versi: 2
    }, {
      id_semester_mulai: next.id,
      status: 'NONAKTIF'
    });
    const notif = await add('notifikasi', {
      jenis: 'CONTOH',
      judul: 'Selamat datang — data contoh'
    }, {
      isi: 'Seluruh data ini fiktif untuk pengembangan tim.',
      waktu_dibuat: new Date('2026-10-22T03:00:00Z')
    });
    await add('penerima', {
      id_notifikasi: notif.id,
      id_siswa: siswa.id
    }, {});
    const audit = await add('audit', {
      jenis_tindakan: 'SEED_CONTOH',
      nama_tabel: 'laporan_pelanggaran',
      identitas_data: String(laporan.id)
    }, {
      id_guru: guru.id,
      waktu: new Date('2026-10-22T03:00:00Z'),
      alasan: 'Seed pengembangan eksplisit'
    });
    await add('detail_audit', {
      id_audit_perubahan: audit.id,
      nama_atribut: 'uraian'
    }, {
      nilai_sebelum: null,
      nilai_sesudah: 'Laporan contoh pengembangan'
    });
  });
  console.log(mode === 'required' ? 'Seed wajib selesai. Akun dan kata sandi yang sudah ada tidak ditimpa.' : 'Seed contoh selesai; tidak ada data pengguna yang ditimpa.');
}
main().catch(e => {
  console.error(e.name?.startsWith('Sequelize') ? 'Seed gagal. Periksa migrasi dan konflik data; transaksi dibatalkan.' : e.message);
  process.exitCode = 1;
}).finally(() => sequelize.close());
