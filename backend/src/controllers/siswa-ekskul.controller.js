const { QueryTypes } = require('sequelize');
const { sequelize, models } = require('../models');
const { today } = require('./auth.controller');
const audit = require('../utils/audit');
const fail = require('../utils/api-error');
const { id } = require('./kesiswaan.controller').validation;

const select = (sql, replacements = {}) => sequelize.query(sql, { type: QueryTypes.SELECT, replacements });
const send = (res, data, status = 200) => res.status(status).json({ data });

exports.guard = (req, res, next) => {
  if (req.authPlatform !== 'mobile' || req.user.kind !== 'siswa') {
    throw fail(403, 'FORBIDDEN', 'Fitur ini hanya tersedia untuk siswa.');
  }
  res.set('Cache-Control', 'no-store');
  next();
};

// Kegiatan yang tersedia pada tahun ajaran aktif beserta status siswa ini.
exports.catalog = async (req, res) => {
  const rows = await select(`SELECT p.id, e.nama, e.deskripsi, p.kapasitas, p.status_pendaftaran,
      p.pendaftaran_mulai, p.pendaftaran_selesai,
      (SELECT COUNT(*) FROM keanggotaan_ekstrakurikuler k JOIN masa_keanggotaan m ON m.id_keanggotaan_ekstrakurikuler=k.id
        WHERE k.id_periode_ekstrakurikuler=p.id AND m.tanggal_selesai IS NULL) AS anggota_aktif,
      (SELECT d.status_keputusan FROM pendaftaran_ekstrakurikuler d WHERE d.id_siswa=:s AND d.id_periode_ekstrakurikuler=p.id
        ORDER BY d.tanggal_daftar DESC, d.id DESC LIMIT 1) AS status_saya,
      EXISTS (SELECT 1 FROM keanggotaan_ekstrakurikuler k JOIN masa_keanggotaan m ON m.id_keanggotaan_ekstrakurikuler=k.id
        WHERE k.id_periode_ekstrakurikuler=p.id AND k.id_siswa=:s AND m.tanggal_selesai IS NULL) AS anggota
    FROM periode_ekstrakurikuler p JOIN ekstrakurikuler e ON e.id=p.id_ekstrakurikuler AND e.status='AKTIF'
    JOIN tahun_ajaran t ON t.id=p.id_tahun_ajaran AND t.aktif=1 WHERE p.status_kegiatan='AKTIF' ORDER BY e.nama`, { s: req.user.id });
  send(res, rows.map(r => ({ ...r, anggota: !!r.anggota, penuh: r.kapasitas != null && Number(r.anggota_aktif) >= r.kapasitas })));
};

// Mendaftar; keputusan diterima/ditolak oleh pembina. Siswa boleh mengikuti lebih dari satu kegiatan.
exports.register = async (req, res) => {
  const periodId = id(req.params.id);
  const saved = await sequelize.transaction(async t => {
    const period = await models.periode_ekskul.findByPk(periodId, { transaction: t, lock: t.LOCK.UPDATE });
    if (!period || period.status_kegiatan !== 'AKTIF') throw fail(404, 'NOT_FOUND', 'Kegiatan tidak ditemukan.');
    if (period.status_pendaftaran !== 'DIBUKA') throw fail(409, 'STATE_CONFLICT', 'Pendaftaran kegiatan ini sedang ditutup.');
    const now = new Date();
    if ((period.pendaftaran_mulai && now < period.pendaftaran_mulai) || (period.pendaftaran_selesai && now > period.pendaftaran_selesai)) {
      throw fail(409, 'STATE_CONFLICT', 'Di luar masa pendaftaran.');
    }
    const student = await models.siswa.findByPk(req.user.id, { transaction: t });
    if (student.status_siswa !== 'AKTIF') throw fail(403, 'FORBIDDEN', 'Siswa tidak aktif.');
    const [{ n }] = await sequelize.query(`SELECT COUNT(*) AS n FROM keanggotaan_ekstrakurikuler k
      JOIN masa_keanggotaan m ON m.id_keanggotaan_ekstrakurikuler=k.id
      WHERE k.id_periode_ekstrakurikuler=:p AND k.id_siswa=:s AND m.tanggal_selesai IS NULL`,
      { type: QueryTypes.SELECT, replacements: { p: periodId, s: req.user.id }, transaction: t });
    if (Number(n)) throw fail(409, 'STATE_CONFLICT', 'Anda sudah menjadi anggota kegiatan ini.');
    if (await models.pendaftaran.count({ where: { id_siswa: req.user.id, id_periode_ekstrakurikuler: periodId, status_keputusan: 'MENUNGGU' }, transaction: t })) {
      throw fail(409, 'STATE_CONFLICT', 'Pendaftaran Anda masih menunggu keputusan pembina.');
    }
    const row = await models.pendaftaran.create({ id_siswa: req.user.id, id_periode_ekstrakurikuler: periodId,
      tanggal_daftar: now, status_keputusan: 'MENUNGGU' }, { transaction: t });
    await audit(req, 'pendaftaran', row.id, null, row.toJSON(), 'DAFTAR_EKSKUL', t);
    return row;
  });
  send(res, { id: saved.id, status_keputusan: saved.status_keputusan }, 201);
};

// Kegiatan yang saya ikuti beserta ringkasan kehadiran (hanya data milik siswa sendiri).
exports.mine = async (req, res) => {
  const rows = await select(`SELECT k.id AS id_keanggotaan, p.id AS id_periode, e.nama, m.tanggal_mulai,
      SUM(x.status_kehadiran='HADIR') AS hadir, SUM(x.status_kehadiran='IZIN') AS izin,
      SUM(x.status_kehadiran='SAKIT') AS sakit, SUM(x.status_kehadiran='ALFA') AS alfa, COUNT(x.id) AS tercatat
    FROM keanggotaan_ekstrakurikuler k JOIN masa_keanggotaan m ON m.id_keanggotaan_ekstrakurikuler=k.id AND m.tanggal_selesai IS NULL
    JOIN periode_ekstrakurikuler p ON p.id=k.id_periode_ekstrakurikuler JOIN ekstrakurikuler e ON e.id=p.id_ekstrakurikuler
    LEFT JOIN presensi_ekstrakurikuler x ON x.id_keanggotaan_ekstrakurikuler=k.id
    WHERE k.id_siswa=:s GROUP BY k.id, p.id, e.nama, m.tanggal_mulai ORDER BY e.nama`, { s: req.user.id });
  const registrations = await select(`SELECT d.id, e.nama, d.tanggal_daftar, d.status_keputusan, d.alasan
    FROM pendaftaran_ekstrakurikuler d JOIN periode_ekstrakurikuler p ON p.id=d.id_periode_ekstrakurikuler
    JOIN ekstrakurikuler e ON e.id=p.id_ekstrakurikuler WHERE d.id_siswa=:s ORDER BY d.tanggal_daftar DESC LIMIT 30`, { s: req.user.id });
  const n = v => Number(v || 0);
  send(res, { keanggotaan: rows.map(r => ({ ...r, hadir: n(r.hadir), izin: n(r.izin), sakit: n(r.sakit), alfa: n(r.alfa), tercatat: n(r.tercatat),
    persen_hadir: n(r.tercatat) ? Math.round(n(r.hadir) / n(r.tercatat) * 1000) / 10 : null })), pendaftaran: registrations });
};
exports.history = async (req, res) => {
  const rows = await select(`SELECT m.tanggal, m.jam_mulai, m.lokasi, m.agenda, x.status_kehadiran, x.keterangan
    FROM presensi_ekstrakurikuler x JOIN keanggotaan_ekstrakurikuler k ON k.id=x.id_keanggotaan_ekstrakurikuler
    JOIN pertemuan_ekstrakurikuler m ON m.id=x.id_pertemuan_ekstrakurikuler
    WHERE k.id_siswa=:s AND k.id_periode_ekstrakurikuler=:p ORDER BY m.tanggal DESC, m.jam_mulai DESC LIMIT 60`, { s: req.user.id, p: id(req.params.id) });
  send(res, rows);
};
