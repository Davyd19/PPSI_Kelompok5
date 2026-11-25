// Use case Guru: "Melihat Rekap Kehadiran" presensi sekolah (pagi & salat Zuhur)
// dari data presensi yang tersimpan, dengan filter periode, kelas, jenis sesi, dan pencarian.
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../models');
const { today } = require('./auth.controller');
const { id, date, string, invalid, missing } = require('./kesiswaan.controller').validation;

const PAGE_SIZE = 50;
const select = (sql, replacements = {}) => sequelize.query(sql, { type: QueryTypes.SELECT, replacements });
const COUNTS = ['hadir', 'terlambat', 'izin', 'sakit', 'alfa', 'pengecualian_sah', 'belum_diisi', 'total_sesi'];

function shiftDay(value, days) {
  const d = new Date(value);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}
function filters(req) {
  const end = req.query.sampai === undefined ? today() : date(req.query.sampai, 'Tanggal akhir');
  // `semua=1` → seluruh periode sampai tanggal akhir (tanpa batas 1 tahun).
  const all = req.query.semua === '1';
  const start = all ? '1000-01-01'
    : req.query.mulai === undefined ? shiftDay(end, -29) : date(req.query.mulai, 'Tanggal awal');
  if (start > end || (!all && (Date.parse(end) - Date.parse(start)) / 86400000 > 366)) {
    throw invalid('Rentang tanggal tidak valid atau lebih dari 367 hari.');
  }
  const jenis = req.query.jenis || null;
  if (jenis && !['PAGI', 'ZUHUR'].includes(jenis)) throw invalid('Jenis sesi tidak valid.');
  const q = string(req.query.q, 'Pencarian', 100, true);
  const page = req.query.page === undefined ? 1 : id(req.query.page);
  if (page > 100000) throw invalid('Halaman tidak valid.');
  return {
    start, end, jenis, q: q ? `%${q}%` : null,
    kelas: req.query.kelas ? id(req.query.kelas) : null,
    page, offset: (page - 1) * PAGE_SIZE
  };
}

// Satu baris = satu siswa pada satu sesi (siswa wajib presensi menurut riwayat kelasnya).
const baseSql = (extraJoin = '') => `FROM sesi_presensi_sekolah ss
  JOIN semester sm ON sm.id=ss.id_semester
  JOIN kelas c ON c.id_tahun_ajaran=sm.id_tahun_ajaran
  JOIN riwayat_kelas_siswa r ON r.id_kelas=c.id AND r.tanggal_mulai<=ss.tanggal
    AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=ss.tanggal)
  JOIN siswa s ON s.id=r.id_siswa
  LEFT JOIN presensi_sekolah p ON p.id_sesi_presensi_sekolah=ss.id AND p.id_siswa=s.id
  ${extraJoin}
  WHERE ss.tanggal BETWEEN :start AND :end
    AND (:jenis IS NULL OR ss.jenis_sesi=:jenis)
    AND (:kelas IS NULL OR c.id=:kelas)
    AND (:q IS NULL OR s.nama LIKE :q OR s.nisn LIKE :q OR s.nis LIKE :q)`;
const countSql = `SUM(p.status_kehadiran='HADIR') AS hadir,
  SUM(p.status_kehadiran='TERLAMBAT') AS terlambat,
  SUM(p.status_kehadiran='IZIN') AS izin,
  SUM(p.status_kehadiran='SAKIT') AS sakit,
  SUM(p.status_kehadiran='ALFA') AS alfa,
  SUM(p.status_kehadiran='PENGECUALIAN_SAH') AS pengecualian_sah,
  SUM(p.id IS NULL) AS belum_diisi,
  COUNT(*) AS total_sesi`;
const numbers = row => ({ ...row, ...Object.fromEntries(COUNTS.map(k => [k, Number(row[k] ?? 0)])) });

// GET /guru/presensi/kelas — pilihan filter kelas (tahun ajaran aktif).
exports.classes = async (req, res) => {
  const rows = await select(`SELECT c.id, c.nama, c.tingkat FROM kelas c
    JOIN tahun_ajaran t ON t.id=c.id_tahun_ajaran
    WHERE t.aktif=1 AND c.status='AKTIF' ORDER BY c.tingkat, c.nama`);
  res.json({ data: rows });
};

// GET /guru/presensi/rekap?mulai=&sampai=&kelas=&jenis=&q=&page=
exports.recap = async (req, res) => {
  const f = filters(req);
  const grouped = `SELECT s.id AS id_siswa, s.nama, s.nis, s.nisn, c.id AS id_kelas, c.nama AS kelas, ${countSql}
    ${baseSql()} GROUP BY s.id, s.nama, s.nis, s.nisn, c.id, c.nama`;
  const [rows, [{ total }], [summary], [{ sesi }]] = await Promise.all([
    select(grouped + ` ORDER BY kelas, nama, id_siswa LIMIT ${PAGE_SIZE} OFFSET :offset`, f),
    select(`SELECT COUNT(*) AS total FROM (${grouped}) x`, f),
    select(`SELECT ${countSql} ${baseSql()}`, f),
    select(`SELECT COUNT(*) AS sesi FROM sesi_presensi_sekolah ss
      WHERE ss.tanggal BETWEEN :start AND :end AND (:jenis IS NULL OR ss.jenis_sesi=:jenis)`, f)
  ]);
  res.json({
    data: rows.map(numbers),
    meta: {
      total: Number(total), page: f.page, page_size: PAGE_SIZE,
      mulai: f.start, sampai: f.end, jumlah_sesi: Number(sesi),
      ringkasan: numbers(summary ?? {})
    }
  });
};

// GET /guru/presensi/rekap/siswa/:id?mulai=&sampai=&jenis= — riwayat per sesi seorang siswa.
exports.studentHistory = async (req, res) => {
  const f = { ...filters(req), kelas: null, q: null, student: id(req.params.id) };
  const [student] = await select('SELECT id, nama, nis, nisn FROM siswa WHERE id=:student', f);
  if (!student) throw missing();
  // `jumlah_koreksi` & `status_awal` dari audit UBAH_PRESENSI agar perubahan tetap terlihat.
  const rows = await select(`SELECT ss.id AS id_sesi, ss.tanggal, ss.jenis_sesi, ss.status AS status_sesi,
      c.nama AS kelas, p.id AS id_presensi, COALESCE(p.status_kehadiran,'BELUM_DIISI') AS status_kehadiran,
      p.metode, p.waktu_presensi, p.keterangan, g.nama AS pencatat,
      (SELECT COUNT(*) FROM audit_perubahan a WHERE a.nama_tabel='presensi_sekolah'
        AND a.jenis_tindakan='UBAH_PRESENSI' AND a.identitas_data=CAST(p.id AS CHAR)) AS jumlah_koreksi,
      (SELECT d.nilai_sebelum FROM audit_perubahan a JOIN detail_audit_perubahan d ON d.id_audit_perubahan=a.id
        WHERE a.nama_tabel='presensi_sekolah' AND a.jenis_tindakan='UBAH_PRESENSI'
          AND a.identitas_data=CAST(p.id AS CHAR) AND d.nama_atribut='status_kehadiran'
        ORDER BY a.id LIMIT 1) AS status_awal
    ${baseSql('LEFT JOIN guru g ON g.id=p.id_guru_pencatat')}
      AND s.id=:student
    ORDER BY ss.tanggal DESC, ss.jenis_sesi`, f);
  res.json({ data: { siswa: student, mulai: f.start, sampai: f.end, riwayat: rows } });
};
