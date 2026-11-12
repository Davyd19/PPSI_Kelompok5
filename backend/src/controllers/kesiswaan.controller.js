const { Op, QueryTypes } = require('sequelize');
const { sequelize, models } = require('../models');
const { today } = require('./auth.controller');
const audit = require('../utils/audit');
const fail = require('../utils/api-error');

const invalid = message => fail(422, 'VALIDATION_ERROR', message);
const conflict = message => fail(409, 'STATE_CONFLICT', message);
const missing = () => fail(404, 'NOT_FOUND', 'Data tidak ditemukan.');
const send = (res, data, status = 200) => res.status(status).json({ data });
const select = (sql, replacements = {}) => sequelize.query(sql, { type: QueryTypes.SELECT, replacements });
const proposalTypes = ['USULAN_ESKALASI', 'USULAN_RUJUKAN'];
const verification = ['MENUNGGU', 'TERVERIFIKASI', 'DITOLAK'];
const presence = ['HADIR', 'TERLAMBAT', 'IZIN', 'SAKIT', 'ALFA', 'PENGECUALIAN_SAH', 'PENGECUALIAN_SAH_ZUHUR', 'BELUM_DIISI'];

function string(value, label, max, optional = false) {
  if (optional && (value == null || value === '')) return null;
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) throw invalid(label + ' tidak valid.');
  return value.trim();
}
function id(value) {
  if (!/^\d+$/.test(String(value)) || !Number.isSafeInteger(Number(value)) || Number(value) < 1) throw invalid('ID tidak valid.');
  return Number(value);
}
function date(value, label) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) || value < '1000-01-01') throw invalid(label + ' tidak valid.');
  const d = new Date(value);
  if (!Number.isFinite(d.getTime()) || d.toISOString().slice(0, 10) !== value) throw invalid(label + ' tidak valid.');
  return value;
}
function shiftDay(value, days) {
  const d = new Date(value);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}
function options(req, statuses) {
  const end = req.query.sampai === undefined ? today() : date(req.query.sampai, 'Tanggal akhir');
  const start = req.query.mulai === undefined ? shiftDay(end, -29) : date(req.query.mulai, 'Tanggal awal');
  if (start > end || (Date.parse(end) - Date.parse(start)) / 86400000 > 366) throw invalid('Rentang tanggal tidak valid atau lebih dari 367 hari.');
  const status = req.query.status || null;
  if (status && !statuses.includes(status)) throw invalid('Status tidak valid.');
  const page = req.query.page === undefined ? 1 : id(req.query.page);
  if (page > 100000) throw invalid('Halaman tidak valid.');
  return { start, end, status, kelas: req.query.kelas ? id(req.query.kelas) : null, page, offset: (page - 1) * 25 };
}

function reportSql() {
  return `SELECT l.id, l.id_siswa, s.nama AS siswa, c.nama AS kelas, c.tingkat,
    k.nama AS kategori, a.nomor_versi, g.nama AS pelapor, p.nama AS pemeriksa,
    l.waktu_kejadian, l.waktu_verifikasi, l.uraian, l.status_verifikasi,
    l.hasil_verifikasi, l.status_tindak_lanjut
    FROM laporan_pelanggaran l JOIN siswa s ON s.id=l.id_siswa
    JOIN versi_aturan_penanganan a ON a.id=l.id_versi_aturan_penanganan
    JOIN kategori_pelanggaran k ON k.id=a.id_kategori_pelanggaran
    JOIN guru g ON g.id=l.id_guru_pelapor LEFT JOIN guru p ON p.id=l.id_guru_pemeriksa
    LEFT JOIN kelas c ON c.id=(SELECT r.id_kelas FROM riwayat_kelas_siswa r
      WHERE r.id_siswa=l.id_siswa AND r.tanggal_mulai<=DATE(l.waktu_kejadian + INTERVAL 7 HOUR)
      AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=DATE(l.waktu_kejadian + INTERVAL 7 HOUR))
      ORDER BY r.tanggal_mulai DESC,r.id DESC LIMIT 1)
    WHERE l.waktu_kejadian >= TIMESTAMP(:start) - INTERVAL 7 HOUR
    AND l.waktu_kejadian < TIMESTAMP(:end) + INTERVAL 17 HOUR
    AND (:kelas IS NULL OR c.id=:kelas) AND (:status IS NULL OR l.status_verifikasi=:status)`;
}
function attendanceSql() {
  return `SELECT ss.id AS id_sesi,s.id AS id_siswa,s.nama AS siswa,c.nama AS kelas,
    ss.tanggal,ss.jenis_sesi,COALESCE(p.status_kehadiran,'BELUM_DIISI') AS status_kehadiran
    FROM sesi_presensi_sekolah ss
    JOIN semester sm ON sm.id=ss.id_semester
    JOIN kelas c ON c.id_tahun_ajaran=sm.id_tahun_ajaran
    JOIN riwayat_kelas_siswa r ON r.id_kelas=c.id AND r.tanggal_mulai<=ss.tanggal
      AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=ss.tanggal)
    JOIN siswa s ON s.id=r.id_siswa
    LEFT JOIN presensi_sekolah p ON p.id_sesi_presensi_sekolah=ss.id AND p.id_siswa=s.id
    WHERE ss.tanggal BETWEEN :start AND :end AND ss.status='DITUTUP'
      AND (:kelas IS NULL OR c.id=:kelas)
      AND (:status IS NULL OR COALESCE(p.status_kehadiran,'BELUM_DIISI')=:status)`;
}

async function list(req, res, sql, statuses, order) {
  const filters = options(req, statuses);
  const [rows, [{ total }]] = await Promise.all([
    select(sql + ' ORDER BY ' + order + ' LIMIT 25 OFFSET :offset', filters),
    select('SELECT COUNT(*) AS total FROM (' + sql + ') r', filters)
  ]);
  res.json({ data: rows, meta: { total: Number(total), page: filters.page, page_size: 25 } });
}
function csvCell(value) {
  let text = value instanceof Date ? value.toISOString() : String(value ?? '');
  if (/^[\s]*[=+@-]|^[\t\r\n]/.test(text)) text = "'" + text;
  return '"' + text.replaceAll('"', '""') + '"';
}
async function exportRows(req, res, sql, statuses, order, fields, name) {
  const rows = await select(sql + ' ORDER BY ' + order, options(req, statuses));
  const csv = [fields.map(csvCell).join(','), ...rows.map(row => fields.map(field => csvCell(row[field])).join(','))];
  res.type('text/csv').attachment(name + '.csv').send('\uFEFF' + csv.join('\r\n'));
}

exports.reports = (req, res) => list(req, res, reportSql(), verification, 'waktu_kejadian DESC,id DESC');
exports.attendance = (req, res) => list(req, res, attendanceSql(), presence, 'tanggal DESC,id_sesi DESC,id_siswa');
exports.exportReports = (req, res) => exportRows(req, res, reportSql(), verification, 'waktu_kejadian DESC,id DESC',
  ['id','siswa','kelas','kategori','nomor_versi','pelapor','pemeriksa','waktu_kejadian','status_verifikasi','status_tindak_lanjut'], 'pelanggaran');
exports.exportAttendance = (req, res) => exportRows(req, res, attendanceSql(), presence, 'tanggal DESC,id_sesi DESC,id_siswa',
  ['tanggal','jenis_sesi','id_siswa','siswa','kelas','status_kehadiran'], 'presensi');

exports.dashboard = async (req, res) => {
  const filters = options(req, verification);
  const [reports, queue, attendance, cases] = await Promise.all([
    select('SELECT status_verifikasi, COUNT(*) AS total FROM (' + reportSql() + ') r GROUP BY status_verifikasi', filters),
    select(reportSql() + " AND l.status_verifikasi='MENUNGGU' ORDER BY waktu_kejadian DESC,id DESC LIMIT 5", filters),
    select('SELECT status_kehadiran, COUNT(*) AS total FROM (' + attendanceSql() + ') a GROUP BY status_kehadiran', { ...filters, status: null }),
    select(`SELECT COUNT(*) AS total FROM penanganan_siswa ps
      WHERE ps.status IN ('TERBUKA','DALAM_PENANGANAN')
        AND ps.tanggal_dibuka <= :end AND (:kelas IS NULL OR EXISTS (
          SELECT 1 FROM riwayat_kelas_siswa r WHERE r.id_siswa=ps.id_siswa AND r.id_kelas=:kelas
            AND r.tanggal_mulai<=:end AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=:end)
        ))`, filters)
  ]);
  const trend = await select(`SELECT DATE_FORMAT(waktu_kejadian + INTERVAL 7 HOUR,'%x-W%v') AS pekan,
    COALESCE(tingkat,'Tanpa kelas') AS tingkat, COUNT(*) AS total
    FROM (${reportSql()}) r GROUP BY pekan, tingkat ORDER BY pekan, tingkat`, filters);
  send(res, { reports, queue, attendance, active_cases: Number(cases[0].total), trend });
};

exports.lookups = async (req, res) => {
  const q = string(req.query.q, 'Pencarian', 100, true);
  const where = q ? { [Op.or]: [{ nama: { [Op.substring]: q } }, { nisn: { [Op.substring]: q } }] } : {};
  const [students, classes, categories] = await Promise.all([
    models.siswa.findAll({ where, attributes: ['id','nama','nisn'], order: [['nama','ASC']], limit: 50 }),
    models.kelas.findAll({ attributes: ['id','nama','id_tahun_ajaran'], order: [['id_tahun_ajaran','DESC'],['nama','ASC']] }),
    models.kategori.findAll({ order: [['nama','ASC']] })
  ]);
  send(res, { students, classes, categories });
};

exports.categories = async (req, res) => send(res, await models.kategori.findAll({
  include: [{ model: models.aturan, as: 'aturan_id_kategori_pelanggaran' }],
  order: [['nama','ASC']]
}));
function category(body) {
  const status = body?.status || 'AKTIF';
  if (!['AKTIF','NONAKTIF'].includes(status)) throw invalid('Status kategori tidak valid.');
  return { nama: string(body?.nama, 'Nama kategori', 191), deskripsi: string(body?.deskripsi, 'Deskripsi', 10000, true), status };
}
exports.saveCategory = async (req, res) => {
  const patch = category(req.body);
  const saved = await sequelize.transaction(async t => {
    const row = req.params.id ? await models.kategori.findByPk(id(req.params.id), { transaction:t, lock:t.LOCK.UPDATE }) : null;
    if (req.params.id && !row) throw missing();
    const before = row?.toJSON();
    const result = row ? await row.update(patch,{transaction:t}) : await models.kategori.create(patch,{transaction:t});
    await audit(req, 'kategori', result.id, before, result.toJSON(), row ? 'UBAH' : 'TAMBAH', t);
    return result;
  });
  send(res, saved, req.params.id ? 200 : 201);
};
exports.addVersion = async (req, res) => {
  const categoryId = id(req.params.id);
  const start = date(req.body?.berlaku_mulai, 'Tanggal mulai');
  const end = req.body?.berlaku_sampai ? date(req.body.berlaku_sampai, 'Tanggal akhir') : null;
  if (end && end < start) throw invalid('Tanggal akhir mendahului tanggal mulai.');
  const rule = string(req.body?.ketentuan, 'Ketentuan', 20000);
  const created = await sequelize.transaction(async t => {
    const parent = await models.kategori.findByPk(categoryId, { transaction:t, lock:t.LOCK.UPDATE });
    if (!parent) throw missing();
    const existing = await models.aturan.findAll({ where:{id_kategori_pelanggaran:categoryId},transaction:t,lock:t.LOCK.UPDATE });
    const overlaps = existing.filter(v => (!end || v.berlaku_mulai <= end) && (!v.berlaku_sampai || v.berlaku_sampai >= start));
    if (overlaps.length) {
      const old = overlaps[0];
      if (overlaps.length !== 1 || old.berlaku_sampai || old.berlaku_mulai >= start) throw conflict('Masa berlaku aturan bertumpuk.');
      const alreadyUsed = await models.laporan.count({ where:{
        id_versi_aturan_penanganan:old.id, waktu_kejadian:{[Op.gte]:new Date(start + 'T00:00:00+07:00')}
      }, transaction:t });
      if (alreadyUsed) throw conflict('Tanggal baru bertabrakan dengan laporan yang memakai versi lama.');
      const before = old.toJSON();
      await old.update({ berlaku_sampai:shiftDay(start,-1) }, {transaction:t});
      await audit(req,'aturan',old.id,before,old.toJSON(),'AKHIRI_ATURAN',t);
    }
    const row = await models.aturan.create({
      id_kategori_pelanggaran:categoryId, nomor_versi:Math.max(0,...existing.map(v=>v.nomor_versi))+1,
      ketentuan:rule, berlaku_mulai:start, berlaku_sampai:end
    },{transaction:t});
    await audit(req,'aturan',row.id,null,row.toJSON(),'TAMBAH_VERSI',t);
    return row;
  });
  send(res,created,201);
};

exports.createReport = async (req, res) => {
  const studentId = id(req.body?.id_siswa);
  const categoryId = id(req.body?.id_kategori_pelanggaran);
  const time = req.body?.waktu_kejadian;
  if (typeof time !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,3})?)?\+07:00$/.test(time)) throw invalid('Waktu kejadian harus dalam WIB.');
  const day = date(time.slice(0,10),'Tanggal kejadian');
  const occurred = new Date(time);
  if (!Number.isFinite(occurred.getTime()) || occurred > new Date()) throw invalid('Waktu kejadian tidak valid.');
  const description = string(req.body?.uraian,'Uraian',20000);
  const saved = await sequelize.transaction(async t => {
    const parent = await models.kategori.findByPk(categoryId,{transaction:t,lock:t.LOCK.UPDATE});
    if (!parent || parent.status !== 'AKTIF') throw invalid('Kategori aktif tidak ditemukan.');
    if (!await models.siswa.findByPk(studentId,{transaction:t})) throw missing();
    const versions = await models.aturan.findAll({ where:{
      id_kategori_pelanggaran:categoryId, berlaku_mulai:{[Op.lte]:day},
      [Op.or]:[{berlaku_sampai:null},{berlaku_sampai:{[Op.gte]:day}}]
    }, transaction:t });
    if (versions.length !== 1) throw conflict('Tanggal kejadian harus mempunyai tepat satu versi aturan yang berlaku.');
    const row = await models.laporan.create({
      id_siswa:studentId,id_versi_aturan_penanganan:versions[0].id,id_guru_pelapor:req.user.id,
      waktu_kejadian:occurred,uraian:description,status_verifikasi:'MENUNGGU',status_tindak_lanjut:'BELUM_DITINDAKLANJUTI'
    },{transaction:t});
    await audit(req,'laporan',row.id,null,row.toJSON(),'CATAT_PELANGGARAN',t);
    return row;
  });
  send(res,saved,201);
};
exports.verify = async (req, res) => {
  const status = req.body?.status_verifikasi;
  if (!['TERVERIFIKASI','DITOLAK'].includes(status)) throw invalid('Keputusan verifikasi tidak valid.');
  const note = string(req.body?.catatan,'Catatan verifikasi',20000);
  const saved = await sequelize.transaction(async t => {
    const row = await models.laporan.findByPk(id(req.params.id),{transaction:t,lock:t.LOCK.UPDATE});
    if (!row) throw missing();
    if (row.status_verifikasi !== 'MENUNGGU') throw conflict('Laporan sudah diperiksa.');
    const before = row.toJSON();
    await row.update({status_verifikasi:status,id_guru_pemeriksa:req.user.id,waktu_verifikasi:new Date(),hasil_verifikasi:note},{transaction:t});
    await audit(req,'laporan',row.id,before,row.toJSON(),'VERIFIKASI_PELANGGARAN',t);
    return row;
  });
  send(res,saved);
};

exports.proposals = async (req, res) => {
  const page = req.query.page ? id(req.query.page) : 1;
  if (page > 100000) throw invalid('Halaman tidak valid.');
  const rows = await models.riwayat.findAndCountAll({
    where: { jenis: proposalTypes },
    attributes: ['id','jenis','waktu','status_usulan','ringkasan_diizinkan'],
    include: [{model:models.penanganan,as:'penanganan_siswa',attributes:['id','id_siswa','ringkasan_diizinkan','status']},
      {model:models.laporan,as:'laporan_pelanggaran',attributes:['id','id_siswa','status_verifikasi']}],
    order:[['waktu','DESC'],['id','DESC']], limit:25, offset:(page-1)*25
  });
  res.json({data:rows.rows,meta:{total:rows.count,page,page_size:25}});
};
exports.decide = async (req, res) => {
  const decisions = { SETUJUI:'DISETUJUI', TOLAK:'DITOLAK', MINTA_REVISI:'PERLU_REVISI' };
  const action = req.body?.keputusan;
  if (!Object.hasOwn(decisions,action)) throw invalid('Keputusan tidak valid.');
  const reason = string(req.body?.alasan,'Alasan keputusan',20000);
  const instruction = string(req.body?.arahan,'Arahan tindak lanjut',20000);
  const result = await sequelize.transaction(async t => {
    const proposal = await models.riwayat.findByPk(id(req.params.id),{transaction:t,lock:t.LOCK.UPDATE});
    if (!proposal || !proposalTypes.includes(proposal.jenis)) throw missing();
    if (proposal.status_usulan !== 'MENUNGGU') throw conflict('Usulan sudah ditinjau.');
    const before = proposal.toJSON();
    await proposal.update({status_usulan:decisions[action]},{transaction:t});
    const response = await models.riwayat.create({
      id_penanganan_siswa:proposal.id_penanganan_siswa,id_laporan_pelanggaran:proposal.id_laporan_pelanggaran,
      id_riwayat_acuan:proposal.id,id_guru_pencatat:req.user.id,jenis:action==='MINTA_REVISI'?'RESPONS':'KEPUTUSAN',
      waktu:new Date(),orang_tua_dilibatkan:false,hasil_keputusan:action,alasan_keputusan:reason,arahan_tindak_lanjut:instruction
    },{transaction:t});
    await audit(req,'riwayat',proposal.id,{status_usulan:before.status_usulan},{status_usulan:proposal.status_usulan},'TINJAU_USULAN',t);
    return { id:proposal.id,status_usulan:proposal.status_usulan,id_keputusan:response.id };
  });
  send(res,result);
};
module.exports.validation = { id, date, string, invalid, missing };
