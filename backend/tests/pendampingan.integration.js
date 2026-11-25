const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { sequelize, models } = require('../src/models');
const { hashPassword } = require('../src/utils/security');
let server, base, bk, wali, other, report, student, handling;
const password = ['Contoh', '123!'].join('');
async function request(path, token, body) {
  const response = await fetch(base + path, { method: body ? 'POST' : 'GET', headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body ? { 'Content-Type': 'application/json' } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}) });
  return { status: response.status, ...await response.json() };
}
async function login(identity, platform = 'mobile') {
  const result = await request('/auth/login', null, { identitas_akun: identity, kata_sandi: password, platform });
  assert.equal(result.status, 200, JSON.stringify(result));
  return result.data;
}
before(async () => {
  if (!/_qa$/.test(process.env.DB_NAME || '')) throw Error('Gunakan database QA terpisah.');
  server = require('../src/app').listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api/v1`;
  const role = await models.peran.findOne({ where: { kode: 'GURU_BK' } });
  const primaryRole = Object.hasOwn(models.guru.rawAttributes, 'id_peran_utama');
  const teacher = await models.guru.create({ nama: 'BK Integrasi QA', identitas_login: `qa.bk.${Date.now()}`, hash_kata_sandi: await hashPassword(password), status_akun: 'AKTIF', ...(primaryRole ? { id_peran_utama: role.id } : {}) });
  if (!primaryRole) await models.guru_peran.create({ id_guru: teacher.id, id_peran: role.id, tanggal_mulai: '2026-01-01' });
  bk = (await login(teacher.identitas_login)).access_token;
  // The development teacher owns the sample class and retains ordinary Guru features.
  const teacherLogin = await login('contoh.guru');
  wali = teacherLogin.access_token;
  assert.ok(teacherLogin.user.available_roles.includes('WALI_KELAS'));
  const foreignTeacher = await models.guru.create({ nama: 'BK Lain QA', identitas_login: `qa.bk.lain.${Date.now()}`, hash_kata_sandi: await hashPassword(password), status_akun: 'AKTIF', ...(primaryRole ? { id_peran_utama: role.id } : {}) });
  if (!primaryRole) await models.guru_peran.create({ id_guru: foreignTeacher.id, id_peran: role.id, tanggal_mulai: '2026-01-01' });
  other = (await login(foreignTeacher.identitas_login)).access_token;
  student = await models.siswa.findOne({ where: { identitas_login: 'contoh.siswa' } });
  const rule = await models.aturan.findOne();
  report = await models.laporan.create({ id_siswa: student.id, id_versi_aturan_penanganan: rule.id, id_guru_pelapor: teacherLogin.user.id, waktu_kejadian: new Date(), uraian: 'Laporan QA pendampingan', status_verifikasi: 'MENUNGGU', status_tindak_lanjut: 'BELUM_DITANGANI' });
});
after(async () => { if (server) await new Promise(resolve => server.close(resolve)); await sequelize.close(); });
test('guards reject unauthenticated, student and web callers; Wali only sees assigned students', async () => {
  assert.equal((await request('/guru-bk/kasus')).status, 401);
  const siswa = await login('contoh.siswa');
  assert.equal((await request('/guru-bk/kasus', siswa.access_token)).status, 403);
  const web = await login('contoh.admin', 'web');
  assert.equal((await request('/guru-bk/kasus', web.access_token)).status, 403);
  assert.equal((await request(`/wali-kelas/kasus/${report.id}`, wali)).status, 200);
  const foreign = await models.siswa.create({ nama: 'Siswa Luar QA', nisn: `9${Date.now()}`.slice(-10), identitas_login: `qa.siswa.${Date.now()}`, hash_kata_sandi: await hashPassword(password), status_siswa: 'AKTIF', status_akun: 'AKTIF' });
  const r = await models.laporan.create({ ...report.toJSON(), id: undefined, id_siswa: foreign.id });
  assert.equal((await request(`/wali-kelas/kasus/${r.id}`, wali)).status, 404);
  assert.equal((await request(`/wali-kelas/kasus/${report.id}/tutup`, wali, { alasan_penutupan: 'Tidak berwenang' })).status, 404);
});
test('verification validates input and concurrent requests cannot verify twice', async () => {
  assert.equal((await request(`/guru-bk/kasus/${report.id}/rencana-konseling`, bk, { tujuan: 'x', bentuk_kegiatan: 'x', jadwal: new Date().toISOString() })).status, 409);
  assert.equal((await request(`/guru-bk/kasus/${report.id}/verifikasi`, bk, { hasil: 'SALAH', catatan: 'x' })).status, 422);
  const createAudit = models.audit.create;
  models.audit.create = async () => { throw Error('Kegagalan audit QA yang disengaja'); };
  try { assert.equal((await request(`/guru-bk/kasus/${report.id}/verifikasi`, bk, { hasil: 'TERIMA', catatan: 'Harus rollback' })).status, 500); }
  finally { models.audit.create = createAudit; }
  await report.reload(); assert.equal(report.status_verifikasi, 'MENUNGGU');
  assert.equal(await models.riwayat.count({ where: { id_laporan_pelanggaran: report.id } }), 0);
  const results = await Promise.all([1, 2].map(() => request(`/guru-bk/kasus/${report.id}/verifikasi`, bk, { hasil: 'TERIMA', catatan: 'Laporan sudah diperiksa' })));
  assert.deepEqual(results.map(r => r.status).sort(), [200, 409]);
});
test('plan creates handling once, can be updated, and remains available after reload', async () => {
  const path = `/guru-bk/kasus/${report.id}/rencana-konseling`;
  const data = { tujuan: 'Tujuan awal QA', bentuk_kegiatan: 'KONSELING_INDIVIDU', jadwal: new Date().toISOString(), rencana_tindak_lanjut: 'Evaluasi' };
  assert.equal((await request(path, bk, { ...data, tujuan: '' })).status, 422);
  assert.equal((await request(path, bk, data)).status, 200);
  await report.reload(); handling = await models.penanganan.findByPk(report.id_penanganan_siswa);
  assert.ok(handling);
  assert.equal((await request(path, bk, { ...data, tujuan: 'Tujuan diperbarui QA' })).status, 200);
  assert.equal(await models.rencana.count({ where: { id_penanganan_siswa: handling.id } }), 1);
  assert.equal((await request(path, bk)).data.tujuan, 'Tujuan diperbarui QA');
  assert.equal((await request(`/guru-bk/kasus/${handling.id}?sumber=PENANGANAN`, bk)).data.sumber, 'PENANGANAN');
  assert.equal((await request(`/guru-bk/kasus/${report.id}`, other)).status, 404);
});
test('BK private notes never leak through Wali list/detail; shared notes persist', async () => {
  const privateText = 'ISI PRIVAT ASESMEN QA';
  assert.equal((await request(`/guru-bk/kasus/${report.id}/catatan-konseling`, bk, { kondisi_permasalahan: privateText, hasil_asesmen: 'Analisis', ringkasan_konseling: 'Internal', rencana_tindak_lanjut: 'Internal berikutnya' })).status, 200);
  const own = await request(`/guru-bk/kasus/${report.id}`, bk);
  assert.ok(JSON.stringify(own.data).includes(privateText));
  const visible = await request(`/wali-kelas/kasus/${handling.id}?sumber=PENANGANAN`, wali);
  assert.equal(visible.status, 200);
  assert.ok(!JSON.stringify(visible.data).includes(privateText));
  assert.equal((await request(`/wali-kelas/kasus/${report.id}/catatan-pembinaan`, wali, { hasil_pembinaan: 'Ringkasan bersama QA', tindakan_diberikan: 'Diskusi', rencana_tindak_lanjut: 'Pantau' })).status, 200);
  assert.ok(JSON.stringify((await request(`/guru-bk/kasus/${report.id}`, bk)).data).includes('Ringkasan bersama QA'));
  assert.equal((await request('/guru-bk/kasus?status=SALAH', bk)).status, 422);
});
test('parent involvement and monitoring do not automatically close a case', async () => {
  assert.equal((await request(`/wali-kelas/kasus/${report.id}/tindak-lanjut-ortu`, wali, { hasil_komunikasi: 'Koordinasi', tanggal_komunikasi: new Date().toISOString(), bentuk_keterlibatan: 'Pertemuan', rencana_tindak_lanjut: 'Pantau' })).status, 200);
  assert.equal((await request(`/guru-bk/kasus/${report.id}/pemantauan`, bk, { keputusan: 'TIDAK_PERLU' })).status, 200);
  await handling.reload(); assert.equal(handling.status, 'TERBUKA');
});
test('escalation rejects duplicate pending proposals and can be reviewed by Kesiswaan', async () => {
  const path = `/guru-bk/kasus/${report.id}/eskalasi`;
  const body = { pihak_tujuan: 'Kesiswaan', alasan: 'Butuh tindak lanjut', hasil_evaluasi: 'Evaluasi internal QA', informasi_pendukung: 'Dokumen internal QA' };
  assert.equal((await request(path, bk, body)).status, 200);
  assert.equal((await request(path, bk, body)).status, 409);
  const proposal = await models.riwayat.findOne({ where: { id_penanganan_siswa: handling.id, jenis: 'USULAN_ESKALASI' }, order: [['id', 'DESC']] });
  const shared = await request(`/wali-kelas/kasus/${report.id}`, wali);
  assert.ok(!JSON.stringify(shared.data).includes('Evaluasi internal QA'));
  assert.equal((await request(`/guru-bk/kasus/${report.id}/tutup`, bk, { alasan_penutupan: 'Selesai', catatan_akhir: 'Akhir' })).status, 409);
  const ksAccount = await models.guru.findOne({ where: { identitas_login: 'contoh.kesiswaan' } });
  const ks = await login(ksAccount ? 'contoh.kesiswaan' : 'contoh.guru', 'web');
  const decisions = await Promise.all([1, 2].map(() => request(`/kesiswaan/proposals/${proposal.id}/decision`, ks.access_token, { keputusan: 'TOLAK', alasan: 'Belum perlu eskalasi', arahan: 'Lanjutkan pembinaan' })));
  assert.deepEqual(decisions.map(r => r.status).sort(), [200, 409]);
  assert.equal((await request(`/wali-kelas/kasus/${report.id}/usulan`, wali, { jenis_usulan: 'PENUTUPAN', alasan: 'Selesai pembinaan', catatan_pendukung: 'Hasil pemantauan' })).status, 200);
});
test('explicit BK closure records decision, audit and closes linked reports; further edits rejected', async () => {
  assert.equal((await request(`/guru-bk/kasus/${report.id}/tutup`, bk, { alasan_penutupan: 'Pendampingan selesai QA', catatan_pendukung: 'Selesai', catatan_akhir: 'Catatan internal akhir' })).status, 200);
  await handling.reload(); await report.reload();
  assert.equal(handling.status, 'SELESAI'); assert.equal(report.status_tindak_lanjut, 'SELESAI');
  assert.equal((await request(`/guru-bk/kasus/${report.id}/tindak-lanjut`, bk, { catatan: 'Terlambat' })).status, 409);
  assert.ok(await models.audit.count({ where: { jenis_tindakan: 'TUTUP_PENANGANAN', identitas_data: String(handling.id) } }));
  const closeProposal = await models.riwayat.findOne({ where: { id_penanganan_siswa: handling.id, jenis: 'USULAN_PENUTUPAN' } });
  assert.equal(closeProposal.status_usulan, 'DISETUJUI');
});
test('counseling without a violation remains readable and editable by assigned BK', async () => {
  const row = await models.penanganan.create({ id_siswa: student.id, id_guru_bk_penanggung_jawab: handling.id_guru_bk_penanggung_jawab, tanggal_dibuka: '2026-11-25', sumber_pengajuan: 'KONSELING', alasan_pembukaan: 'Konseling tanpa laporan QA', status: 'TERBUKA' });
  const rows = await request('/guru-bk/kasus', bk);
  assert.ok(rows.data.some(c => c.sumber === 'PENANGANAN' && c.id === row.id));
  assert.equal((await request(`/guru-bk/kasus/${row.id}/tindak-lanjut?sumber=PENANGANAN`, bk, { catatan: 'Catatan tanpa pelanggaran' })).status, 200);
  const seen = await request(`/wali-kelas/kasus/${row.id}?sumber=PENANGANAN`, wali);
  assert.ok(!JSON.stringify(seen.data).includes('Catatan tanpa pelanggaran'));
});

test('ended Wali assignment removes case access immediately', async () => {
  const teacher = await models.guru.findOne({ where: { identitas_login: 'contoh.guru' } });
  const assignments = await models.wali.findAll({ where: { id_guru: teacher.id } });
  const before = assignments.map(row => row.tanggal_selesai);
  try {
    for (const row of assignments) await row.update({ tanggal_selesai: '2026-11-24' });
    assert.equal((await request('/wali-kelas/kasus', wali)).status, 403);
  } finally {
    for (let index = 0; index < assignments.length; index++) await assignments[index].update({ tanggal_selesai: before[index] });
  }
});
