// Use case Guru: "Menginput Laporan Pelanggaran".
// Alur: buka menu -> pilih siswa -> isi waktu, tempat, jenis, deskripsi, bukti (opsional)
// -> kirim -> sistem memvalidasi kelengkapan (tidak lengkap: kembali ke formulir dengan
// pesan per kolom) -> laporan tersimpan berstatus MENUNGGU untuk diverifikasi Kesiswaan.
const path = require('node:path');
const fs = require('node:fs/promises');
const { randomUUID } = require('node:crypto');
const { Op, QueryTypes } = require('sequelize');
const { sequelize, models } = require('../models');
const { today } = require('./auth.controller');
const audit = require('../utils/audit');
const fail = require('../utils/api-error');
const { id, string, invalid, missing } = require('./kesiswaan.controller').validation;

const MAX_ATTACHMENTS = 3;
const directory = path.resolve(process.env.PELANGGARAN_UPLOAD_DIR || path.join(__dirname, '../../storage/pelanggaran'));
const accepted = {
  'application/pdf': d => d.subarray(0, 5).toString() === '%PDF-' && d.subarray(-1024).toString().includes('%%EOF'),
  'image/jpeg': d => d[0] === 255 && d[1] === 216 && d[2] === 255,
  'image/png': d => d.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
};
const select = (sql, replacements = {}, transaction) =>
  sequelize.query(sql, { type: QueryTypes.SELECT, replacements, transaction });
const incomplete = details => fail(422, 'VALIDATION_ERROR', 'Data laporan belum lengkap. Periksa kembali isian.', details);

// Kategori aktif yang punya tepat satu versi aturan berlaku pada tanggal tertentu.
const categorySql = `SELECT k.id, k.nama, k.deskripsi FROM kategori_pelanggaran k
  WHERE k.status='AKTIF' AND (SELECT COUNT(*) FROM versi_aturan_penanganan a
    WHERE a.id_kategori_pelanggaran=k.id AND a.berlaku_mulai<=:day
      AND (a.berlaku_sampai IS NULL OR a.berlaku_sampai>=:day))=1
  ORDER BY k.nama`;

// GET /guru/pelanggaran/formulir — pilihan jenis pelanggaran & kelas.
exports.form = async (req, res) => {
  const day = today();
  const [categories, classes] = await Promise.all([
    select(categorySql, { day }),
    select(`SELECT c.id, c.nama FROM kelas c JOIN tahun_ajaran t ON t.id=c.id_tahun_ajaran
      WHERE t.aktif=1 AND c.status='AKTIF' ORDER BY c.tingkat, c.nama`)
  ]);
  res.json({ data: { kategori: categories, kelas: classes, maks_bukti: MAX_ATTACHMENTS } });
};

// GET /guru/pelanggaran/siswa?q=&kelas= — siswa aktif beserta kelas saat ini.
exports.students = async (req, res) => {
  const q = string(req.query.q, 'Pencarian', 100, true);
  const kelas = req.query.kelas ? id(req.query.kelas) : null;
  const rows = await select(`SELECT s.id, s.nama, s.nis, s.nisn, c.id AS id_kelas, c.nama AS kelas
    FROM siswa s
    JOIN riwayat_kelas_siswa r ON r.id_siswa=s.id AND r.tanggal_mulai<=:day
      AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=:day)
    JOIN kelas c ON c.id=r.id_kelas
    WHERE s.status_siswa='AKTIF'
      AND (:q IS NULL OR s.nama LIKE :q OR s.nis LIKE :q OR s.nisn LIKE :q)
      AND (:kelas IS NULL OR c.id=:kelas)
    ORDER BY c.nama, s.nama LIMIT 50`, { day: today(), q: q ? `%${q}%` : null, kelas });
  res.json({ data: rows });
};

// POST /guru/pelanggaran — kirim laporan.
exports.create = async (req, res) => {
  const b = req.body || {};
  const errors = {};
  const pickId = (value, key, message) => {
    if (/^\d{1,10}$/.test(String(value ?? '')) && Number(value) > 0) return Number(value);
    errors[key] = message;
    return null;
  };
  const text = (value, key, min, max, message) => {
    const v = typeof value === 'string' ? value.trim() : '';
    if (v.length < min || v.length > max) errors[key] = message;
    return v;
  };
  const studentId = pickId(b.id_siswa, 'id_siswa', 'Pilih siswa yang dilaporkan.');
  const categoryId = pickId(b.id_kategori_pelanggaran, 'id_kategori_pelanggaran', 'Pilih jenis pelanggaran.');
  const place = text(b.tempat_kejadian, 'tempat_kejadian', 3, 191, 'Isi tempat kejadian (3–191 karakter).');
  const description = text(b.uraian, 'uraian', 10, 5000, 'Isi deskripsi kejadian minimal 10 karakter.');
  let occurred = null;
  const time = b.waktu_kejadian;
  if (typeof time !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?\+07:00$/.test(time)) {
    errors.waktu_kejadian = 'Isi tanggal dan jam kejadian.';
  } else {
    occurred = new Date(time);
    const ageDays = (Date.now() - occurred.getTime()) / 86400000;
    if (!Number.isFinite(occurred.getTime()) || occurred > new Date(Date.now() + 60000)) {
      errors.waktu_kejadian = 'Waktu kejadian tidak boleh di masa depan.';
    } else if (ageDays > 30) {
      errors.waktu_kejadian = 'Laporan hanya untuk kejadian maksimal 30 hari terakhir.';
    }
  }
  if (Object.keys(errors).length) throw incomplete(errors);
  const day = time.slice(0, 10);

  const saved = await sequelize.transaction(async t => {
    const student = await models.siswa.findByPk(studentId, { transaction: t });
    if (!student || student.status_siswa !== 'AKTIF') throw incomplete({ id_siswa: 'Siswa tidak ditemukan atau tidak aktif.' });
    const category = await models.kategori.findByPk(categoryId, { transaction: t, lock: t.LOCK.SHARE });
    if (!category || category.status !== 'AKTIF') throw incomplete({ id_kategori_pelanggaran: 'Jenis pelanggaran tidak aktif.' });
    const versions = await models.aturan.findAll({ where: {
      id_kategori_pelanggaran: categoryId, berlaku_mulai: { [Op.lte]: day },
      [Op.or]: [{ berlaku_sampai: null }, { berlaku_sampai: { [Op.gte]: day } }]
    }, transaction: t });
    if (versions.length !== 1) {
      throw incomplete({ id_kategori_pelanggaran: 'Belum ada aturan yang berlaku untuk tanggal kejadian ini. Hubungi Kesiswaan.' });
    }
    const row = await models.laporan.create({
      id_siswa: studentId, id_versi_aturan_penanganan: versions[0].id, id_guru_pelapor: req.user.id,
      waktu_kejadian: occurred, tempat_kejadian: place, uraian: description,
      status_verifikasi: 'MENUNGGU', status_tindak_lanjut: 'BELUM_DITINDAKLANJUTI'
    }, { transaction: t });
    await audit(req, 'laporan', row.id, null, row.toJSON(), 'CATAT_PELANGGARAN', t);
    return row;
  });
  res.status(201).json({ data: { id: saved.id, status_verifikasi: saved.status_verifikasi } });
};

// POST /guru/pelanggaran/:id/bukti — unggah bukti (JPEG/PNG/PDF, maks. 5 MB).
exports.upload = async (req, res) => {
  const type = req.get('Content-Type')?.split(';')[0];
  if (!Object.hasOwn(accepted, type) || !Buffer.isBuffer(req.body) || !req.body.length || !accepted[type](req.body)) {
    throw invalid('Bukti harus berupa foto (JPEG/PNG) atau PDF yang valid.');
  }
  let name;
  try { name = path.basename(decodeURIComponent(req.get('X-Filename') || 'bukti')); } catch { throw invalid('Nama berkas tidak valid.'); }
  name = string(name, 'Nama berkas', 191);
  if (/[\x00-\x1f\x7f]/.test(name)) throw invalid('Nama berkas tidak valid.');
  const key = randomUUID();
  const file = path.join(directory, key);
  await fs.mkdir(directory, { recursive: true });
  await fs.writeFile(file, req.body, { flag: 'wx', mode: 0o600 });
  try {
    const row = await sequelize.transaction(async t => {
      const report = await models.laporan.findByPk(id(req.params.id), { transaction: t, lock: t.LOCK.UPDATE });
      if (!report || report.id_guru_pelapor !== req.user.id) throw missing();
      if (report.status_verifikasi !== 'MENUNGGU') throw fail(409, 'STATE_CONFLICT', 'Laporan sudah diperiksa; bukti tidak dapat ditambah.');
      const count = await models.lampiran_laporan.count({ where: { id_laporan_pelanggaran: report.id }, transaction: t });
      if (count >= MAX_ATTACHMENTS) throw fail(409, 'STATE_CONFLICT', `Maksimal ${MAX_ATTACHMENTS} bukti per laporan.`);
      const item = await models.lampiran_laporan.create({
        id_laporan_pelanggaran: report.id, nama_berkas: name, lokasi_berkas: key, jenis_berkas: type, waktu_unggah: new Date()
      }, { transaction: t });
      await audit(req, 'lampiran_laporan', item.id, null, { id_laporan_pelanggaran: report.id, nama_berkas: name }, 'UNGGAH_BUKTI_PELANGGARAN', t);
      return item;
    });
    res.status(201).json({ data: { id: row.id, nama_berkas: name, jenis_berkas: type } });
  } catch (error) {
    await fs.unlink(file).catch(() => {});
    throw error;
  }
};

// GET /guru/pelanggaran?page=&q= — laporan yang dikirim guru ini beserta status verifikasinya.
// q (opsional) mencari nama siswa, NIS, kategori, kelas, atau tempat kejadian.
exports.mine = async (req, res) => {
  const page = req.query.page ? id(req.query.page) : 1;
  if (page > 100000) throw invalid('Halaman tidak valid.');
  const q = string(req.query.q, 'Pencarian', 100, true);
  const base = `FROM laporan_pelanggaran l
    JOIN siswa s ON s.id=l.id_siswa
    JOIN versi_aturan_penanganan a ON a.id=l.id_versi_aturan_penanganan
    JOIN kategori_pelanggaran k ON k.id=a.id_kategori_pelanggaran
    LEFT JOIN kelas c ON c.id=(SELECT r.id_kelas FROM riwayat_kelas_siswa r
      WHERE r.id_siswa=l.id_siswa AND r.tanggal_mulai<=DATE(l.waktu_kejadian + INTERVAL 7 HOUR)
        AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=DATE(l.waktu_kejadian + INTERVAL 7 HOUR))
      ORDER BY r.tanggal_mulai DESC, r.id DESC LIMIT 1)
    WHERE l.id_guru_pelapor=:me
    ${q ? `AND (s.nama LIKE :q OR s.nis LIKE :q OR k.nama LIKE :q OR c.nama LIKE :q
      OR l.tempat_kejadian LIKE :q)` : ''}`;
  const params = { me: req.user.id, offset: (page - 1) * 20, q: q ? `%${q}%` : null };
  const [rows, [{ total }]] = await Promise.all([
    select(`SELECT l.id, s.nama AS siswa, s.nis, c.nama AS kelas, k.nama AS kategori,
        l.waktu_kejadian, l.tempat_kejadian, l.uraian, l.status_verifikasi, l.hasil_verifikasi,
        l.status_tindak_lanjut,
        (SELECT COUNT(*) FROM lampiran_laporan_pelanggaran b WHERE b.id_laporan_pelanggaran=l.id) AS jumlah_bukti
      ${base} ORDER BY l.waktu_kejadian DESC, l.id DESC LIMIT 20 OFFSET :offset`, params),
    select(`SELECT COUNT(*) AS total ${base}`, params)
  ]);
  res.json({
    data: rows.map(r => ({ ...r, jumlah_bukti: Number(r.jumlah_bukti) })),
    meta: { total: Number(total), page, page_size: 20 }
  });
};
