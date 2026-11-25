'use strict';
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { Op } = require('sequelize');
const { models, sequelize } = require('../models');
const fail = require('../utils/api-error');

const VALID_MANUAL_STATUSES = new Set([
  'HADIR',
  'TERLAMBAT',
  'IZIN',
  'SAKIT',
  'ALFA',
  'PENGECUALIAN_SAH',
]);

function requireGuru(req) {
  if (req.user.kind !== 'guru' || req.user.roles?.includes('KEPALA_SEKOLAH')) {
    throw fail(403, 'FORBIDDEN', 'Fitur ini hanya dapat diakses oleh Guru aktif.');
  }
}

function jakartaDate(d = new Date()) {
  if (typeof d === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(d)) return d;
  const dt = d instanceof Date ? d : new Date(d);
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(dt);
}

function parseWibLimit(dateStr, raw) {
  if (!raw || typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (/^\d{2}:\d{2}(:\d{2})?$/.test(trimmed)) {
    const hms = trimmed.length === 5 ? `${trimmed}:00` : trimmed;
    return new Date(`${dateStr}T${hms}+07:00`);
  }
  const parsed = new Date(trimmed);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

async function getActiveStudentClassMap() {
  const rkRows = await models.riwayat_kelas.findAll({
    where: { tanggal_selesai: null },
    include: [{ model: models.kelas, as: 'kelas', required: false }],
    order: [['id', 'DESC']],
  });
  const map = new Map();
  for (const rk of rkRows) {
    if (!map.has(rk.id_siswa)) {
      map.set(rk.id_siswa, {
        id_kelas: rk.id_kelas,
        kelas: rk.kelas?.nama ?? '-',
      });
    }
  }
  return map;
}

async function buildSessionSummary(sessionId, activeStudentsCount) {
  const rows = await models.presensi.findAll({
    where: { id_sesi_presensi_sekolah: sessionId },
    attributes: ['status_kehadiran'],
    raw: true,
  });
  const counts = {
    total: activeStudentsCount,
    HADIR: 0,
    TERLAMBAT: 0,
    IZIN: 0,
    SAKIT: 0,
    ALFA: 0,
    PENGECUALIAN_SAH: 0,
    BELUM_DIISI: 0,
  };
  for (const r of rows) {
    if (counts[r.status_kehadiran] !== undefined) counts[r.status_kehadiran]++;
  }
  counts.BELUM_DIISI = Math.max(0, activeStudentsCount - rows.length);
  return counts;
}

async function formatSession(s, userId, activeStudentsCount) {
  const opener = s.guru_pembuka ?? (await models.guru.findByPk(s.id_guru_pembuka));
  const summary = await buildSessionSummary(s.id, activeStudentsCount);
  return {
    id: s.id,
    jenis_sesi: s.jenis_sesi,
    status: s.status,
    waktu_buka: s.waktu_buka ? new Date(s.waktu_buka).toISOString() : null,
    waktu_tutup: s.waktu_tutup ? new Date(s.waktu_tutup).toISOString() : null,
    batas_tepat_waktu: s.batas_tepat_waktu ? new Date(s.batas_tepat_waktu).toISOString() : null,
    guru_pembuka: opener?.nama ?? null,
    milik_saya: s.id_guru_pembuka === userId,
    ringkasan: summary,
  };
}

// ---------------------------------------------------------------------------
// 1. PRESENSI SEKOLAH (SESI, QR, MANUAL)
// ---------------------------------------------------------------------------
exports.todaySessions = async (req, res) => {
  requireGuru(req);
  const today = jakartaDate();

  const semester = await models.semester.findOne({
    where: { tanggal_mulai: { [Op.lte]: today }, tanggal_selesai: { [Op.gte]: today } },
    order: [['tanggal_mulai', 'DESC']],
  });

  const sessions = await models.sesi.findAll({
    where: { tanggal: today },
    include: [{ model: models.guru, as: 'guru_pembuka', required: false }],
    order: [['id', 'ASC']],
  });

  const activeStudentsCount = await models.siswa.count({
    where: { status_siswa: 'AKTIF' },
  });

  const formatted = [];
  for (const s of sessions) {
    formatted.push(await formatSession(s, req.user.id, activeStudentsCount));
  }

  res.set('Cache-Control', 'no-store').json({
    data: {
      tanggal: today,
      semester: semester ? { id: semester.id, nama: semester.nama } : null,
      batas_bawaan: { PAGI: '07:15', ZUHUR: '12:45' },
      sesi: formatted,
    },
  });
};

exports.openSession = async (req, res) => {
  requireGuru(req);
  const { jenis_sesi, batas_tepat_waktu } = req.body ?? {};
  if (!['PAGI', 'ZUHUR'].includes(jenis_sesi)) {
    throw fail(422, 'VALIDATION_ERROR', 'Jenis sesi harus PAGI atau ZUHUR.');
  }

  const today = jakartaDate();
  const semester = await models.semester.findOne({
    where: { tanggal_mulai: { [Op.lte]: today }, tanggal_selesai: { [Op.gte]: today } },
    order: [['tanggal_mulai', 'DESC']],
  });
  if (!semester) {
    throw fail(422, 'NO_ACTIVE_SEMESTER', 'Tidak ada semester aktif untuk tanggal hari ini.');
  }

  const existing = await models.sesi.findOne({
    where: { tanggal: today, jenis_sesi },
  });
  if (existing) {
    throw fail(409, 'SESSION_EXISTS', `Sesi ${jenis_sesi} hari ini sudah pernah dibuka.`);
  }

  const defaultLimit = jenis_sesi === 'PAGI' ? '07:15' : '12:45';
  const limitDate = parseWibLimit(today, batas_tepat_waktu || defaultLimit);
  if (!limitDate) {
    throw fail(422, 'VALIDATION_ERROR', 'Format batas tepat waktu tidak valid.');
  }

  const qrCode = `SMAN12-${today}-${jenis_sesi}-${crypto.randomBytes(6).toString('hex').toUpperCase()}`;
  const validUntil = new Date(`${today}T23:59:59+07:00`);

  const created = await models.sesi.create({
    id_semester: semester.id,
    id_guru_pembuka: req.user.id,
    jenis_sesi,
    tanggal: today,
    waktu_buka: new Date(),
    waktu_tutup: null,
    batas_tepat_waktu: limitDate,
    status: 'AKTIF',
    hash_token_qr: qrCode,
    token_kedaluwarsa: validUntil,
  });

  const activeStudentsCount = await models.siswa.count({
    where: { status_siswa: 'AKTIF' },
  });

  res.status(201).set('Cache-Control', 'no-store').json({
    data: {
      sesi: await formatSession(created, req.user.id, activeStudentsCount),
      qr: {
        kode: qrCode,
        berlaku_sampai: validUntil.toISOString(),
      },
    },
  });
};

exports.sessionQr = async (req, res) => {
  requireGuru(req);
  const sessionId = parseInt(req.params.id, 10);
  const sesi = await models.sesi.findByPk(sessionId);
  if (!sesi) throw fail(404, 'NOT_FOUND', 'Sesi presensi tidak ditemukan.');
  if (sesi.status !== 'AKTIF' && sesi.status !== 'BUKA') {
    throw fail(422, 'SESSION_CLOSED', 'Sesi presensi sudah ditutup.');
  }

  let kode = sesi.hash_token_qr;
  let validUntil = sesi.token_kedaluwarsa ? new Date(sesi.token_kedaluwarsa) : null;
  if (!kode || !validUntil) {
    const tanggalStr = typeof sesi.tanggal === 'string' ? sesi.tanggal.slice(0, 10) : jakartaDate(sesi.tanggal);
    kode = kode || `SMAN12-${tanggalStr}-${sesi.jenis_sesi}-${crypto.randomBytes(6).toString('hex').toUpperCase()}`;
    validUntil = validUntil || new Date(`${tanggalStr}T23:59:59+07:00`);
    await sesi.update({ hash_token_qr: kode, token_kedaluwarsa: validUntil });
  }

  res.set('Cache-Control', 'no-store').json({
    data: {
      kode,
      berlaku_sampai: validUntil.toISOString(),
    },
  });
};

exports.closeSession = async (req, res) => {
  requireGuru(req);
  const sessionId = parseInt(req.params.id, 10);
  const sesi = await models.sesi.findByPk(sessionId, {
    include: [{ model: models.guru, as: 'guru_pembuka', required: false }],
  });
  if (!sesi) throw fail(404, 'NOT_FOUND', 'Sesi presensi tidak ditemukan.');

  if (sesi.status !== 'DITUTUP') {
    await sesi.update({ status: 'DITUTUP', waktu_tutup: new Date() });
  }

  const activeStudentsCount = await models.siswa.count({
    where: { status_siswa: 'AKTIF' },
  });

  res.set('Cache-Control', 'no-store').json({
    data: await formatSession(sesi, req.user.id, activeStudentsCount),
  });
};

exports.sessionClasses = async (req, res) => {
  requireGuru(req);
  const sessionId = parseInt(req.params.id, 10);
  const sesi = await models.sesi.findByPk(sessionId);
  if (!sesi) throw fail(404, 'NOT_FOUND', 'Sesi presensi tidak ditemukan.');

  const classes = await models.kelas.findAll({
    where: { status: 'AKTIF' },
    order: [['nama', 'ASC']],
  });

  const activeStudents = await models.siswa.findAll({
    where: { status_siswa: 'AKTIF' },
    attributes: ['id'],
    raw: true,
  });
  const activeStudentIds = new Set(activeStudents.map((s) => s.id));
  const classMap = await getActiveStudentClassMap();

  const recordedRows = await models.presensi.findAll({
    where: { id_sesi_presensi_sekolah: sessionId },
    attributes: ['id_siswa'],
    raw: true,
  });
  const recordedIds = new Set(recordedRows.map((r) => r.id_siswa));

  const totals = new Map();
  const pending = new Map();
  for (const sid of activeStudentIds) {
    const info = classMap.get(sid);
    if (!info) continue;
    totals.set(info.id_kelas, (totals.get(info.id_kelas) ?? 0) + 1);
    if (!recordedIds.has(sid)) {
      pending.set(info.id_kelas, (pending.get(info.id_kelas) ?? 0) + 1);
    }
  }

  const data = classes.map((c) => ({
    id_kelas: c.id,
    kelas: c.nama,
    total: totals.get(c.id) ?? 0,
    belum_diisi: pending.get(c.id) ?? 0,
  }));

  res.set('Cache-Control', 'no-store').json({ data });
};

exports.sessionStudents = async (req, res) => {
  requireGuru(req);
  const sessionId = parseInt(req.params.id, 10);
  const sesi = await models.sesi.findByPk(sessionId);
  if (!sesi) throw fail(404, 'NOT_FOUND', 'Sesi presensi tidak ditemukan.');

  const classIdFilter = req.query.kelas ? parseInt(req.query.kelas, 10) : null;
  const query = typeof req.query.q === 'string' ? req.query.q.trim().toLowerCase() : '';
  const statusFilter = typeof req.query.status === 'string' ? req.query.status.trim() : '';

  const students = await models.siswa.findAll({
    where: { status_siswa: 'AKTIF' },
    order: [['nama', 'ASC']],
  });
  const classMap = await getActiveStudentClassMap();

  const presensiRows = await models.presensi.findAll({
    where: { id_sesi_presensi_sekolah: sessionId },
    include: [{ model: models.guru, as: 'guru_pencatat', required: false }],
  });
  const presensiByStudent = new Map();
  for (const p of presensiRows) presensiByStudent.set(p.id_siswa, p);

  const result = [];
  for (const st of students) {
    const cls = classMap.get(st.id);
    if (classIdFilter && cls?.id_kelas !== classIdFilter) continue;
    if (query) {
      const hay = `${st.nama ?? ''} ${st.nis ?? ''} ${st.nisn ?? ''}`.toLowerCase();
      if (!hay.includes(query)) continue;
    }
    const p = presensiByStudent.get(st.id);
    const status = p?.status_kehadiran ?? 'BELUM_DIISI';
    if (statusFilter && status !== statusFilter) continue;

    result.push({
      id_siswa: st.id,
      nama: st.nama,
      nis: st.nis ?? null,
      nisn: st.nisn ?? '-',
      kelas: cls?.kelas ?? '-',
      status_kehadiran: status,
      metode: p?.metode ?? null,
      keterangan: p?.keterangan ?? null,
      pencatat: p?.guru_pencatat?.nama ?? null,
      waktu_presensi: p?.waktu_presensi ? new Date(p.waktu_presensi).toISOString() : null,
    });
  }

  res.set('Cache-Control', 'no-store').json({ data: result });
};

exports.manualAttendance = async (req, res) => {
  requireGuru(req);
  const sessionId = parseInt(req.params.id, 10);
  const { id_siswa, status_kehadiran, alasan } = req.body ?? {};

  const sesi = await models.sesi.findByPk(sessionId);
  if (!sesi) throw fail(404, 'NOT_FOUND', 'Sesi presensi tidak ditemukan.');
  if (!id_siswa || !VALID_MANUAL_STATUSES.has(status_kehadiran)) {
    throw fail(422, 'VALIDATION_ERROR', 'Siswa dan status kehadiran yang valid wajib diisi.');
  }

  const now = new Date();
  const [record, created] = await models.presensi.findOrCreate({
    where: { id_sesi_presensi_sekolah: sessionId, id_siswa },
    defaults: {
      id_guru_pencatat: req.user.id,
      status_kehadiran,
      waktu_presensi: now,
      metode: 'MANUAL',
      keterangan: typeof alasan === 'string' && alasan.trim() ? alasan.trim() : null,
    },
  });
  if (!created) {
    await record.update({
      id_guru_pencatat: req.user.id,
      status_kehadiran,
      waktu_presensi: record.waktu_presensi ?? now,
      metode: 'MANUAL',
      keterangan: typeof alasan === 'string' && alasan.trim() ? alasan.trim() : record.keterangan,
    });
  }

  res.set('Cache-Control', 'no-store').json({
    data: { id: record.id, id_siswa, status_kehadiran },
  });
};

exports.manualBatchAttendance = async (req, res) => {
  requireGuru(req);
  const sessionId = parseInt(req.params.id, 10);
  const { alasan, entri } = req.body ?? {};

  const sesi = await models.sesi.findByPk(sessionId);
  if (!sesi) throw fail(404, 'NOT_FOUND', 'Sesi presensi tidak ditemukan.');
  if (!Array.isArray(entri) || entri.length === 0) {
    throw fail(422, 'VALIDATION_ERROR', 'Daftar entri presensi wajib diisi.');
  }

  const now = new Date();
  const commonNote = typeof alasan === 'string' && alasan.trim() ? alasan.trim() : null;

  await sequelize.transaction(async (transaction) => {
    for (const item of entri) {
      if (!item?.id_siswa || !VALID_MANUAL_STATUSES.has(item.status_kehadiran)) {
        throw fail(422, 'VALIDATION_ERROR', 'Terdapat entri presensi yang tidak valid.');
      }
      const note =
        typeof item.alasan === 'string' && item.alasan.trim()
          ? item.alasan.trim()
          : commonNote;
      const existing = await models.presensi.findOne({
        where: { id_sesi_presensi_sekolah: sessionId, id_siswa: item.id_siswa },
        transaction,
      });
      if (existing) {
        await existing.update(
          {
            id_guru_pencatat: req.user.id,
            status_kehadiran: item.status_kehadiran,
            waktu_presensi: existing.waktu_presensi ?? now,
            metode: 'MANUAL',
            keterangan: note ?? existing.keterangan,
          },
          { transaction },
        );
      } else {
        await models.presensi.create(
          {
            id_sesi_presensi_sekolah: sessionId,
            id_siswa: item.id_siswa,
            id_guru_pencatat: req.user.id,
            status_kehadiran: item.status_kehadiran,
            waktu_presensi: now,
            metode: 'MANUAL',
            keterangan: note,
          },
          { transaction },
        );
      }
    }
  });

  res.set('Cache-Control', 'no-store').json({
    data: { updated: entri.length },
  });
};

// ---------------------------------------------------------------------------
// 2. REKAP KEHADIRAN
// ---------------------------------------------------------------------------
exports.recapClasses = async (req, res) => {
  requireGuru(req);
  const classes = await models.kelas.findAll({
    where: { status: 'AKTIF' },
    order: [['nama', 'ASC']],
  });
  res.set('Cache-Control', 'no-store').json({
    data: classes.map((c) => ({ id: c.id, nama: c.nama })),
  });
};

exports.attendanceRecap = async (req, res) => {
  requireGuru(req);
  const today = jakartaDate();
  const mulai = typeof req.query.mulai === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(req.query.mulai)
    ? req.query.mulai
    : `${today.slice(0, 7)}-01`;
  const sampai = typeof req.query.sampai === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(req.query.sampai)
    ? req.query.sampai
    : today;
  const classIdFilter = req.query.kelas ? parseInt(req.query.kelas, 10) : null;
  const jenis = typeof req.query.jenis === 'string' && ['PAGI', 'ZUHUR'].includes(req.query.jenis)
    ? req.query.jenis
    : null;
  const q = typeof req.query.q === 'string' ? req.query.q.trim().toLowerCase() : '';
  const page = Math.max(1, parseInt(req.query.page ?? '1', 10) || 1);
  const pageSize = 25;

  const sessionWhere = { tanggal: { [Op.between]: [mulai, sampai] } };
  if (jenis) sessionWhere.jenis_sesi = jenis;

  const sessions = await models.sesi.findAll({
    where: sessionWhere,
    order: [['tanggal', 'ASC']],
    raw: true,
  });
  const sessionIds = sessions.map((s) => s.id);

  const students = await models.siswa.findAll({
    where: { status_siswa: 'AKTIF' },
    order: [['nama', 'ASC']],
    raw: true,
  });
  const classMap = await getActiveStudentClassMap();

  const filteredStudents = students.filter((st) => {
    const cls = classMap.get(st.id);
    if (classIdFilter && cls?.id_kelas !== classIdFilter) return false;
    if (q) {
      const hay = `${st.nama ?? ''} ${st.nis ?? ''} ${st.nisn ?? ''}`.toLowerCase();
      if (!hay.includes(q)) return false;
    }
    return true;
  });

  const presensiRows = sessionIds.length > 0 && filteredStudents.length > 0
    ? await models.presensi.findAll({
        where: {
          id_sesi_presensi_sekolah: { [Op.in]: sessionIds },
          id_siswa: { [Op.in]: filteredStudents.map((s) => s.id) },
        },
        attributes: ['id_siswa', 'status_kehadiran'],
        raw: true,
      })
    : [];

  const byStudent = new Map();
  for (const p of presensiRows) {
    if (!byStudent.has(p.id_siswa)) byStudent.set(p.id_siswa, []);
    byStudent.get(p.id_siswa).push(p.status_kehadiran);
  }

  const summary = {
    hadir: 0,
    terlambat: 0,
    izin: 0,
    sakit: 0,
    alfa: 0,
    pengecualian_sah: 0,
    belum_diisi: 0,
    total_sesi: sessions.length * filteredStudents.length,
  };

  const allRows = filteredStudents.map((st) => {
    const statuses = byStudent.get(st.id) ?? [];
    const c = {
      hadir: 0,
      terlambat: 0,
      izin: 0,
      sakit: 0,
      alfa: 0,
      pengecualian_sah: 0,
      belum_diisi: 0,
      total_sesi: sessions.length,
    };
    for (const stCode of statuses) {
      if (stCode === 'HADIR') c.hadir++;
      else if (stCode === 'TERLAMBAT') c.terlambat++;
      else if (stCode === 'IZIN') c.izin++;
      else if (stCode === 'SAKIT') c.sakit++;
      else if (stCode === 'ALFA') c.alfa++;
      else if (stCode === 'PENGECUALIAN_SAH') c.pengecualian_sah++;
    }
    c.belum_diisi = Math.max(0, sessions.length - statuses.length);

    summary.hadir += c.hadir;
    summary.terlambat += c.terlambat;
    summary.izin += c.izin;
    summary.sakit += c.sakit;
    summary.alfa += c.alfa;
    summary.pengecualian_sah += c.pengecualian_sah;
    summary.belum_diisi += c.belum_diisi;

    const cls = classMap.get(st.id);
    return {
      id_siswa: st.id,
      nama: st.nama,
      nis: st.nis ?? null,
      nisn: st.nisn ?? '-',
      kelas: cls?.kelas ?? '-',
      ...c,
    };
  });

  const start = (page - 1) * pageSize;
  const pageRows = allRows.slice(start, start + pageSize);

  res.set('Cache-Control', 'no-store').json({
    data: pageRows,
    meta: {
      total: allRows.length,
      page,
      page_size: pageSize,
      jumlah_sesi: sessions.length,
      ringkasan: summary,
    },
  });
};

exports.studentRecapHistory = async (req, res) => {
  requireGuru(req);
  const studentId = parseInt(req.params.studentId, 10);
  const today = jakartaDate();
  const mulai = typeof req.query.mulai === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(req.query.mulai)
    ? req.query.mulai
    : `${today.slice(0, 7)}-01`;
  const sampai = typeof req.query.sampai === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(req.query.sampai)
    ? req.query.sampai
    : today;
  const jenis = typeof req.query.jenis === 'string' && ['PAGI', 'ZUHUR'].includes(req.query.jenis)
    ? req.query.jenis
    : null;

  const sessionWhere = { tanggal: { [Op.between]: [mulai, sampai] } };
  if (jenis) sessionWhere.jenis_sesi = jenis;

  const sessions = await models.sesi.findAll({
    where: sessionWhere,
    order: [['tanggal', 'DESC'], ['id', 'DESC']],
    raw: true,
  });

  const classMap = await getActiveStudentClassMap();
  const kelasName = classMap.get(studentId)?.kelas ?? '-';

  const presensiRows = sessions.length > 0
    ? await models.presensi.findAll({
        where: {
          id_siswa: studentId,
          id_sesi_presensi_sekolah: { [Op.in]: sessions.map((s) => s.id) },
        },
        include: [{ model: models.guru, as: 'guru_pencatat', required: false }],
      })
    : [];
  const bySession = new Map();
  for (const p of presensiRows) bySession.set(p.id_sesi_presensi_sekolah, p);

  const riwayat = sessions.map((s) => {
    const p = bySession.get(s.id);
    const tanggalStr = typeof s.tanggal === 'string' ? s.tanggal.slice(0, 10) : jakartaDate(s.tanggal);
    return {
      tanggal: tanggalStr,
      jenis_sesi: s.jenis_sesi,
      kelas: kelasName,
      status_kehadiran: p?.status_kehadiran ?? 'BELUM_DIISI',
      status_sesi: s.status,
      metode: p?.metode ?? null,
      waktu_presensi: p?.waktu_presensi ? new Date(p.waktu_presensi).toISOString() : null,
      keterangan: p?.keterangan ?? null,
      pencatat: p?.guru_pencatat?.nama ?? null,
    };
  });

  res.set('Cache-Control', 'no-store').json({ data: { riwayat } });
};

// ---------------------------------------------------------------------------
// 3. LAPORAN PELANGGARAN
// ---------------------------------------------------------------------------
const EVIDENCE_ROOT = path.resolve(__dirname, '../../uploads/pelanggaran');

function countEvidenceFiles(reportId) {
  const dir = path.join(EVIDENCE_ROOT, String(reportId));
  if (!fs.existsSync(dir)) return 0;
  try {
    return fs.readdirSync(dir).length;
  } catch {
    return 0;
  }
}

exports.violationForm = async (req, res) => {
  requireGuru(req);
  const [categories, classes] = await Promise.all([
    models.kategori.findAll({ where: { status: 'AKTIF' }, order: [['nama', 'ASC']] }),
    models.kelas.findAll({ where: { status: 'AKTIF' }, order: [['nama', 'ASC']] }),
  ]);

  res.set('Cache-Control', 'no-store').json({
    data: {
      kategori: categories.map((k) => ({ id: k.id, nama: k.nama, deskripsi: k.deskripsi ?? null })),
      kelas: classes.map((c) => ({ id: c.id, nama: c.nama })),
      maks_bukti: 3,
    },
  });
};

exports.violationStudents = async (req, res) => {
  requireGuru(req);
  const classIdFilter = req.query.kelas ? parseInt(req.query.kelas, 10) : null;
  const q = typeof req.query.q === 'string' ? req.query.q.trim().toLowerCase() : '';

  const students = await models.siswa.findAll({
    where: { status_siswa: 'AKTIF' },
    order: [['nama', 'ASC']],
    raw: true,
  });
  const classMap = await getActiveStudentClassMap();

  const result = [];
  for (const st of students) {
    const cls = classMap.get(st.id);
    if (classIdFilter && cls?.id_kelas !== classIdFilter) continue;
    if (q) {
      const hay = `${st.nama ?? ''} ${st.nis ?? ''} ${st.nisn ?? ''}`.toLowerCase();
      if (!hay.includes(q)) continue;
    }
    result.push({
      id: st.id,
      nama: st.nama,
      kelas: cls?.kelas ?? '-',
      nis: st.nis ?? null,
      nisn: st.nisn ?? null,
    });
  }

  res.set('Cache-Control', 'no-store').json({ data: result });
};

exports.submitViolation = async (req, res) => {
  requireGuru(req);
  const { id_siswa, id_kategori_pelanggaran, waktu_kejadian, tempat_kejadian, uraian } = req.body ?? {};
  const details = {};
  if (!id_siswa) details.id_siswa = 'Siswa wajib dipilih.';
  if (!id_kategori_pelanggaran) details.id_kategori_pelanggaran = 'Kategori pelanggaran wajib dipilih.';
  if (!waktu_kejadian || Number.isNaN(new Date(waktu_kejadian).getTime())) {
    details.waktu_kejadian = 'Waktu kejadian tidak valid.';
  }
  if (typeof uraian !== 'string' || !uraian.trim()) {
    details.uraian = 'Uraian kejadian wajib diisi.';
  }
  if (Object.keys(details).length > 0) {
    throw fail(422, 'VALIDATION_ERROR', 'Periksa kembali isian laporan pelanggaran.', details);
  }

  let aturan = await models.aturan.findOne({
    where: { id_kategori_pelanggaran },
    order: [['nomor_versi', 'DESC']],
  });
  if (!aturan) {
    aturan = await models.aturan.create({
      id_kategori_pelanggaran,
      nomor_versi: 1,
      ketentuan: 'Aturan penanganan standar.',
      berlaku_mulai: jakartaDate(),
      berlaku_sampai: null,
    });
  }

  const place = typeof tempat_kejadian === 'string' && tempat_kejadian.trim() ? tempat_kejadian.trim() : null;
  const fullUraian = place ? `[Lokasi: ${place}] ${uraian.trim()}` : uraian.trim();

  const created = await models.laporan.create({
    id_siswa,
    id_versi_aturan_penanganan: aturan.id,
    id_guru_pelapor: req.user.id,
    waktu_kejadian: new Date(waktu_kejadian),
    uraian: fullUraian,
    status_verifikasi: 'MENUNGGU',
    status_tindak_lanjut: 'MENUNGGU_VERIFIKASI',
  });

  res.status(201).set('Cache-Control', 'no-store').json({
    data: { id: created.id },
  });
};

exports.uploadViolationEvidence = async (req, res) => {
  requireGuru(req);
  const reportId = parseInt(req.params.id, 10);
  const report = await models.laporan.findOne({
    where: { id: reportId, id_guru_pelapor: req.user.id },
  });
  if (!report) throw fail(404, 'NOT_FOUND', 'Laporan pelanggaran tidak ditemukan.');

  const buf = Buffer.isBuffer(req.body) ? req.body : null;
  if (!buf || buf.length === 0) {
    throw fail(422, 'VALIDATION_ERROR', 'Berkas bukti tidak boleh kosong.');
  }

  const rawName = req.get('X-Filename') ? decodeURIComponent(req.get('X-Filename')) : 'bukti.jpg';
  const safeName = `${Date.now()}-${path.basename(rawName).replace(/[^a-zA-Z0-9._-]/g, '_')}`;
  const dir = path.join(EVIDENCE_ROOT, String(reportId));
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, safeName), buf);

  res.status(201).set('Cache-Control', 'no-store').json({
    data: { ok: true, filename: safeName },
  });
};

exports.myViolations = async (req, res) => {
  requireGuru(req);
  const page = Math.max(1, parseInt(req.query.page ?? '1', 10) || 1);
  const pageSize = 20;

  const { count, rows } = await models.laporan.findAndCountAll({
    where: { id_guru_pelapor: req.user.id },
    include: [
      { model: models.siswa, as: 'siswa', required: true },
      {
        model: models.aturan,
        as: 'versi_aturan_penanganan',
        required: true,
        include: [{ model: models.kategori, as: 'kategori_pelanggaran', required: true }],
      },
    ],
    order: [['waktu_kejadian', 'DESC'], ['id', 'DESC']],
    limit: pageSize,
    offset: (page - 1) * pageSize,
  });

  const classMap = await getActiveStudentClassMap();

  const data = rows.map((r) => {
    const rawUraian = r.uraian ?? '';
    let place = null;
    let cleanUraian = rawUraian;
    const match = rawUraian.match(/^\[Lokasi:\s*([^\]]+)\]\s*(.*)$/s);
    if (match) {
      place = match[1].trim();
      cleanUraian = match[2];
    }
    return {
      id: r.id,
      siswa: r.siswa?.nama ?? '-',
      kelas: classMap.get(r.id_siswa)?.kelas ?? null,
      kategori: r.versi_aturan_penanganan?.kategori_pelanggaran?.nama ?? '-',
      waktu_kejadian: r.waktu_kejadian ? new Date(r.waktu_kejadian).toISOString() : null,
      tempat_kejadian: place,
      uraian: cleanUraian,
      status_verifikasi: r.status_verifikasi,
      hasil_verifikasi: r.hasil_verifikasi ?? null,
      jumlah_bukti: countEvidenceFiles(r.id),
    };
  });

  res.set('Cache-Control', 'no-store').json({
    data,
    meta: { total: count, page, page_size: pageSize },
  });
};
