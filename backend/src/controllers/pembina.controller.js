const { createHash, randomBytes } = require('node:crypto');
const { Op, QueryTypes } = require('sequelize');
const { sequelize, models } = require('../models');
const { today } = require('./auth.controller');
const audit = require('../utils/audit');
const fail = require('../utils/api-error');
const { id, date, string, invalid, missing } = require('./kesiswaan.controller').validation;

const conflict = message => fail(409, 'STATE_CONFLICT', message);
const send = (res, data, status = 200) => res.status(status).json({ data });
const select = (sql, replacements = {}) => sequelize.query(sql, { type: QueryTypes.SELECT, replacements });
const attendanceStatuses = ['HADIR', 'IZIN', 'SAKIT', 'ALFA'];
const levels = ['SEKOLAH', 'KECAMATAN', 'KOTA', 'PROVINSI', 'NASIONAL', 'INTERNASIONAL'];

function time(value, label) {
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(value)) throw invalid(label + ' tidak valid.');
  return value.length === 5 ? value + ':00' : value;
}

// Periode yang sedang dibina guru ini (penugasan aktif hari ini).
async function assignedPeriods(guruId) {
  const day = today();
  const rows = await models.pembina.findAll({
    where: { id_guru: guruId, tanggal_mulai: { [Op.lte]: day },
      [Op.or]: [{ tanggal_selesai: null }, { tanggal_selesai: { [Op.gte]: day } }] }
  });
  return rows.map(r => r.id_periode_ekstrakurikuler);
}
// Memastikan periode memang dibina oleh guru yang login (cegah akses lintas ekskul).
async function ownPeriod(req, value) {
  const periodId = id(value);
  if (!(await assignedPeriods(req.user.id)).includes(periodId)) {
    throw fail(403, 'FORBIDDEN', 'Anda bukan pembina kegiatan ini.');
  }
  return periodId;
}
// Pertemuan beserta pemeriksaan kepemilikan; dipakai semua aksi sesi/presensi.
async function ownMeeting(req, value, t) {
  const meeting = await models.pertemuan.findByPk(id(value), t ? { transaction: t, lock: t.LOCK.UPDATE } : {});
  if (!meeting) throw missing();
  if (!(await assignedPeriods(req.user.id)).includes(meeting.id_periode_ekstrakurikuler)) {
    throw fail(403, 'FORBIDDEN', 'Anda bukan pembina kegiatan ini.');
  }
  return meeting;
}

exports.guard = (req, res, next) => {
  if (req.authPlatform !== 'mobile' || !req.user.available_roles.includes('PEMBINA_EKSTRAKURIKULER')) {
    throw fail(403, 'FORBIDDEN', 'Fitur ini hanya dapat diakses Pembina Ekstrakurikuler aktif.');
  }
  res.set('Cache-Control', 'no-store');
  next();
};

// Beranda: kegiatan yang dibina, jumlah anggota aktif, dan pertemuan hari ini.
exports.activities = async (req, res) => {
  const periods = await assignedPeriods(req.user.id);
  if (!periods.length) return send(res, { activities: [], sessions_today: [] });
  const activities = await select(`SELECT p.id, e.id AS id_ekskul, e.nama, e.deskripsi, t.nama AS tahun_ajaran,
      p.kapasitas, p.status_pendaftaran, p.status_kegiatan,
      (SELECT COUNT(*) FROM keanggotaan_ekstrakurikuler k JOIN masa_keanggotaan m ON m.id_keanggotaan_ekstrakurikuler=k.id
        WHERE k.id_periode_ekstrakurikuler=p.id AND m.tanggal_selesai IS NULL) AS anggota_aktif,
      (SELECT COUNT(*) FROM pendaftaran_ekstrakurikuler d WHERE d.id_periode_ekstrakurikuler=p.id
        AND d.status_keputusan='MENUNGGU') AS pendaftar_menunggu
    FROM periode_ekstrakurikuler p JOIN ekstrakurikuler e ON e.id=p.id_ekstrakurikuler
    JOIN tahun_ajaran t ON t.id=p.id_tahun_ajaran WHERE p.id IN (:periods) ORDER BY e.nama`, { periods });
  const sessions = await select(`SELECT m.id, m.id_periode_ekstrakurikuler, e.nama AS ekskul, m.tanggal, m.jam_mulai,
      m.jam_selesai, m.lokasi, m.agenda, m.status_pertemuan, m.status_presensi
    FROM pertemuan_ekstrakurikuler m JOIN periode_ekstrakurikuler p ON p.id=m.id_periode_ekstrakurikuler
    JOIN ekstrakurikuler e ON e.id=p.id_ekstrakurikuler
    WHERE m.id_periode_ekstrakurikuler IN (:periods) AND m.tanggal=:day ORDER BY m.jam_mulai`, { periods, day: today() });
  send(res, { activities, sessions_today: sessions });
};

// Info kegiatan dapat diubah pembina: deskripsi ekskul dan status pendaftaran periodenya.
exports.updateActivity = async (req, res) => {
  const periodId = await ownPeriod(req, req.params.id);
  const body = req.body || {};
  const patchEkskul = {}, patchPeriode = {};
  if (body.deskripsi !== undefined) patchEkskul.deskripsi = string(body.deskripsi, 'Deskripsi', 10000, true);
  if (body.kapasitas !== undefined) {
    if (!Number.isInteger(body.kapasitas) || body.kapasitas < 1 || body.kapasitas > 1000) throw invalid('Kapasitas tidak valid.');
    patchPeriode.kapasitas = body.kapasitas;
  }
  if (body.status_pendaftaran !== undefined) {
    if (!['DIBUKA', 'DITUTUP'].includes(body.status_pendaftaran)) throw invalid('Status pendaftaran tidak valid.');
    patchPeriode.status_pendaftaran = body.status_pendaftaran;
  }
  if (!Object.keys(patchEkskul).length && !Object.keys(patchPeriode).length) throw invalid('Tidak ada perubahan.');
  const saved = await sequelize.transaction(async t => {
    const period = await models.periode_ekskul.findByPk(periodId, { transaction: t, lock: t.LOCK.UPDATE });
    const club = await models.ekskul.findByPk(period.id_ekstrakurikuler, { transaction: t, lock: t.LOCK.UPDATE });
    if (patchPeriode.kapasitas) {
      const [{ n }] = await select(`SELECT COUNT(*) AS n FROM keanggotaan_ekstrakurikuler k
        JOIN masa_keanggotaan m ON m.id_keanggotaan_ekstrakurikuler=k.id
        WHERE k.id_periode_ekstrakurikuler=:periodId AND m.tanggal_selesai IS NULL`, { periodId });
      if (patchPeriode.kapasitas < Number(n)) throw conflict('Kapasitas lebih kecil dari jumlah anggota aktif.');
    }
    if (Object.keys(patchEkskul).length) {
      const before = club.toJSON();
      await club.update(patchEkskul, { transaction: t });
      await audit(req, 'ekskul', club.id, before, club.toJSON(), 'UBAH_INFO_EKSKUL', t);
    }
    if (Object.keys(patchPeriode).length) {
      const before = period.toJSON();
      await period.update(patchPeriode, { transaction: t });
      await audit(req, 'periode_ekskul', period.id, before, period.toJSON(), 'UBAH_PERIODE_EKSKUL', t);
    }
    return { id: period.id };
  });
  send(res, saved);
};

// Pendaftaran & keanggotaan
exports.registrations = async (req, res) => {
  const periodId = await ownPeriod(req, req.params.id);
  const rows = await select(`SELECT d.id, d.id_siswa, s.nama AS siswa, s.nisn, d.tanggal_daftar,
      d.status_keputusan, d.tanggal_keputusan, d.alasan
    FROM pendaftaran_ekstrakurikuler d JOIN siswa s ON s.id=d.id_siswa
    WHERE d.id_periode_ekstrakurikuler=:periodId ORDER BY (d.status_keputusan='MENUNGGU') DESC, d.tanggal_daftar DESC`, { periodId });
  send(res, rows);
};
exports.decideRegistration = async (req, res) => {
  const decision = req.body?.keputusan;
  if (!['TERIMA', 'TOLAK'].includes(decision)) throw invalid('Keputusan tidak valid.');
  const reason = string(req.body?.alasan, 'Alasan', 5000, decision === 'TERIMA');
  const result = await sequelize.transaction(async t => {
    const reg = await models.pendaftaran.findByPk(id(req.params.id), { transaction: t, lock: t.LOCK.UPDATE });
    if (!reg) throw missing();
    if (!(await assignedPeriods(req.user.id)).includes(reg.id_periode_ekstrakurikuler)) throw fail(403, 'FORBIDDEN', 'Anda bukan pembina kegiatan ini.');
    if (reg.status_keputusan !== 'MENUNGGU') throw conflict('Pendaftaran sudah diputuskan.');
    const period = await models.periode_ekskul.findByPk(reg.id_periode_ekstrakurikuler, { transaction: t, lock: t.LOCK.UPDATE });
    if (decision === 'TERIMA') {
      if (period.kapasitas != null) {
        const [{ n }] = await select(`SELECT COUNT(*) AS n FROM keanggotaan_ekstrakurikuler k
          JOIN masa_keanggotaan m ON m.id_keanggotaan_ekstrakurikuler=k.id
          WHERE k.id_periode_ekstrakurikuler=:p AND m.tanggal_selesai IS NULL`, { p: period.id });
        if (Number(n) >= period.kapasitas) throw conflict('Kapasitas kegiatan sudah penuh.');
      }
      let member = await models.anggota.findOne({ where: { id_siswa: reg.id_siswa, id_periode_ekstrakurikuler: period.id }, transaction: t, lock: t.LOCK.UPDATE });
      if (!member) member = await models.anggota.create({ id_siswa: reg.id_siswa, id_periode_ekstrakurikuler: period.id }, { transaction: t });
      const open = await models.masa.count({ where: { id_keanggotaan_ekstrakurikuler: member.id, tanggal_selesai: null }, transaction: t });
      if (!open) await models.masa.create({ id_keanggotaan_ekstrakurikuler: member.id, tanggal_mulai: today() }, { transaction: t });
    }
    const before = reg.toJSON();
    await reg.update({ status_keputusan: decision === 'TERIMA' ? 'DITERIMA' : 'DITOLAK', id_guru_pemeriksa: req.user.id,
      tanggal_keputusan: new Date(), alasan: reason }, { transaction: t });
    await audit(req, 'pendaftaran', reg.id, before, reg.toJSON(), 'KEPUTUSAN_PENDAFTARAN_EKSKUL', t);
    return { id: reg.id, status_keputusan: reg.status_keputusan };
  });
  send(res, result);
};
exports.members = async (req, res) => {
  const periodId = await ownPeriod(req, req.params.id);
  const rows = await select(`SELECT k.id, s.id AS id_siswa, s.nama, s.nisn, m.tanggal_mulai, m.tanggal_selesai, m.alasan_berakhir,
      (m.tanggal_selesai IS NULL) AS aktif
    FROM keanggotaan_ekstrakurikuler k JOIN siswa s ON s.id=k.id_siswa
    JOIN masa_keanggotaan m ON m.id=(SELECT x.id FROM masa_keanggotaan x WHERE x.id_keanggotaan_ekstrakurikuler=k.id
      ORDER BY x.tanggal_mulai DESC,x.id DESC LIMIT 1)
    WHERE k.id_periode_ekstrakurikuler=:periodId ORDER BY aktif DESC, s.nama`, { periodId });
  send(res, rows.map(r => ({ ...r, aktif: !!r.aktif })));
};
exports.endMembership = async (req, res) => {
  const reason = string(req.body?.alasan, 'Alasan', 191);
  await sequelize.transaction(async t => {
    const member = await models.anggota.findByPk(id(req.params.id), { transaction: t, lock: t.LOCK.UPDATE });
    if (!member) throw missing();
    if (!(await assignedPeriods(req.user.id)).includes(member.id_periode_ekstrakurikuler)) throw fail(403, 'FORBIDDEN', 'Anda bukan pembina kegiatan ini.');
    const open = await models.masa.findOne({ where: { id_keanggotaan_ekstrakurikuler: member.id, tanggal_selesai: null }, transaction: t, lock: t.LOCK.UPDATE });
    if (!open) throw conflict('Keanggotaan sudah berakhir.');
    if (open.tanggal_mulai > today()) throw conflict('Masa keanggotaan belum dimulai.');
    const before = open.toJSON();
    await open.update({ tanggal_selesai: today(), alasan_berakhir: reason }, { transaction: t });
    await audit(req, 'masa', open.id, before, open.toJSON(), 'AKHIRI_KEANGGOTAAN', t);
  });
  send(res, { id: id(req.params.id) });
};

// Jadwal & sesi pertemuan
exports.meetings = async (req, res) => {
  const periodId = await ownPeriod(req, req.params.id);
  const rows = await select(`SELECT m.*, (SELECT COUNT(*) FROM presensi_ekstrakurikuler p WHERE p.id_pertemuan_ekstrakurikuler=m.id) AS tercatat
    FROM pertemuan_ekstrakurikuler m WHERE m.id_periode_ekstrakurikuler=:periodId ORDER BY m.tanggal DESC, m.jam_mulai DESC LIMIT 100`, { periodId });
  send(res, rows);
};
exports.createMeeting = async (req, res) => {
  const periodId = await ownPeriod(req, req.params.id);
  const body = req.body || {};
  const data = { id_periode_ekstrakurikuler: periodId, tanggal: date(body.tanggal, 'Tanggal'),
    jam_mulai: time(body.jam_mulai, 'Jam mulai'), jam_selesai: time(body.jam_selesai, 'Jam selesai'),
    lokasi: string(body.lokasi, 'Lokasi', 191), agenda: string(body.agenda, 'Agenda', 191, true),
    status_pertemuan: 'TERJADWAL', status_presensi: 'BELUM_DIBUKA' };
  if (data.jam_selesai <= data.jam_mulai) throw invalid('Jam selesai harus setelah jam mulai.');
  const saved = await sequelize.transaction(async t => {
    const row = await models.pertemuan.create(data, { transaction: t });
    await audit(req, 'pertemuan', row.id, null, row.toJSON(), 'TAMBAH_PERTEMUAN', t);
    return row;
  });
  send(res, saved, 201);
};
exports.cancelMeeting = async (req, res) => {
  const reason = string(req.body?.alasan_batal, 'Alasan pembatalan', 191);
  const saved = await sequelize.transaction(async t => {
    const row = await ownMeeting(req, req.params.id, t);
    if (row.status_pertemuan !== 'TERJADWAL' || row.status_presensi !== 'BELUM_DIBUKA') throw conflict('Pertemuan yang sudah berjalan tidak dapat dibatalkan.');
    const before = row.toJSON();
    await row.update({ status_pertemuan: 'DIBATALKAN', alasan_batal: reason }, { transaction: t });
    await audit(req, 'pertemuan', row.id, before, row.toJSON(), 'BATALKAN_PERTEMUAN', t);
    return row;
  });
  send(res, saved);
};

// Buka / tutup sesi presensi
exports.openAttendance = async (req, res) => {
  const saved = await sequelize.transaction(async t => {
    const row = await ownMeeting(req, req.params.id, t);
    if (row.status_pertemuan !== 'TERJADWAL') throw conflict('Pertemuan tidak aktif.');
    if (row.status_presensi !== 'BELUM_DIBUKA') throw conflict('Sesi presensi sudah dibuka atau ditutup.');
    if (row.tanggal !== today()) throw conflict('Sesi presensi hanya dapat dibuka pada hari pertemuan.');
    const before = row.toJSON();
    await row.update({ status_presensi: 'DIBUKA', id_guru_pembuka: req.user.id, waktu_buka: new Date() }, { transaction: t });
    await audit(req, 'pertemuan', row.id, before, row.toJSON(), 'BUKA_PRESENSI_EKSKUL', t);
    return row;
  });
  send(res, saved);
};
exports.closeAttendance = async (req, res) => {
  const saved = await sequelize.transaction(async t => {
    const row = await ownMeeting(req, req.params.id, t);
    if (row.status_presensi !== 'DIBUKA') throw conflict('Sesi presensi belum dibuka.');
    // Anggota yang belum dicatat otomatis ALFA agar rekap lengkap.
    const members = await select(`SELECT k.id FROM keanggotaan_ekstrakurikuler k
      JOIN masa_keanggotaan m ON m.id_keanggotaan_ekstrakurikuler=k.id
      WHERE k.id_periode_ekstrakurikuler=:p AND m.tanggal_mulai<=:d AND (m.tanggal_selesai IS NULL OR m.tanggal_selesai>=:d)
      AND NOT EXISTS (SELECT 1 FROM presensi_ekstrakurikuler x WHERE x.id_pertemuan_ekstrakurikuler=:m AND x.id_keanggotaan_ekstrakurikuler=k.id)`,
      { p: row.id_periode_ekstrakurikuler, d: row.tanggal, m: row.id });
    if (members.length) await models.presensi_ekskul.bulkCreate(members.map(m => ({
      id_pertemuan_ekstrakurikuler: row.id, id_keanggotaan_ekstrakurikuler: m.id, id_guru_pencatat: req.user.id,
      status_kehadiran: 'ALFA', waktu_pencatatan: new Date(), keterangan: 'Otomatis saat sesi ditutup'
    })), { transaction: t });
    const before = row.toJSON();
    await row.update({ status_presensi: 'DITUTUP', status_pertemuan: 'SELESAI', id_guru_penutup: req.user.id, waktu_tutup: new Date(),
      hash_token_qr: null, token_kedaluwarsa: null }, { transaction: t });
    await audit(req, 'pertemuan', row.id, before, row.toJSON(), 'TUTUP_PRESENSI_EKSKUL', t);
    return { ...row.toJSON(), otomatis_alfa: members.length };
  });
  send(res, saved);
};

// QR presensi mandiri. Setiap permintaan membuat token baru yang berlaku singkat, sehingga
// foto QR yang dibagikan ke luar ruangan cepat kedaluwarsa. Aplikasi pembina memintanya ulang berkala.
const QR_TTL_MS = 60 * 1000;
exports.qrToken = async (req, res) => {
  const saved = await sequelize.transaction(async t => {
    const row = await ownMeeting(req, req.params.id, t);
    if (row.status_pertemuan !== 'TERJADWAL' || row.status_presensi !== 'DIBUKA') throw conflict('Buka sesi presensi terlebih dahulu.');
    if (row.tanggal !== today()) throw conflict('QR hanya tersedia pada hari pertemuan.');
    const token = randomBytes(18).toString('base64url');
    const expires = new Date(Date.now() + QR_TTL_MS);
    await row.update({ hash_token_qr: createHash('sha256').update(token).digest('hex'), token_kedaluwarsa: expires }, { transaction: t });
    return { kode: `EKSKUL:${row.id}:${token}`, kedaluwarsa: expires, berlaku_detik: QR_TTL_MS / 1000 };
  });
  send(res, saved);
};

// Daftar hadir satu pertemuan (anggota aktif + status tercatat).
exports.attendance = async (req, res) => {
  const meeting = await ownMeeting(req, req.params.id);
  const rows = await select(`SELECT k.id AS id_keanggotaan, s.id AS id_siswa, s.nama, s.nisn,
      p.status_kehadiran, p.waktu_pencatatan, p.keterangan
    FROM keanggotaan_ekstrakurikuler k JOIN siswa s ON s.id=k.id_siswa
    JOIN masa_keanggotaan m ON m.id_keanggotaan_ekstrakurikuler=k.id AND m.tanggal_mulai<=:d AND (m.tanggal_selesai IS NULL OR m.tanggal_selesai>=:d)
    LEFT JOIN presensi_ekstrakurikuler p ON p.id_pertemuan_ekstrakurikuler=:m AND p.id_keanggotaan_ekstrakurikuler=k.id
    WHERE k.id_periode_ekstrakurikuler=:p ORDER BY s.nama`, { p: meeting.id_periode_ekstrakurikuler, d: meeting.tanggal, m: meeting.id });
  send(res, { pertemuan: meeting, anggota: rows });
};
// Presensi manual oleh pembina (melengkapi scan QR siswa). Boleh dikoreksi selama pertemuan belum dibatalkan.
exports.markAttendance = async (req, res) => {
  const entries = req.body?.presensi;
  if (!Array.isArray(entries) || entries.length < 1 || entries.length > 200) throw invalid('Kirim 1 sampai 200 data presensi.');
  const parsed = entries.map(e => {
    if (!attendanceStatuses.includes(e?.status_kehadiran)) throw invalid('Status kehadiran tidak valid.');
    return { member: id(e.id_keanggotaan), status: e.status_kehadiran, note: string(e.keterangan, 'Keterangan', 191, true) };
  });
  if (new Set(parsed.map(p => p.member)).size !== parsed.length) throw invalid('Anggota dobel dalam satu permintaan.');
  const result = await sequelize.transaction(async t => {
    const meeting = await ownMeeting(req, req.params.id, t);
    if (meeting.status_pertemuan === 'DIBATALKAN') throw conflict('Pertemuan dibatalkan.');
    if (meeting.status_presensi === 'BELUM_DIBUKA') throw conflict('Buka sesi presensi terlebih dahulu.');
    const valid = await select(`SELECT k.id FROM keanggotaan_ekstrakurikuler k
      JOIN masa_keanggotaan m ON m.id_keanggotaan_ekstrakurikuler=k.id AND m.tanggal_mulai<=:d AND (m.tanggal_selesai IS NULL OR m.tanggal_selesai>=:d)
      WHERE k.id_periode_ekstrakurikuler=:p AND k.id IN (:ids)`, { p: meeting.id_periode_ekstrakurikuler, d: meeting.tanggal, ids: parsed.map(p => p.member) });
    if (valid.length !== parsed.length) throw invalid('Ada anggota yang bukan anggota aktif kegiatan ini.');
    const corrected = meeting.status_presensi === 'DITUTUP';
    for (const p of parsed) {
      const existing = await models.presensi_ekskul.findOne({ where: { id_pertemuan_ekstrakurikuler: meeting.id, id_keanggotaan_ekstrakurikuler: p.member }, transaction: t, lock: t.LOCK.UPDATE });
      const values = { id_guru_pencatat: req.user.id, status_kehadiran: p.status, waktu_pencatatan: new Date(), keterangan: p.note };
      if (existing) {
        const before = existing.toJSON();
        await existing.update(values, { transaction: t });
        await audit(req, 'presensi_ekskul', existing.id, before, existing.toJSON(), corrected ? 'KOREKSI_PRESENSI_EKSKUL' : 'UBAH_PRESENSI_EKSKUL', t);
      } else {
        const row = await models.presensi_ekskul.create({ id_pertemuan_ekstrakurikuler: meeting.id, id_keanggotaan_ekstrakurikuler: p.member, ...values }, { transaction: t });
        await audit(req, 'presensi_ekskul', row.id, null, row.toJSON(), 'CATAT_PRESENSI_EKSKUL', t);
      }
    }
    return { dicatat: parsed.length, koreksi: corrected };
  });
  send(res, result);
};

// Rekap kehadiran anggota per kegiatan.
exports.recap = async (req, res) => {
  const periodId = await ownPeriod(req, req.params.id);
  const rows = await select(`SELECT k.id AS id_keanggotaan, s.nama, s.nisn,
      SUM(p.status_kehadiran='HADIR') AS hadir, SUM(p.status_kehadiran='IZIN') AS izin,
      SUM(p.status_kehadiran='SAKIT') AS sakit, SUM(p.status_kehadiran='ALFA') AS alfa, COUNT(p.id) AS tercatat
    FROM keanggotaan_ekstrakurikuler k JOIN siswa s ON s.id=k.id_siswa
    LEFT JOIN pertemuan_ekstrakurikuler m ON m.id_periode_ekstrakurikuler=k.id_periode_ekstrakurikuler AND m.status_presensi='DITUTUP'
    LEFT JOIN presensi_ekstrakurikuler p ON p.id_pertemuan_ekstrakurikuler=m.id AND p.id_keanggotaan_ekstrakurikuler=k.id
    WHERE k.id_periode_ekstrakurikuler=:periodId GROUP BY k.id, s.nama, s.nisn ORDER BY s.nama`, { periodId });
  const [{ total }] = await select(`SELECT COUNT(*) AS total FROM pertemuan_ekstrakurikuler WHERE id_periode_ekstrakurikuler=:periodId AND status_presensi='DITUTUP'`, { periodId });
  send(res, { total_pertemuan: Number(total), anggota: rows.map(r => {
    const hadir = Number(r.hadir || 0), tercatat = Number(r.tercatat || 0);
    return { ...r, hadir, izin: Number(r.izin || 0), sakit: Number(r.sakit || 0), alfa: Number(r.alfa || 0), tercatat,
      persen_hadir: tercatat ? Math.round(hadir / tercatat * 1000) / 10 : null };
  }) });
};

// Prestasi dicatat pembina untuk anggota aktif kegiatannya. Siswa dari ekskul lain boleh ikut lomba
// ekskul ini (mengikuti catatan A2): peserta tidak harus anggota, cukup siswa yang terdaftar.
exports.listAchievements = async (req, res) => {
  const periodId = await ownPeriod(req, req.params.id);
  const rows = await models.portofolio.findAll({ where: { id_periode_ekstrakurikuler: periodId, jenis: 'PRESTASI' },
    order: [['tanggal', 'DESC'], ['id', 'DESC']], limit: 100,
    include: [{ model: models.peserta, as: 'peserta_id_portofolio', separate: true, include: [{ model: models.siswa, as: 'siswa', attributes: ['id', 'nama'] }] },
      { model: models.lampiran, as: 'lampiran_id_portofolio', separate: true, attributes: ['id', 'nama_berkas', 'jenis_berkas'] }] });
  send(res, rows);
};
exports.createAchievement = async (req, res) => {
  const periodId = await ownPeriod(req, req.params.id);
  const body = req.body || {};
  if (!Array.isArray(body.peserta) || body.peserta.length < 1 || body.peserta.length > 100) throw invalid('Pilih 1 sampai 100 siswa.');
  const ids = [...new Set(body.peserta.map(id))];
  const level = string(body.tingkat_prestasi, 'Tingkat prestasi', 191);
  if (!levels.includes(level)) throw invalid('Tingkat prestasi tidak valid.');
  const data = { id_periode_ekstrakurikuler: periodId, id_guru_pencatat: req.user.id, jenis: 'PRESTASI',
    judul: string(body.judul, 'Judul', 191), tanggal: date(body.tanggal, 'Tanggal prestasi'),
    deskripsi: string(body.deskripsi, 'Deskripsi', 20000, true), tingkat_prestasi: level,
    hasil_prestasi: string(body.hasil_prestasi, 'Hasil prestasi', 191), nama_tim: string(body.nama_tim, 'Nama tim', 191, ids.length === 1) };
  const saved = await sequelize.transaction(async t => {
    if (await models.siswa.count({ where: { id: ids }, transaction: t }) !== ids.length) throw invalid('Peserta tidak ditemukan.');
    const row = await models.portofolio.create(data, { transaction: t });
    await models.peserta.bulkCreate(ids.map(s => ({ id_portofolio: row.id, id_siswa: s })), { transaction: t });
    await audit(req, 'portofolio', row.id, null, { ...row.toJSON(), peserta: ids.join(',') }, 'CATAT_PRESTASI', t);
    return row;
  });
  send(res, saved, 201);
};
// Lampiran bukti hanya boleh ditambahkan ke prestasi kegiatan yang dibina guru ini.
exports.ownAchievement = async (req, res, next) => {
  const item = await models.portofolio.findByPk(id(req.params.id));
  if (!item || item.jenis !== 'PRESTASI' || item.id_periode_ekstrakurikuler == null) throw missing();
  if (!(await assignedPeriods(req.user.id)).includes(item.id_periode_ekstrakurikuler)) throw fail(403, 'FORBIDDEN', 'Anda bukan pembina kegiatan ini.');
  next();
};
exports.studentLookup = async (req, res) => {
  const q = string(req.query.q, 'Pencarian', 100, true);
  const rows = await models.siswa.findAll({ where: { status_siswa: 'AKTIF', ...(q ? { [Op.or]: [{ nama: { [Op.substring]: q } }, { nisn: { [Op.substring]: q } }] } : {}) },
    attributes: ['id', 'nama', 'nisn'], order: [['nama', 'ASC']], limit: 30 });
  send(res, rows);
};
