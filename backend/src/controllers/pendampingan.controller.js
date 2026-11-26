const { Op } = require('sequelize');
const { sequelize, models } = require('../models');
const { today } = require('./auth.controller');
const audit = require('../utils/audit');
const fail = require('../utils/api-error');

const invalid = message => fail(422, 'VALIDATION_ERROR', message);
const conflict = message => fail(409, 'STATE_CONFLICT', message);
const missing = () => fail(404, 'NOT_FOUND', 'Laporan atau penanganan tidak ditemukan dalam kewenangan Anda.');
const active = () => ({ tanggal_mulai: { [Op.lte]: today() }, [Op.or]: [{ tanggal_selesai: null }, { tanggal_selesai: { [Op.gte]: today() } }] });
const statuses = ['MENUNGGU_VERIFIKASI', 'DALAM_PEMBINAAN', 'RENCANA_KONSELING_AKTIF', 'DIRUJUK_ESKALASI', 'SELESAI_DITUTUP'];
function id(value) {
  if (!/^[1-9]\d*$/.test(String(value)) || !Number.isSafeInteger(Number(value))) throw invalid('ID tidak valid.');
  return Number(value);
}
function text(value, name, max = 10000, optional = false) {
  if (optional && (value == null || value === '')) return null;
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) throw invalid(`${name} wajib diisi dan maksimal ${max} karakter.`);
  return value.trim();
}
function instant(value, name) {
  if (typeof value !== 'string' || !/^\d{4}-\d\d-\d\dT/.test(value) || !Number.isFinite(Date.parse(value))) throw invalid(`${name} tidak valid.`);
  const day = value.slice(0, 10);
  if (new Date(day).toISOString().slice(0, 10) !== day || !/(Z|[+-]\d\d:\d\d)$/.test(value)) throw invalid(`${name} harus berisi tanggal dan zona waktu yang valid.`);
  return new Date(value);
}
function source(req) {
  const value = req.query.sumber || 'LAPORAN';
  if (!['LAPORAN', 'PENANGANAN'].includes(value)) throw invalid('Sumber kasus tidak valid.');
  return value;
}
exports.guard = role => (req, res, next) => {
  if (req.authPlatform !== 'mobile' || req.user.kind !== 'guru' || !req.user.available_roles?.includes(role)) throw fail(403, 'FORBIDDEN', 'Penugasan atau peran yang diperlukan tidak aktif.');
  req.caseRole = role;
  res.set('Cache-Control', 'no-store');
  next();
};
async function classScope(req, transaction) {
  const assignments = await models.wali.findAll({ where: { id_guru: req.user.id, ...active() }, transaction });
  return assignments.map(row => row.id_kelas);
}
async function mayReadStudent(req, studentId, transaction) {
  if (req.caseRole === 'GURU_BK') return;
  const classes = await classScope(req, transaction);
  const membership = await models.riwayat_kelas.findOne({ where: { id_siswa: studentId, id_kelas: { [Op.in]: classes }, ...active() }, transaction });
  if (!membership) throw missing();
}
async function context(req, transaction, lock = false) {
  const opts = { transaction, ...(lock ? { lock: transaction.LOCK.UPDATE } : {}) };
  let report = null, handling = null;
  if (source(req) === 'LAPORAN') {
    report = await models.laporan.findByPk(id(req.params.id), opts);
    if (!report) throw missing();
    if (report.id_penanganan_siswa) handling = await models.penanganan.findByPk(report.id_penanganan_siswa, opts);
  } else handling = await models.penanganan.findByPk(id(req.params.id), opts);
  if (!report && !handling) throw missing();
  if (report && handling && report.id_siswa !== handling.id_siswa) throw conflict('Siswa pada laporan dan penanganan tidak cocok.');
  if (req.caseRole === 'GURU_BK' && handling && handling.id_guru_bk_penanggung_jawab !== req.user.id) throw missing();
  await mayReadStudent(req, (handling || report).id_siswa, transaction);
  return { report, handling };
}
const closed = ctx => ctx.handling ? ['SELESAI', 'DITUTUP', 'NONAKTIF'].includes(ctx.handling.status) : ctx.report.status_verifikasi === 'DITOLAK' || ctx.report.status_tindak_lanjut === 'SELESAI';
function writable(ctx) {
  if (closed(ctx)) throw conflict('Penanganan atau laporan sudah selesai.');
  if (ctx.report && ctx.report.status_verifikasi !== 'TERVERIFIKASI') throw conflict('Laporan harus diverifikasi sebelum ditindaklanjuti.');
}
async function ensureHandling(req, ctx, t) {
  if (ctx.handling) return ctx.handling;
  const row = await models.penanganan.create({ id_siswa: ctx.report.id_siswa, id_guru_bk_penanggung_jawab: req.user.id, tanggal_dibuka: today(), sumber_pengajuan: 'LAPORAN_PELANGGARAN', alasan_pembukaan: 'Pendampingan lanjutan laporan pelanggaran.', status: 'TERBUKA' }, { transaction: t });
  const before = ctx.report.toJSON();
  await ctx.report.update({ id_penanganan_siswa: row.id }, { transaction: t });
  await audit(req, 'laporan', ctx.report.id, before, ctx.report.toJSON(), 'HUBUNGKAN_PENANGANAN', t);
  await audit(req, 'penanganan', row.id, null, row.toJSON(), 'BUKA_PENANGANAN', t);
  ctx.handling = row;
  return row;
}
async function history(req, ctx, values, t) {
  for (const field of ['isi_internal', 'ringkasan_diizinkan']) {
    if (values[field] && Buffer.byteLength(values[field], 'utf8') > 60000) throw invalid('Catatan terlalu panjang. Ringkas isian sebelum menyimpan.');
  }
  const row = await models.riwayat.create({ id_penanganan_siswa: ctx.handling?.id || null, id_laporan_pelanggaran: ctx.handling ? null : ctx.report.id, id_guru_pencatat: req.user.id, waktu: new Date(), orang_tua_dilibatkan: false, ...values }, { transaction: t });
  await audit(req, 'riwayat', row.id, null, row.toJSON(), 'CATAT_PENANGANAN', t);
  return row;
}
async function histories(ctx, transaction) {
  const terms = [];
  if (ctx.handling) {
    terms.push({ id_penanganan_siswa: ctx.handling.id });
    const reports = await models.laporan.findAll({ where: { id_penanganan_siswa: ctx.handling.id }, attributes: ['id'], transaction });
    if (reports.length) terms.push({ id_laporan_pelanggaran: { [Op.in]: reports.map(r => r.id) } });
  } else terms.push({ id_laporan_pelanggaran: ctx.report.id });
  return models.riwayat.findAll({ where: { [Op.or]: terms }, order: [['waktu', 'ASC'], ['id', 'ASC']], transaction });
}
async function dto(req, ctx, detail = false) {
  const student = await models.siswa.findByPk((ctx.handling || ctx.report).id_siswa);
  const membership = await models.riwayat_kelas.findOne({ where: { id_siswa: student.id, ...active() }, include: [{ model: models.kelas, as: 'kelas' }], order: [['tanggal_mulai', 'DESC']] });
  const report = ctx.report || await models.laporan.findOne({ where: { id_penanganan_siswa: ctx.handling.id }, order: [['id', 'DESC']] });
  const rules = report ? await models.aturan.findByPk(report.id_versi_aturan_penanganan, { include: [{ model: models.kategori, as: 'kategori_pelanggaran' }] }) : null;
  const rows = await histories(ctx);
  const plan = ctx.handling ? await models.rencana.findOne({ where: { id_penanganan_siswa: ctx.handling.id, status: { [Op.notIn]: ['SELESAI', 'DIBATALKAN', 'NONAKTIF'] } } }) : null;
  let status = closed(ctx) ? 'SELESAI_DITUTUP' : report?.status_verifikasi === 'MENUNGGU' && !ctx.handling ? 'MENUNGGU_VERIFIKASI' : 'DALAM_PEMBINAAN';
  if (!closed(ctx) && status !== 'MENUNGGU_VERIFIKASI') {
    if (plan) status = 'RENCANA_KONSELING_AKTIF';
    if (rows.some(r => ['USULAN_ESKALASI', 'USULAN_RUJUKAN'].includes(r.jenis) && ['MENUNGGU', 'DISETUJUI'].includes(r.status_usulan))) status = 'DIRUJUK_ESKALASI';
  }
  const privateAccess = req.caseRole === 'GURU_BK';
  const data = { id: (source(req) === 'PENANGANAN' ? ctx.handling : ctx.report).id, sumber: source(req), nama_siswa: student.nama, kelas: membership?.kelas?.nama || '-', kategori: rules?.kategori_pelanggaran?.nama || 'Pendampingan Siswa', tanggal_laporan: report?.waktu_kejadian || ctx.handling.tanggal_dibuka, status, deskripsi: ctx.handling ? (privateAccess ? ctx.handling.alasan_pembukaan : ctx.handling.ringkasan_diizinkan || 'Pendampingan siswa sedang berlangsung.') : report.uraian, tempat_kejadian: report?.tempat_kejadian || null, pelapor: report ? (await models.guru.findByPk(report.id_guru_pelapor))?.nama : null, catatan_verifikasi: report?.hasil_verifikasi || null };
  if (detail) {
    data.riwayat = [];
    for (const row of rows) {
      const description = privateAccess ? row.isi_internal || row.ringkasan_diizinkan || row.alasan_keputusan : row.ringkasan_diizinkan || row.alasan_keputusan;
      if (!description) continue;
      data.riwayat.push({ id: row.id, tanggal: row.waktu, jenis: row.jenis, deskripsi: description, oleh: (await models.guru.findByPk(row.id_guru_pencatat))?.nama || '-', status_usulan: row.status_usulan });
    }
  }
  return data;
}
exports.list = async (req, res) => {
  if (req.query.status && !statuses.includes(req.query.status)) throw invalid('Status tidak valid.');
  let students;
  if (req.caseRole === 'WALI_KELAS') {
    const memberships = await models.riwayat_kelas.findAll({ where: { id_kelas: { [Op.in]: await classScope(req) }, ...active() }, attributes: ['id_siswa'] });
    students = memberships.map(r => r.id_siswa);
  }
  const reports = await models.laporan.findAll({ where: { id_penanganan_siswa: null, ...(students ? { id_siswa: { [Op.in]: students } } : {}) }, order: [['id', 'DESC']] });
  const handlings = await models.penanganan.findAll({ where: req.caseRole === 'GURU_BK' ? { id_guru_bk_penanggung_jawab: req.user.id } : { id_siswa: { [Op.in]: students } }, order: [['id', 'DESC']] });
  const data = [];
  for (const report of reports) data.push(await dto({ ...req, query: { sumber: 'LAPORAN' } }, { report, handling: null }));
  for (const handling of handlings) data.push(await dto({ ...req, query: { sumber: 'PENANGANAN' } }, { report: null, handling }));
  data.sort((a, b) => new Date(b.tanggal_laporan) - new Date(a.tanggal_laporan));
  res.json({ data: req.query.status ? data.filter(row => row.status === req.query.status) : data });
};
exports.detail = async (req, res) => res.json({ data: await dto(req, await context(req), true) });
exports.plan = async (req, res) => {
  const ctx = await context(req);
  const row = ctx.handling ? await models.rencana.findOne({ where: { id_penanganan_siswa: ctx.handling.id, status: { [Op.notIn]: ['SELESAI', 'DIBATALKAN', 'NONAKTIF'] } }, order: [['id', 'DESC']] }) : null;
  res.json({ data: row ? { ...row.toJSON(), id_kasus: Number(req.params.id) } : null });
};
exports.verify = async (req, res) => {
  if (!['TERIMA', 'TOLAK'].includes(req.body?.hasil)) throw invalid('Hasil verifikasi tidak valid.');
  const note = text(req.body.catatan, 'Catatan verifikasi', 191);
  await sequelize.transaction(async t => {
    const ctx = await context(req, t, true);
    if (!ctx.report || ctx.report.status_verifikasi !== 'MENUNGGU') throw conflict('Laporan sudah diperiksa.');
    const before = ctx.report.toJSON();
    await ctx.report.update({ status_verifikasi: req.body.hasil === 'TERIMA' ? 'TERVERIFIKASI' : 'DITOLAK', hasil_verifikasi: note, id_guru_pemeriksa: req.user.id, waktu_verifikasi: new Date(), status_tindak_lanjut: req.body.hasil === 'TERIMA' ? 'DALAM_PEMBINAAN' : 'SELESAI' }, { transaction: t });
    await history(req, ctx, { jenis: 'VERIFIKASI', ringkasan_diizinkan: note }, t);
    await audit(req, 'laporan', ctx.report.id, before, ctx.report.toJSON(), 'VERIFIKASI_LAPORAN', t);
  });
  res.json({ data: { tersimpan: true } });
};
exports.savePlan = async (req, res) => {
  const body = req.body || {};
  const values = { tujuan: text(body.tujuan, 'Tujuan'), bentuk_kegiatan: text(body.bentuk_kegiatan, 'Bentuk kegiatan', 191), jadwal: instant(body.jadwal, 'Jadwal'), rencana_tindak_lanjut: text(body.rencana_tindak_lanjut, 'Rencana tindak lanjut', 10000, true) };
  await sequelize.transaction(async t => {
    const ctx = await context(req, t, true); writable(ctx);
    await ensureHandling(req, ctx, t);
    let row = await models.rencana.findOne({ where: { id_penanganan_siswa: ctx.handling.id, status: { [Op.notIn]: ['SELESAI', 'DIBATALKAN', 'NONAKTIF'] } }, order: [['id', 'DESC']], transaction: t, lock: t.LOCK.UPDATE });
    const before = row?.toJSON() || null;
    if (row) await row.update(values, { transaction: t });
    else row = await models.rencana.create({ ...values, id_penanganan_siswa: ctx.handling.id, id_guru_penyusun: req.user.id, status: 'DIRENCANAKAN' }, { transaction: t });
    await audit(req, 'rencana', row.id, before, row.toJSON(), before ? 'UBAH_RENCANA' : 'TAMBAH_RENCANA', t);
    await history(req, ctx, { jenis: 'RENCANA_KONSELING', id_rencana_konseling: row.id, isi_internal: 'Rencana konseling disimpan.', ringkasan_diizinkan: 'Jadwal pendampingan telah disusun.' }, t);
  });
  res.json({ data: { tersimpan: true } });
};
exports.record = action => async (req, res) => {
  const b = req.body || {};
  let values;
  if (action === 'catatan-konseling') {
    const notes = ['kondisi_permasalahan', 'hasil_asesmen', 'ringkasan_konseling', 'rencana_tindak_lanjut'].map(key => `${key.replaceAll('_', ' ')}: ${text(b[key], key)}`).join('\n');
    values = { jenis: 'KONSELING', isi_internal: notes };
  } else if (action === 'catatan-pembinaan') {
    values = { jenis: 'PEMBINAAN', ringkasan_diizinkan: ['hasil_pembinaan', 'tindakan_diberikan', 'rencana_tindak_lanjut'].map(key => `${key.replaceAll('_', ' ')}: ${text(b[key], key)}`).join('\n') };
  } else if (action === 'tindak-lanjut-ortu') {
    const communication = instant(b.tanggal_komunikasi, 'Tanggal komunikasi');
    const notes = `Tanggal komunikasi: ${communication.toISOString()}\n${['hasil_komunikasi', 'bentuk_keterlibatan', 'rencana_tindak_lanjut'].map(key => `${key.replaceAll('_', ' ')}: ${text(b[key], key)}`).join('\n')}`;
    values = { jenis: 'TINDAK_LANJUT_ORANG_TUA', orang_tua_dilibatkan: true, ...(req.caseRole === 'GURU_BK' ? { isi_internal: notes, ringkasan_diizinkan: 'Koordinasi pendampingan dengan orang tua telah dicatat.' } : { ringkasan_diizinkan: notes }) };
  } else if (action === 'pemantauan') {
    if (b.keputusan !== 'TIDAK_PERLU') throw invalid('Keputusan pemantauan tidak valid.');
    values = { jenis: 'PEMANTAUAN', ringkasan_diizinkan: 'Pemantauan dicatat; belum diperlukan tindak lanjut tambahan. Status tetap terbuka.' };
  } else if (action === 'tindak-lanjut') {
    const note = text(b.catatan, 'Catatan');
    values = { jenis: 'TINDAK_LANJUT', ...(req.caseRole === 'GURU_BK' ? { isi_internal: note } : { ringkasan_diizinkan: note }) };
  } else if (action === 'eskalasi' || action === 'usulan') {
    const reason = text(b.alasan, 'Alasan', 8000);
    const kind = action === 'eskalasi' ? (b.jenis_usulan || 'ESKALASI') : b.jenis_usulan;
    if (!(action === 'eskalasi' ? ['ESKALASI', 'RUJUKAN'] : ['ESKALASI', 'PENUTUPAN']).includes(kind)) throw invalid('Jenis usulan tidak valid.');
    values = { jenis: `USULAN_${kind}`, status_usulan: 'MENUNGGU', ringkasan_diizinkan: reason };
    if (action === 'eskalasi') {
      const destination = text(b.pihak_tujuan, 'Pihak tujuan', 191);
      values.ringkasan_diizinkan = `Tujuan: ${destination}\nAlasan: ${reason}`;
      values.isi_internal = `Evaluasi: ${text(b.hasil_evaluasi, 'Hasil evaluasi')}\nPendukung: ${text(b.informasi_pendukung, 'Informasi pendukung', 10000, true) || '-'}`;
    } else values.ringkasan_diizinkan += `\nPendukung: ${text(b.catatan_pendukung, 'Catatan pendukung', 10000, true) || '-'}`;
  } else if (action === 'tutup') {
    values = { jenis: 'PENUTUPAN', isi_internal: `${text(b.catatan_pendukung, 'Catatan pendukung', 10000, true) || '-'}\n${text(b.catatan_akhir, 'Catatan akhir')}`, ringkasan_diizinkan: text(b.alasan_penutupan, 'Alasan penutupan') };
  } else throw invalid('Tindakan tidak dikenal.');
  await sequelize.transaction(async t => {
    const ctx = await context(req, t, true); writable(ctx);
    // All BK actions establish responsibility before saving any private notes.
    if (req.caseRole === 'GURU_BK') await ensureHandling(req, ctx, t);
    const rows = await histories(ctx, t);
    if (values.status_usulan && rows.some(row => row.jenis === values.jenis && row.status_usulan === 'MENUNGGU')) throw conflict('Masih ada usulan sejenis yang menunggu keputusan.');
    if (action === 'tutup' && rows.some(row => ['USULAN_ESKALASI', 'USULAN_RUJUKAN'].includes(row.jenis) && ['MENUNGGU', 'DISETUJUI'].includes(row.status_usulan))) throw conflict('Penutupan menunggu penyelesaian eskalasi oleh pihak yang berwenang.');
    const row = await history(req, ctx, values, t);
    if (action === 'tutup') {
      if (ctx.handling) {
        const before = ctx.handling.toJSON();
        await ctx.handling.update({ status: 'SELESAI', ringkasan_diizinkan: values.ringkasan_diizinkan }, { transaction: t });
        await audit(req, 'penanganan', ctx.handling.id, before, ctx.handling.toJSON(), 'TUTUP_PENANGANAN', t);
        const reports = await models.laporan.findAll({ where: { id_penanganan_siswa: ctx.handling.id }, transaction: t, lock: t.LOCK.UPDATE });
        for (const report of reports) {
          const old = report.toJSON(); await report.update({ status_tindak_lanjut: 'SELESAI' }, { transaction: t });
          await audit(req, 'laporan', report.id, old, report.toJSON(), 'SELESAIKAN_LAPORAN', t);
        }
      } else {
        const before = ctx.report.toJSON(); await ctx.report.update({ status_tindak_lanjut: 'SELESAI' }, { transaction: t });
        await audit(req, 'laporan', ctx.report.id, before, ctx.report.toJSON(), 'SELESAIKAN_LAPORAN', t);
      }
      for (const proposal of rows.filter(r => r.jenis === 'USULAN_PENUTUPAN' && r.status_usulan === 'MENUNGGU')) {
        const beforeProposal = proposal.toJSON();
        await proposal.update({ status_usulan: 'DISETUJUI' }, { transaction: t });
        await audit(req, 'riwayat', proposal.id, beforeProposal, proposal.toJSON(), 'SETUJUI_PENUTUPAN', t);
        await history(req, ctx, { jenis: 'KEPUTUSAN', id_riwayat_acuan: proposal.id, hasil_keputusan: 'SETUJUI', alasan_keputusan: values.ringkasan_diizinkan, ringkasan_diizinkan: 'Usulan penutupan disetujui.' }, t);
      }
    }
    return row;
  });
  res.json({ data: { tersimpan: true } });
};
