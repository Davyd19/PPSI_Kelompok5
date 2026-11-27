const { QueryTypes } = require('sequelize');
const { sequelize } = require('../models');
const { today } = require('./auth.controller');
const fail = require('../utils/api-error');
const { date, id, invalid } = require('./kesiswaan.controller').validation;

const select = (sql, replacements = {}) => sequelize.query(sql, { type: QueryTypes.SELECT, replacements });
const n = v => Number(v || 0);
const pct = (a, b) => (b ? Math.round(a / b * 1000) / 10 : null);

exports.guard = (req, res, next) => {
  if (req.authPlatform !== 'web' || req.user.primary_role !== 'KEPALA_SEKOLAH') {
    throw fail(403, 'FORBIDDEN', 'Fitur ini hanya dapat diakses Kepala Sekolah aktif.');
  }
  res.set('Cache-Control', 'no-store');
  next();
};
function range(req) {
  const end = req.query.sampai === undefined ? today() : date(req.query.sampai, 'Tanggal akhir');
  const start = req.query.mulai === undefined ? new Date(Date.parse(end) - 29 * 86400000).toISOString().slice(0, 10) : date(req.query.mulai, 'Tanggal awal');
  if (start > end || (Date.parse(end) - Date.parse(start)) / 86400000 > 366) throw invalid('Rentang tanggal tidak valid atau lebih dari 367 hari.');
  const tingkat = req.query.tingkat ?? null;
  if (tingkat !== null && !['X', 'XI', 'XII'].includes(tingkat)) throw invalid('Tingkat kelas tidak valid.');
  return { start, end, tingkat };
}

// Kehadiran sekolah: hanya sesi berstatus DITUTUP; yang belum diisi dihitung BELUM_DIISI (tidak dianggap hadir).
const attendanceCte = `SELECT ss.id AS id_sesi, ss.tanggal, ss.jenis_sesi, c.tingkat, s.id AS id_siswa,
    COALESCE(p.status_kehadiran,'BELUM_DIISI') AS status
  FROM sesi_presensi_sekolah ss JOIN semester sm ON sm.id=ss.id_semester
  JOIN kelas c ON c.id_tahun_ajaran=sm.id_tahun_ajaran
  JOIN riwayat_kelas_siswa r ON r.id_kelas=c.id AND r.tanggal_mulai<=ss.tanggal AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=ss.tanggal)
  JOIN siswa s ON s.id=r.id_siswa
  LEFT JOIN presensi_sekolah p ON p.id_sesi_presensi_sekolah=ss.id AND p.id_siswa=s.id
  WHERE ss.tanggal BETWEEN :start AND :end AND ss.status='DITUTUP' AND (:tingkat IS NULL OR c.tingkat=:tingkat)`;
const present = "status IN ('HADIR','TERLAMBAT')";

async function snapshot(f) {
  const day = today();
  const [trend, todayRows, byStatus, reports, cases, casesByCategory, clubs, unique, students, achievements, byLevel, byClub] = await Promise.all([
    select(`SELECT tanggal, SUM(${present}) AS hadir, COUNT(*) AS total FROM (${attendanceCte}) a GROUP BY tanggal ORDER BY tanggal`, f),
    select(`SELECT SUM(${present}) AS hadir, COUNT(*) AS total FROM (${attendanceCte}) a WHERE tanggal=:day`, { ...f, start: day, end: day, day }),
    select(`SELECT status, COUNT(*) AS total FROM (${attendanceCte}) a GROUP BY status`, f),
    select(`SELECT status_verifikasi, COUNT(*) AS total FROM laporan_pelanggaran
      WHERE waktu_kejadian >= TIMESTAMP(:start) - INTERVAL 7 HOUR AND waktu_kejadian < TIMESTAMP(:end) + INTERVAL 17 HOUR GROUP BY status_verifikasi`, f),
    select(`SELECT status, COUNT(*) AS total FROM penanganan_siswa GROUP BY status`),
    select(`SELECT k.nama AS kategori, COUNT(*) AS total FROM laporan_pelanggaran l
      JOIN versi_aturan_penanganan a ON a.id=l.id_versi_aturan_penanganan JOIN kategori_pelanggaran k ON k.id=a.id_kategori_pelanggaran
      WHERE l.status_verifikasi='TERVERIFIKASI' AND l.waktu_kejadian >= TIMESTAMP(:start) - INTERVAL 7 HOUR
        AND l.waktu_kejadian < TIMESTAMP(:end) + INTERVAL 17 HOUR GROUP BY k.nama ORDER BY total DESC`, f),
    select(`SELECT e.nama, COUNT(DISTINCT k.id) AS anggota FROM periode_ekstrakurikuler p
      JOIN ekstrakurikuler e ON e.id=p.id_ekstrakurikuler JOIN tahun_ajaran t ON t.id=p.id_tahun_ajaran AND t.aktif=1
      LEFT JOIN keanggotaan_ekstrakurikuler k ON k.id_periode_ekstrakurikuler=p.id
        AND EXISTS (SELECT 1 FROM masa_keanggotaan m WHERE m.id_keanggotaan_ekstrakurikuler=k.id AND m.tanggal_selesai IS NULL)
      GROUP BY e.id, e.nama ORDER BY anggota DESC, e.nama`),
    select(`SELECT COUNT(DISTINCT k.id_siswa) AS total FROM keanggotaan_ekstrakurikuler k
      JOIN periode_ekstrakurikuler p ON p.id=k.id_periode_ekstrakurikuler JOIN tahun_ajaran t ON t.id=p.id_tahun_ajaran AND t.aktif=1
      WHERE EXISTS (SELECT 1 FROM masa_keanggotaan m WHERE m.id_keanggotaan_ekstrakurikuler=k.id AND m.tanggal_selesai IS NULL)`),
    select("SELECT COUNT(*) AS total FROM siswa WHERE status_siswa='AKTIF'"),
    select(`SELECT COUNT(*) AS total FROM portofolio WHERE status_catatan='AKTIF' AND jenis='PRESTASI' AND tanggal BETWEEN :start AND :end`, f),
    select(`SELECT tingkat_prestasi AS tingkat, COUNT(*) AS total FROM portofolio WHERE status_catatan='AKTIF' AND jenis='PRESTASI' AND tanggal BETWEEN :start AND :end GROUP BY tingkat_prestasi`, f),
    select(`SELECT e.nama AS ekskul, COUNT(*) AS total FROM portofolio o JOIN periode_ekstrakurikuler p ON p.id=o.id_periode_ekstrakurikuler
      JOIN ekstrakurikuler e ON e.id=p.id_ekstrakurikuler WHERE o.status_catatan='AKTIF' AND o.jenis='PRESTASI' AND o.tanggal BETWEEN :start AND :end GROUP BY e.nama ORDER BY total DESC LIMIT 5`, f)
  ]);
  const t = todayRows[0] || {};
  const reportMap = Object.fromEntries(reports.map(r => [r.status_verifikasi, n(r.total)]));
  const caseMap = Object.fromEntries(cases.map(r => [r.status, n(r.total)]));
  const activeCases = n(caseMap.TERBUKA) + n(caseMap.DALAM_PENANGANAN);
  const closedCases = Object.entries(caseMap).filter(([k]) => !['TERBUKA', 'DALAM_PENANGANAN'].includes(k)).reduce((s, [, v]) => s + v, 0);
  const members = n(unique[0]?.total), totalStudents = n(students[0]?.total);
  return {
    periode: { mulai: f.start, sampai: f.end, tingkat: f.tingkat, dibuat: new Date().toISOString() },
    kehadiran: {
      hari_ini: { hadir: n(t.hadir), total: n(t.total), persen: pct(n(t.hadir), n(t.total)) },
      tren: trend.map(r => ({ tanggal: r.tanggal, persen: pct(n(r.hadir), n(r.total)) })),
      per_status: Object.fromEntries(byStatus.map(r => [r.status, n(r.total)]))
    },
    pelanggaran: { laporan: reportMap, per_kategori: casesByCategory.map(r => ({ kategori: r.kategori, total: n(r.total) })) },
    kasus: { aktif: activeCases, selesai: closedCases, per_status: caseMap },
    ekskul: { siswa_unik: members, total_siswa: totalStudents, persen_partisipasi: pct(members, totalStudents),
      per_kegiatan: clubs.map(r => ({ nama: r.nama, anggota: n(r.anggota) })),
      prestasi: { total: n(achievements[0]?.total), per_tingkat: byLevel.map(r => ({ tingkat: r.tingkat, total: n(r.total) })), per_ekskul: byClub.map(r => ({ ekskul: r.ekskul, total: n(r.total) })) } }
  };
}

exports.dashboard = async (req, res) => res.json({ data: await snapshot(range(req)) });

// Ringkasan kasus: hanya jumlah dan status. Isi konseling, nama siswa, dan catatan internal sengaja tidak dikirim ke Kepala Sekolah.
exports.cases = async (req, res) => {
  const f = range(req);
  const [byStatus, byCategory, aging] = await Promise.all([
    select('SELECT status, COUNT(*) AS total FROM penanganan_siswa GROUP BY status'),
    select(`SELECT k.nama AS kategori, SUM(l.status_tindak_lanjut<>'SELESAI') AS berjalan, COUNT(*) AS total FROM laporan_pelanggaran l
      JOIN versi_aturan_penanganan a ON a.id=l.id_versi_aturan_penanganan JOIN kategori_pelanggaran k ON k.id=a.id_kategori_pelanggaran
      WHERE l.status_verifikasi='TERVERIFIKASI' AND l.waktu_kejadian >= TIMESTAMP(:start) - INTERVAL 7 HOUR
        AND l.waktu_kejadian < TIMESTAMP(:end) + INTERVAL 17 HOUR GROUP BY k.nama ORDER BY total DESC`, f),
    select(`SELECT SUM(DATEDIFF(:end,tanggal_dibuka)<=7) AS sampai_7, SUM(DATEDIFF(:end,tanggal_dibuka) BETWEEN 8 AND 30) AS dari_8_30,
      SUM(DATEDIFF(:end,tanggal_dibuka)>30) AS lebih_30 FROM penanganan_siswa WHERE status IN ('TERBUKA','DALAM_PENANGANAN')`, f)
  ]);
  res.json({ data: { periode: { mulai: f.start, sampai: f.end }, per_status: byStatus.map(r => ({ status: r.status, total: n(r.total) })),
    per_kategori: byCategory.map(r => ({ kategori: r.kategori, total: n(r.total), berjalan: n(r.berjalan) })),
    usia_kasus_aktif: { sampai_7_hari: n(aging[0]?.sampai_7), dari_8_30_hari: n(aging[0]?.dari_8_30), lebih_30_hari: n(aging[0]?.lebih_30) } } });
};

exports.ekskul = async (req, res) => {
  const f = range(req);
  const rows = await select(`SELECT e.nama, p.kapasitas,
      (SELECT COUNT(*) FROM keanggotaan_ekstrakurikuler k WHERE k.id_periode_ekstrakurikuler=p.id
        AND EXISTS (SELECT 1 FROM masa_keanggotaan m WHERE m.id_keanggotaan_ekstrakurikuler=k.id AND m.tanggal_selesai IS NULL)) AS anggota,
      (SELECT COUNT(*) FROM pertemuan_ekstrakurikuler m WHERE m.id_periode_ekstrakurikuler=p.id AND m.status_presensi='DITUTUP' AND m.tanggal BETWEEN :start AND :end) AS pertemuan,
      (SELECT SUM(x.status_kehadiran='HADIR') FROM presensi_ekstrakurikuler x JOIN pertemuan_ekstrakurikuler m ON m.id=x.id_pertemuan_ekstrakurikuler
        WHERE m.id_periode_ekstrakurikuler=p.id AND m.tanggal BETWEEN :start AND :end) AS hadir,
      (SELECT COUNT(*) FROM presensi_ekstrakurikuler x JOIN pertemuan_ekstrakurikuler m ON m.id=x.id_pertemuan_ekstrakurikuler
        WHERE m.id_periode_ekstrakurikuler=p.id AND m.tanggal BETWEEN :start AND :end) AS tercatat,
      (SELECT COUNT(*) FROM portofolio o WHERE o.id_periode_ekstrakurikuler=p.id AND o.status_catatan='AKTIF' AND o.jenis='PRESTASI' AND o.tanggal BETWEEN :start AND :end) AS prestasi
    FROM periode_ekstrakurikuler p JOIN ekstrakurikuler e ON e.id=p.id_ekstrakurikuler JOIN tahun_ajaran t ON t.id=p.id_tahun_ajaran AND t.aktif=1
    ORDER BY e.nama`, f);
  res.json({ data: { periode: { mulai: f.start, sampai: f.end }, kegiatan: rows.map(r => ({ nama: r.nama, kapasitas: r.kapasitas, anggota: n(r.anggota),
    pertemuan: n(r.pertemuan), persen_hadir: pct(n(r.hadir), n(r.tercatat)), prestasi: n(r.prestasi) })) } });
};

const cell = v => {
  let text = String(v ?? '');
  if (/^[\s]*[=+@-]|^[\t\r\n]/.test(text)) text = "'" + text;
  return '"' + text.replaceAll('"', '""') + '"';
};
// Ekspor ringkasan eksekutif (CSV, agregat saja tanpa data pribadi).
exports.exportSummary = async (req, res) => {
  const d = await snapshot(range(req));
  const rows = [['Bagian', 'Indikator', 'Nilai'],
    ['Periode', 'Mulai', d.periode.mulai], ['Periode', 'Sampai', d.periode.sampai],
    ['Kehadiran', 'Hari ini (%)', d.kehadiran.hari_ini.persen], ...Object.entries(d.kehadiran.per_status).map(([k, v]) => ['Kehadiran', 'Status ' + k, v]),
    ...Object.entries(d.pelanggaran.laporan).map(([k, v]) => ['Laporan pelanggaran', k, v]),
    ...d.pelanggaran.per_kategori.map(r => ['Pelanggaran terverifikasi', r.kategori, r.total]),
    ['Kasus', 'Aktif', d.kasus.aktif], ['Kasus', 'Selesai', d.kasus.selesai],
    ['Ekstrakurikuler', 'Siswa unik', d.ekskul.siswa_unik], ['Ekstrakurikuler', 'Partisipasi (%)', d.ekskul.persen_partisipasi],
    ...d.ekskul.per_kegiatan.map(r => ['Anggota kegiatan', r.nama, r.anggota]),
    ['Prestasi', 'Total', d.ekskul.prestasi.total], ...d.ekskul.prestasi.per_tingkat.map(r => ['Prestasi tingkat', r.tingkat, r.total])];
  res.type('text/csv').attachment(`ringkasan-eksekutif-${d.periode.mulai}_${d.periode.sampai}.csv`).send('﻿' + rows.map(r => r.map(cell).join(',')).join('\r\n'));
};
