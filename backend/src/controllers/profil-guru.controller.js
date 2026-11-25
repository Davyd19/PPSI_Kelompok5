// Profil akun Guru (aplikasi mobile): lihat data diri & tugas, ubah kontak, ganti kata sandi.
// Nama, NIP, dan identitas login dikelola Admin sehingga hanya dapat dibaca di sini.
const { QueryTypes } = require('sequelize');
const { sequelize, models } = require('../models');
const { revokeAccountSessions } = require('../models/auth-session');
const { createSession } = require('./auth-session.controller');
const { today } = require('./auth.controller');
const { hashPassword, verifyPassword } = require('../utils/security');
const audit = require('../utils/audit');
const fail = require('../utils/api-error');

const select = (sql, replacements) => sequelize.query(sql, { type: QueryTypes.SELECT, replacements });
const invalid = (message, details) => fail(422, 'VALIDATION_ERROR', message, details);
const EMAIL = /^[^\s@]{1,64}@[^\s@]+\.[^\s@]{2,}$/;
const PHONE = /^\+?[0-9]{8,15}$/;

async function view(guruId) {
  const g = await models.guru.unscoped().findByPk(guruId);
  const day = today();
  const active = 'x.tanggal_mulai<=:day AND (x.tanggal_selesai IS NULL OR x.tanggal_selesai>=:day)';
  const [wali, pembina, peran] = await Promise.all([
    select(`SELECT c.nama FROM penugasan_wali_kelas x JOIN kelas c ON c.id=x.id_kelas
      WHERE x.id_guru=:id AND ${active} ORDER BY c.nama`, { id: guruId, day }),
    select(`SELECT DISTINCT e.nama FROM penugasan_pembina x
      JOIN periode_ekstrakurikuler pe ON pe.id=x.id_periode_ekstrakurikuler
      JOIN ekstrakurikuler e ON e.id=pe.id_ekstrakurikuler
      WHERE x.id_guru=:id AND ${active} ORDER BY e.nama`, { id: guruId, day }),
    select(`SELECT p.nama FROM guru_peran x JOIN peran p ON p.id=x.id_peran
      WHERE x.id_guru=:id AND ${active} ORDER BY p.nama`, { id: guruId, day })
  ]);
  return {
    nama: g.nama,
    nip: g.identitas_pegawai,
    identitas_login: g.identitas_login,
    email: g.email,
    telepon: g.telepon,
    status_akun: g.status_akun,
    peran: peran.map(r => r.nama),
    wali_kelas: wali.map(r => r.nama),
    pembina_ekstrakurikuler: pembina.map(r => r.nama)
  };
}

// GET /guru/profil
exports.show = async (req, res) => {
  res.set('Cache-Control', 'no-store').json({ data: await view(req.user.id) });
};

// POST /guru/profil — Body: { email?, telepon? } (string kosong = hapus).
exports.update = async (req, res) => {
  const clean = (v, name) => {
    if (v === undefined) return undefined;
    if (v === null || (typeof v === 'string' && !v.trim())) return null;
    if (typeof v !== 'string') throw invalid(`${name} tidak valid.`);
    return v.trim();
  };
  const email = clean(req.body?.email, 'Email')?.toLowerCase();
  const telepon = clean(req.body?.telepon, 'Telepon')?.replace(/[\s-]/g, '');
  const errors = {};
  if (email && (email.length > 191 || !EMAIL.test(email))) errors.email = 'Format email tidak valid.';
  if (telepon && !PHONE.test(telepon)) errors.telepon = 'Nomor telepon 8–15 digit, boleh diawali +.';
  if (Object.keys(errors).length) throw invalid('Data profil belum valid.', errors);
  await sequelize.transaction(async t => {
    const g = await models.guru.unscoped().findByPk(req.user.id, { transaction: t, lock: t.LOCK.UPDATE });
    const before = { email: g.email, telepon: g.telepon };
    const changes = {
      ...(email !== undefined ? { email } : {}),
      ...(telepon !== undefined ? { telepon } : {})
    };
    await g.update(changes, { transaction: t });
    await audit({ user: req.user, body: {} }, 'guru', g.id, before, { email: g.email, telepon: g.telepon }, 'UBAH_PROFIL', t);
  });
  res.json({ data: await view(req.user.id) });
};

// POST /guru/profil/kata-sandi — Body: { kata_sandi_lama, kata_sandi_baru }.
// Semua sesi lain dicabut; perangkat ini menerima sesi baru agar tetap masuk.
exports.changePassword = async (req, res) => {
  const oldPw = req.body?.kata_sandi_lama;
  const newPw = req.body?.kata_sandi_baru;
  if (typeof oldPw !== 'string' || !oldPw) throw invalid('Kata sandi lama wajib diisi.', { kata_sandi_lama: 'Wajib diisi.' });
  if (typeof newPw !== 'string' || newPw.length < 10 || newPw.length > 128) {
    throw invalid('Kata sandi baru 10–128 karakter.', { kata_sandi_baru: 'Minimal 10 karakter.' });
  }
  if (newPw === oldPw) throw invalid('Kata sandi baru harus berbeda.', { kata_sandi_baru: 'Harus berbeda dari kata sandi lama.' });
  const current = await models.guru.unscoped().findByPk(req.user.id);
  if (!(await verifyPassword(oldPw, current.hash_kata_sandi))) {
    throw invalid('Kata sandi lama tidak sesuai.', { kata_sandi_lama: 'Kata sandi lama tidak sesuai.' });
  }
  const hash = await hashPassword(newPw);
  const user = await sequelize.transaction(async t => {
    const g = await models.guru.unscoped().findByPk(req.user.id, { transaction: t, lock: t.LOCK.UPDATE });
    if (g.hash_kata_sandi !== current.hash_kata_sandi) throw fail(409, 'STATE_CONFLICT', 'Kata sandi baru saja diubah. Coba lagi.');
    await g.update({ hash_kata_sandi: hash }, { transaction: t });
    await revokeAccountSessions('guru', g.id, t);
    await audit({ user: req.user, body: {} }, 'guru', g.id, null, null, 'GANTI_KATA_SANDI', t);
    return g;
  });
  const tokens = await createSession('guru', user, req.authPlatform);
  res.set('Cache-Control', 'no-store').json({ data: { ...tokens, expires_in: 900 } });
};
