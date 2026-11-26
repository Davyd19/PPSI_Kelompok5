// Presensi sekolah utama (pagi & salat Zuhur) berbasis QR.
// Guru pertama yang membuka sesi membuat SATU QR untuk sesi itu (sekali per hari per jenis);
// QR tidak berganti dan berlaku sampai sesi ditutup/akhir hari, sehingga dapat dibagikan ke
// seluruh siswa. Guru lain tidak dapat membuat QR baru, hanya menampilkan QR yang sama.
// Bila pemindaian gagal, guru menginput manual dengan alasan wajib (berjejak).
const { createHash, createHmac, timingSafeEqual } = require('node:crypto');
const { Op, QueryTypes } = require('sequelize');
const { sequelize, models } = require('../models');
const { today } = require('./auth.controller');
const audit = require('../utils/audit');
const fail = require('../utils/api-error');
const { id, string, invalid, missing } = require('./kesiswaan.controller').validation;

const TYPES = ['PAGI', 'ZUHUR'];
const DEFAULT_LIMIT = { PAGI: '07:15', ZUHUR: '12:45' };
const QR_PREFIX = 'SIMK-PRESENSI';
// Pilihan waktu berlaku QR (menit). QR dapat ditutup lebih awal secara manual.
const QR_MINUTES = [5, 10, 15, 30, 60];
const DEFAULT_QR_MINUTES = 15;
const MANUAL_STATUS = ['HADIR', 'TERLAMBAT', 'IZIN', 'SAKIT', 'ALFA', 'PENGECUALIAN_SAH'];
const FILTER_STATUS = [...MANUAL_STATUS, 'BELUM_DIISI'];

const conflict = message => fail(409, 'STATE_CONFLICT', message);
const select = (sql, replacements = {}, transaction) =>
  sequelize.query(sql, { type: QueryTypes.SELECT, replacements, transaction });
const digest = token => createHash('sha256').update(token).digest('hex');
const wib = (day, hhmm) => new Date(`${day}T${hhmm}:00+07:00`);

function plain(row) {
  const { hash_token_qr, ...rest } = row.toJSON();
  return rest;
}
// Token QR statis per sesi, diturunkan dari rahasia server sehingga QR yang sama dapat
// ditampilkan ulang tanpa menyimpan token mentah di database (yang disimpan hanya hash-nya).
function qrToken(session) {
  const secret = process.env.AUTH_SECRET;
  if (!secret || secret.length < 32) throw fail(503, 'AUTH_NOT_CONFIGURED', 'Konfigurasi autentikasi belum lengkap.');
  return createHmac('sha256', secret)
    .update(`presensi-qr:${session.id}:${session.tanggal}:${session.jenis_sesi}`)
    .digest('base64url');
}
function qrMinutes(value) {
  const minutes = value === undefined || value === null ? DEFAULT_QR_MINUTES : Number(value);
  if (!QR_MINUTES.includes(minutes)) throw invalid(`Waktu berlaku QR harus salah satu dari ${QR_MINUTES.join(', ')} menit.`);
  return minutes;
}
// Masa berlaku QR: sekarang + durasi pilihan guru, tetapi tidak melewati akhir hari sesi (WIB).
function qrExpiry(session, minutes) {
  const endOfDay = new Date(`${session.tanggal}T23:59:59.999+07:00`).getTime();
  return new Date(Math.min(Date.now() + minutes * 60000, endOfDay));
}
// Dipanggil sekali saat sesi dibuka.
function issueQr(session, minutes) {
  return {
    hash_token_qr: digest(qrToken(session)),
    token_kedaluwarsa: qrExpiry(session, minutes)
  };
}
function qrView(session) {
  const until = new Date(session.token_kedaluwarsa);
  return {
    kode: `${QR_PREFIX}:${session.id}:${qrToken(session)}`,
    jenis_sesi: session.jenis_sesi,
    tanggal: session.tanggal,
    berlaku_sampai: until.toISOString(),
    aktif: until > new Date(),
    pilihan_menit: QR_MINUTES
  };
}
// Sesi aktif hari ini beserta hash QR-nya (scope bawaan menyembunyikan hash).
async function lockedQrSession(req, t) {
  const row = await models.sesi.unscoped().findByPk(id(req.params.id), { transaction: t, lock: t.LOCK.UPDATE });
  if (!row) throw missing();
  if (row.status !== 'AKTIF' || row.tanggal !== today() || !row.hash_token_qr) {
    throw conflict('Sesi sudah ditutup; QR tidak berlaku lagi.');
  }
  return row;
}

// Siswa yang wajib presensi pada sesi: siswa dengan riwayat kelas aktif pada tanggal sesi
// di tahun ajaran semester sesi (sama dengan dasar rekap Kesiswaan).
function rosterSql(extra = '') {
  return `SELECT ss.id AS id_sesi, s.id AS id_siswa, s.nama, s.nisn, s.nis, c.id AS id_kelas, c.nama AS kelas, c.tingkat,
    COALESCE(p.status_kehadiran,'BELUM_DIISI') AS status_kehadiran, p.metode, p.waktu_presensi,
    p.keterangan, g.nama AS pencatat
    FROM sesi_presensi_sekolah ss
    JOIN semester sm ON sm.id=ss.id_semester
    JOIN kelas c ON c.id_tahun_ajaran=sm.id_tahun_ajaran
    JOIN riwayat_kelas_siswa r ON r.id_kelas=c.id AND r.tanggal_mulai<=ss.tanggal
      AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=ss.tanggal)
    JOIN siswa s ON s.id=r.id_siswa
    LEFT JOIN presensi_sekolah p ON p.id_sesi_presensi_sekolah=ss.id AND p.id_siswa=s.id
    LEFT JOIN guru g ON g.id=p.id_guru_pencatat
    WHERE ss.id IN (:sessions) ${extra}`;
}
async function summaries(ids, transaction) {
  const result = Object.fromEntries(ids.map(i => [i, { total: 0, ...Object.fromEntries(FILTER_STATUS.map(s => [s, 0])) }]));
  if (!ids.length) return result;
  const rows = await select(`SELECT id_sesi, status_kehadiran, COUNT(*) AS total FROM (${rosterSql()}) x
    GROUP BY id_sesi, status_kehadiran`, { sessions: ids }, transaction);
  for (const r of rows) {
    result[r.id_sesi][r.status_kehadiran] = Number(r.total);
    result[r.id_sesi].total += Number(r.total);
  }
  return result;
}
async function sessionView(row, user, transaction) {
  const data = plain(row);
  const [opener] = await select('SELECT nama FROM guru WHERE id=:id', { id: data.id_guru_pembuka }, transaction);
  return {
    ...data,
    guru_pembuka: opener?.nama ?? null,
    milik_saya: data.id_guru_pembuka === user.id,
    ringkasan: (await summaries([data.id], transaction))[data.id]
  };
}
async function lockedSession(req, t) {
  const row = await models.sesi.findByPk(id(req.params.id), { transaction: t, lock: t.LOCK.UPDATE });
  if (!row) throw missing();
  return row;
}

// GET /guru/presensi/sesi — sesi hari ini (PAGI & ZUHUR) beserta ringkasannya.
exports.todaySessions = async (req, res) => {
  const day = today();
  const [semester, rows] = await Promise.all([
    models.semester.findOne({ where: { tanggal_mulai: { [Op.lte]: day }, tanggal_selesai: { [Op.gte]: day } } }),
    models.sesi.findAll({ where: { tanggal: day }, order: [['jenis_sesi', 'ASC'], ['id', 'ASC']] })
  ]);
  const counts = await summaries(rows.map(r => r.id));
  const openers = rows.length ? await select('SELECT id, nama FROM guru WHERE id IN (:ids)', { ids: rows.map(r => r.id_guru_pembuka) }) : [];
  const names = Object.fromEntries(openers.map(o => [o.id, o.nama]));
  res.json({ data: {
    tanggal: day,
    semester: semester ? { id: semester.id, nama: semester.nama } : null,
    batas_bawaan: DEFAULT_LIMIT,
    sesi: rows.map(r => ({ ...plain(r), guru_pembuka: names[r.id_guru_pembuka] ?? null,
      milik_saya: r.id_guru_pembuka === req.user.id, ringkasan: counts[r.id] }))
  } });
};

// POST /guru/presensi/sesi — membuka sesi presensi sekolah hari ini.
exports.open = async (req, res) => {
  const type = req.body?.jenis_sesi;
  if (!TYPES.includes(type)) throw invalid('Jenis sesi harus PAGI atau ZUHUR.');
  const limit = req.body?.batas_tepat_waktu ?? DEFAULT_LIMIT[type];
  if (typeof limit !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(limit)) throw invalid('Batas tepat waktu harus berformat JJ:MM (WIB).');
  const minutes = qrMinutes(req.body?.berlaku_menit);
  const day = today();
  const result = await sequelize.transaction(async t => {
    // Kunci semester agar dua guru tidak membuka sesi yang sama bersamaan.
    const semester = await models.semester.findOne({
      where: { tanggal_mulai: { [Op.lte]: day }, tanggal_selesai: { [Op.gte]: day } },
      transaction: t, lock: t.LOCK.UPDATE
    });
    if (!semester) throw conflict('Belum ada semester yang berlaku hari ini.');
    // QR tiap sesi hanya dibuat sekali sehari (dijamin juga oleh unique index tanggal+jenis).
    const existing = await models.sesi.findOne({ where: { tanggal: day, jenis_sesi: type }, transaction: t });
    if (existing) {
      const [opener] = await select('SELECT nama FROM guru WHERE id=:id', { id: existing.id_guru_pembuka }, t);
      const label = type === 'PAGI' ? 'Presensi pagi' : 'Presensi Zuhur';
      throw conflict(existing.id_guru_pembuka === req.user.id
        ? `${label} hari ini sudah Anda buat. QR tidak dapat dibuat ulang.`
        : `QR ${label.toLowerCase()} hari ini sudah dibuat oleh ${opener?.nama ?? 'guru lain'}.`);
    }
    const row = await models.sesi.create({
      id_semester: semester.id, id_guru_pembuka: req.user.id, jenis_sesi: type, tanggal: day,
      waktu_buka: new Date(), waktu_tutup: null, batas_tepat_waktu: wib(day, limit), status: 'AKTIF',
      hash_token_qr: null, token_kedaluwarsa: null
    }, { transaction: t });
    await row.update(issueQr(row, minutes), { transaction: t });
    await audit(req, 'sesi', row.id, null, plain(row), 'BUKA_SESI_PRESENSI', t);
    return { sesi: await sessionView(row, req.user, t), qr: qrView(row) };
  });
  res.status(201).json({ data: result });
};

// GET /guru/presensi/sesi/:id/qr — menampilkan ULANG QR yang sudah dibuat (tidak membuat baru).
// QR yang sama boleh ditampilkan guru mana pun karena memang dibagikan ke seluruh siswa.
exports.qr = async (req, res) => {
  const row = await models.sesi.findByPk(id(req.params.id));
  if (!row) throw missing();
  if (row.status !== 'AKTIF' || row.tanggal !== today() || !row.hash_token_qr) {
    throw conflict('Sesi sudah ditutup; QR tidak berlaku lagi.');
  }
  res.set('Cache-Control', 'no-store').json({ data: qrView(row) });
};

// POST /guru/presensi/sesi/:id/qr/tutup — menutup masa berlaku QR lebih awal secara manual.
// Sesi tetap AKTIF sehingga guru masih dapat menginput presensi manual.
exports.closeQr = async (req, res) => {
  const result = await sequelize.transaction(async t => {
    const row = await lockedQrSession(req, t);
    if (!row.token_kedaluwarsa || new Date(row.token_kedaluwarsa) <= new Date()) throw conflict('QR sudah tidak berlaku.');
    const before = plain(row);
    await row.update({ token_kedaluwarsa: new Date() }, { transaction: t });
    await audit(req, 'sesi', row.id, before, plain(row), 'TUTUP_QR_PRESENSI', t);
    return qrView(row);
  });
  res.set('Cache-Control', 'no-store').json({ data: result });
};

// POST /guru/presensi/sesi/:id/qr/berlaku — atur ulang waktu berlaku QR yang SAMA
// (memperpanjang atau mengaktifkan lagi), tanpa membuat QR baru.
exports.extendQr = async (req, res) => {
  const minutes = qrMinutes(req.body?.berlaku_menit);
  const result = await sequelize.transaction(async t => {
    const row = await lockedQrSession(req, t);
    const before = plain(row);
    await row.update({ token_kedaluwarsa: qrExpiry(row, minutes) }, { transaction: t });
    await audit(req, 'sesi', row.id, before, plain(row), 'ATUR_BERLAKU_QR_PRESENSI', t);
    return qrView(row);
  });
  res.set('Cache-Control', 'no-store').json({ data: result });
};

// POST /guru/presensi/sesi/:id/tutup
exports.close = async (req, res) => {
  const result = await sequelize.transaction(async t => {
    const row = await lockedSession(req, t);
    if (row.status !== 'AKTIF') throw conflict('Sesi sudah ditutup.');
    const before = plain(row);
    await row.update({ status: 'DITUTUP', waktu_tutup: new Date(), hash_token_qr: null, token_kedaluwarsa: null }, { transaction: t });
    await audit(req, 'sesi', row.id, before, plain(row), 'TUTUP_SESI_PRESENSI', t);
    return sessionView(row, req.user, t);
  });
  res.json({ data: result });
};

// GET /guru/presensi/sesi/:id/kelas — daftar kelas peserta sesi beserta jumlah yang belum tercatat.
exports.classes = async (req, res) => {
  const row = await models.sesi.findByPk(id(req.params.id));
  if (!row) throw missing();
  const rows = await select(`SELECT id_kelas, kelas, COUNT(*) AS total,
      SUM(status_kehadiran='BELUM_DIISI') AS belum_diisi
    FROM (${rosterSql()}) x GROUP BY id_kelas, kelas ORDER BY kelas`, { sessions: [row.id] });
  res.json({ data: rows.map(r => ({ ...r, total: Number(r.total), belum_diisi: Number(r.belum_diisi) })) });
};

// GET /guru/presensi/sesi/:id/siswa?kelas=&q=&status=&page=
// Dengan filter kelas, seluruh siswa kelas dikembalikan sekaligus (maks. 200).
exports.students = async (req, res) => {
  const row = await models.sesi.findByPk(id(req.params.id));
  if (!row) throw missing();
  const q = string(req.query.q, 'Pencarian', 100, true);
  const status = req.query.status || null;
  if (status && !FILTER_STATUS.includes(status)) throw invalid('Status tidak valid.');
  const kelas = req.query.kelas === undefined ? null : id(req.query.kelas);
  const page = req.query.page === undefined ? 1 : id(req.query.page);
  const size = kelas ? 200 : 50;
  const filters = { sessions: [row.id], q: q ? `%${q}%` : null, status, kelas, size, offset: (page - 1) * size };
  const sql = rosterSql(`AND (:q IS NULL OR s.nama LIKE :q OR s.nisn LIKE :q OR c.nama LIKE :q)
    AND (:kelas IS NULL OR c.id=:kelas)
    AND (:status IS NULL OR COALESCE(p.status_kehadiran,'BELUM_DIISI')=:status)`);
  const [rows, [{ total }]] = await Promise.all([
    select(sql + ' ORDER BY c.nama, s.nama, s.id LIMIT :size OFFSET :offset', filters),
    select(`SELECT COUNT(*) AS total FROM (${sql}) x`, filters)
  ]);
  res.json({ data: rows, meta: { total: Number(total), page, page_size: size } });
};

// POST /guru/presensi/sesi/:id/manual-kelas — input manual massal satu kelas.
// Body: { id_kelas, alasan?, entri: [{ id_siswa, status_kehadiran, alasan? }] }. Alasan per siswa
// diutamakan; `alasan` di luar entri menjadi alasan umum untuk baris yang kosong. Semua entri
// disimpan atau tidak sama sekali; tiap baris mencatat guru pencatat, waktu, alasan, dan audit.
exports.manualBatch = async (req, res) => {
  const classId = id(req.body?.id_kelas);
  const common = string(req.body?.alasan, 'Alasan umum', 191, true);
  const entries = req.body?.entri;
  if (!Array.isArray(entries) || !entries.length || entries.length > 200) throw invalid('Isi presensi minimal satu siswa (maks. 200).');
  const parsed = entries.map(e => {
    if (!MANUAL_STATUS.includes(e?.status_kehadiran)) throw invalid('Status kehadiran tidak valid.');
    const reason = string(e?.alasan, 'Alasan siswa', 191, true) ?? common;
    if (!reason || reason.length < 5) throw invalid('Setiap siswa wajib memiliki alasan minimal 5 karakter.');
    return { studentId: id(e?.id_siswa), status: e.status_kehadiran, reason };
  });
  if (new Set(parsed.map(e => e.studentId)).size !== parsed.length) throw invalid('Siswa yang sama dikirim lebih dari sekali.');
  const saved = await sequelize.transaction(async t => {
    const session = await lockedSession(req, t);
    if (session.status !== 'AKTIF') throw conflict('Sesi sudah ditutup. Gunakan fitur Ubah Presensi.');
    const roster = await select(rosterSql('AND c.id=:kelas AND s.id IN (:students)'),
      { sessions: [session.id], kelas: classId, students: parsed.map(e => e.studentId) }, t);
    const byId = new Map(roster.map(r => [r.id_siswa, r]));
    if (parsed.some(e => !byId.has(e.studentId))) throw invalid('Ada siswa yang tidak terdaftar di kelas ini untuk sesi ini.');
    const recorded = parsed.filter(e => byId.get(e.studentId).status_kehadiran !== 'BELUM_DIISI');
    if (recorded.length) {
      throw conflict('Presensi sudah tercatat untuk: ' + recorded.map(e => byId.get(e.studentId).nama).join(', ') +
        '. Muat ulang daftar; perubahan gunakan fitur Ubah Presensi.');
    }
    const now = new Date();
    const rows = [];
    for (const e of parsed) {
      const row = await models.presensi.create({
        id_sesi_presensi_sekolah: session.id, id_siswa: e.studentId, id_guru_pencatat: req.user.id,
        status_kehadiran: e.status, waktu_presensi: now, metode: 'MANUAL', keterangan: e.reason
      }, { transaction: t });
      await audit({ user: req.user, body: { alasan_tindakan: e.reason } }, 'presensi', row.id, null, row.toJSON(),
        'INPUT_MANUAL_PRESENSI', t);
      rows.push({ id: row.id, id_siswa: e.studentId, status_kehadiran: e.status });
    }
    return rows;
  });
  res.status(201).json({ data: saved });
};

// POST /guru/presensi/sesi/:id/manual — input manual berjejak bila pemindaian gagal.
exports.manual = async (req, res) => {
  const studentId = id(req.body?.id_siswa);
  const status = req.body?.status_kehadiran;
  if (!MANUAL_STATUS.includes(status)) throw invalid('Status kehadiran tidak valid.');
  const reason = string(req.body?.alasan, 'Alasan input manual', 191);
  if (reason.length < 5) throw invalid('Alasan input manual minimal 5 karakter.');
  const saved = await sequelize.transaction(async t => {
    const session = await lockedSession(req, t);
    if (session.status !== 'AKTIF') throw conflict('Sesi sudah ditutup. Gunakan fitur Ubah Presensi.');
    const [enrolled] = await select(rosterSql('AND s.id=:student'), { sessions: [session.id], student: studentId }, t);
    if (!enrolled) throw invalid('Siswa tidak terdaftar di kelas aktif untuk sesi ini.');
    if (enrolled.status_kehadiran !== 'BELUM_DIISI') {
      throw conflict(`Presensi siswa sudah tercatat (${enrolled.status_kehadiran}). Gunakan fitur Ubah Presensi.`);
    }
    const row = await models.presensi.create({
      id_sesi_presensi_sekolah: session.id, id_siswa: studentId, id_guru_pencatat: req.user.id,
      status_kehadiran: status, waktu_presensi: new Date(), metode: 'MANUAL', keterangan: reason
    }, { transaction: t });
    await audit({ user: req.user, body: { alasan_tindakan: reason } }, 'presensi', row.id, null, row.toJSON(),
      'INPUT_MANUAL_PRESENSI', t);
    return row;
  });
  res.status(201).json({ data: saved });
};

// POST /guru/presensi/sesi/:id/koreksi — use case "Mengubah Presensi".
// Guru mengoreksi status presensi siswa yang sudah tercatat (mis. mengantisipasi kecurangan
// pemindaian QR), atau mengisi presensi yang belum tercatat pada sesi yang sudah ditutup.
// Body: { id_siswa, status_kehadiran, alasan }. Alasan wajib; nilai lama & baru tercatat di audit.
exports.correct = async (req, res) => {
  const studentId = id(req.body?.id_siswa);
  const status = req.body?.status_kehadiran;
  if (!MANUAL_STATUS.includes(status)) throw invalid('Status kehadiran tidak valid.');
  const reason = string(req.body?.alasan, 'Alasan perubahan', 191);
  if (reason.length < 5) throw invalid('Alasan perubahan minimal 5 karakter.');
  const saved = await sequelize.transaction(async t => {
    const session = await lockedSession(req, t);
    if (session.tanggal > today()) throw invalid('Sesi belum berlangsung.');
    const [enrolled] = await select(rosterSql('AND s.id=:student'), { sessions: [session.id], student: studentId }, t);
    if (!enrolled) throw invalid('Siswa tidak terdaftar di kelas aktif untuk sesi ini.');
    const row = await models.presensi.findOne({
      where: { id_sesi_presensi_sekolah: session.id, id_siswa: studentId },
      transaction: t, lock: t.LOCK.UPDATE
    });
    const auditReq = { user: req.user, body: { alasan_tindakan: reason } };
    if (!row) {
      if (session.status === 'AKTIF') {
        throw conflict('Presensi siswa belum tercatat dan sesi masih dibuka. Gunakan Input Manual.');
      }
      const created = await models.presensi.create({
        id_sesi_presensi_sekolah: session.id, id_siswa: studentId, id_guru_pencatat: req.user.id,
        status_kehadiran: status, waktu_presensi: new Date(), metode: 'MANUAL', keterangan: reason
      }, { transaction: t });
      await audit(auditReq, 'presensi', created.id, null, created.toJSON(), 'UBAH_PRESENSI', t);
      return { id: created.id, status_sebelum: 'BELUM_DIISI', status_kehadiran: status };
    }
    if (row.status_kehadiran === status) throw invalid('Status kehadiran sama dengan sebelumnya.');
    const before = row.toJSON();
    // Waktu & metode presensi asli dipertahankan sebagai jejak; pencatat menjadi guru pengoreksi.
    await row.update({ status_kehadiran: status, keterangan: reason, id_guru_pencatat: req.user.id }, { transaction: t });
    await audit(auditReq, 'presensi', row.id, before, row.toJSON(), 'UBAH_PRESENSI', t);
    return { id: row.id, status_sebelum: before.status_kehadiran, status_kehadiran: status };
  });
  res.json({ data: saved });
};

// POST /student/presensi/scan — siswa memindai QR dinamis dari perangkat guru.
exports.scan = async (req, res) => {
  if (req.authPlatform !== 'mobile' || req.user.kind !== 'siswa') {
    throw fail(403, 'FORBIDDEN', 'Pemindaian presensi hanya untuk siswa.');
  }
  const match = typeof req.body?.kode === 'string'
    ? new RegExp(`^${QR_PREFIX}:(\\d{1,10}):([A-Za-z0-9_-]{43})$`).exec(req.body.kode.trim()) : null;
  const rejected = () => fail(422, 'QR_INVALID', 'QR tidak valid, sudah kedaluwarsa, atau sesi sudah ditutup.');
  if (!match) throw rejected();
  const saved = await sequelize.transaction(async t => {
    const session = await models.sesi.findByPk(Number(match[1]), { transaction: t, lock: t.LOCK.UPDATE });
    const now = new Date();
    if (!session || session.status !== 'AKTIF' || session.tanggal !== today() || !session.hash_token_qr ||
      !session.token_kedaluwarsa || session.token_kedaluwarsa <= now) throw rejected();
    const expected = Buffer.from(session.hash_token_qr, 'hex');
    const actual = Buffer.from(digest(match[2]), 'hex');
    if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) throw rejected();
    const [enrolled] = await select(rosterSql("AND s.id=:student AND s.status_siswa='AKTIF'"),
      { sessions: [session.id], student: req.user.id }, t);
    if (!enrolled) throw fail(403, 'FORBIDDEN', 'Anda tidak terdaftar pada sesi presensi ini.');
    if (enrolled.status_kehadiran !== 'BELUM_DIISI') throw conflict('Presensi Anda untuk sesi ini sudah tercatat.');
    const status = session.batas_tepat_waktu && now > session.batas_tepat_waktu ? 'TERLAMBAT' : 'HADIR';
    const row = await models.presensi.create({
      id_sesi_presensi_sekolah: session.id, id_siswa: req.user.id, id_guru_pencatat: null,
      status_kehadiran: status, waktu_presensi: now, metode: 'QR', keterangan: null
    }, { transaction: t });
    await models.audit.create({
      id_siswa: req.user.id, jenis_tindakan: 'PRESENSI_QR', nama_tabel: 'presensi_sekolah',
      identitas_data: String(row.id), waktu: now, alasan: null
    }, { transaction: t });
    return { id: row.id, jenis_sesi: session.jenis_sesi, status_kehadiran: status, waktu_presensi: now };
  });
  res.status(201).json({ data: saved });
};
