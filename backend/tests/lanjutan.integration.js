const {test,before,after} = require('node:test');
const assert = require('node:assert/strict');
const {models,sequelize} = require('../src/models');
const {today} = require('../src/controllers/auth.controller');
const {reconcile,measure,evaluate} = require('../src/services/badges');

let server, base, staff, student, admin;
before(async () => {
  if (!/_qa$/.test(process.env.DB_NAME || '')) throw new Error('Gunakan database QA.');
  server = require('../src/app').listen(0,'127.0.0.1');
  await new Promise(resolve => server.once('listening',resolve));
  base = `http://127.0.0.1:${server.address().port}/api/v1`;
});
after(async () => {
  if (server) await new Promise(resolve=>server.close(resolve));
  await sequelize.close();
});
async function request(path,{method='GET',body,token,headers={}}={}) {
  const response = await fetch(base+path,{
    method,headers:{...(token?{Authorization:'Bearer '+token}:{}),...(body && !Buffer.isBuffer(body)?{'Content-Type':'application/json'}:{}),...headers},
    body:Buffer.isBuffer(body)?body:body?JSON.stringify(body):undefined
  });
  const data = response.headers.get('content-type')?.includes('json') ? await response.json() : await response.text();
  return {status:response.status,data:data.data,error:data.error,body:data};
}
async function login(identity,platform) {
  const result = await request('/auth/login',{method:'POST',body:{identitas_akun:identity,kata_sandi:'Contoh123!',platform}});
  assert.equal(result.status,200,JSON.stringify(result));
  return result.data;
}
const post=(path,body,token)=>request(path,{method:'POST',body,token});

test('mobile rotation rejects replay and logout revokes only the selected device',async()=>{
  staff=(await login('contoh.guru','web')).access_token;
  admin=(await login('contoh.admin','web')).access_token;
  const first=await login('contoh.siswa','mobile');
  const second=await login('contoh.siswa','mobile');
  student=second.access_token;
  assert.deepEqual(first.user.available_roles,['SISWA']);
  const rotate=await post('/auth/refresh',{refresh_token:first.refresh_token});
  assert.equal(rotate.status,200);
  assert.notEqual(rotate.data.refresh_token,first.refresh_token);
  assert.equal((await post('/auth/refresh',{refresh_token:first.refresh_token})).status,401);
  assert.equal((await request('/auth/me',{token:rotate.data.access_token})).status,401);
  assert.equal((await request('/auth/me',{token:student})).status,200);
  const third=await login('contoh.siswa','mobile');
  assert.equal((await post('/auth/logout',{refresh_token:third.refresh_token})).status,204);
  assert.equal((await post('/auth/logout',{refresh_token:third.refresh_token})).status,204);
  assert.equal((await request('/auth/me',{token:third.access_token})).status,401);
  assert.equal((await request('/auth/me',{token:student})).status,200);
});

test('role choices follow live assignments and a mobile token cannot operate the web portal',async()=>{
  const teacher=await login('contoh.guru','mobile');
  assert.ok(teacher.user.available_roles.includes('GURU_BK'));
  assert.ok(teacher.user.available_roles.includes('WALI_KELAS'));
  assert.ok(teacher.user.available_roles.includes('PEMBINA_EKSTRAKURIKULER'));
  assert.equal((await request('/kesiswaan/dashboard',{token:teacher.access_token})).status,403);
  const assignment=await models.wali.findOne({where:{id_guru:teacher.user.id}});
  const original=assignment.tanggal_selesai;
  await assignment.update({tanggal_selesai:'2026-07-01'});
  try {
    const me=await request('/auth/me',{token:teacher.access_token});
    assert.equal(me.status,200);
    assert.ok(!me.data.available_roles.includes('WALI_KELAS'));
  } finally {await assignment.update({tanggal_selesai:original});}
  const parent=await login('contoh.ortu','mobile');
  assert.deepEqual(parent.user.available_roles,['ORANG_TUA']);
});

test('password reset and account status revoke all active sessions',async()=>{
  const user=await post('/admin/siswa',{nama:'Siswa Auth QA',nisn:'0199900000',identitas_login:'qa.sesi.siswa',kata_sandi:'Contoh123!',status_akun:'AKTIF',status_siswa:'AKTIF'},admin);
  assert.equal(user.status,201,JSON.stringify(user));
  const first=await login('qa.sesi.siswa','mobile');
  const second=await login('qa.sesi.siswa','mobile');
  const reset=await post(`/admin/accounts/siswa/${user.data.id}/reset-password`,{kata_sandi:'Contoh123!'},admin);
  assert.equal(reset.status,200,JSON.stringify(reset));
  for(const session of [first,second])assert.equal((await post('/auth/refresh',{refresh_token:session.refresh_token})).status,401);
  const active=await login('qa.sesi.siswa','mobile');
  const change=await request(`/admin/siswa/${user.data.id}`,{method:'PATCH',body:{status_akun:'NONAKTIF'},token:admin});
  assert.equal(change.status,200,JSON.stringify(change));
  assert.equal((await request('/auth/me',{token:active.access_token})).status,401);
});

test('real dashboard, historic rules, self-verification and filtered exports',async()=>{
  const dashboard=await request('/kesiswaan/dashboard?mulai=2026-10-01&sampai=2026-10-31',{token:staff});
  assert.equal(dashboard.status,200,JSON.stringify(dashboard));
  assert.ok(dashboard.data.attendance.length);
  const category=await post('/kesiswaan/categories',{nama:'Kategori QA'},staff);
  assert.equal(category.status,201,JSON.stringify(category));
  const cid=category.data.id;
  const version=await post(`/kesiswaan/categories/${cid}/versions`,{berlaku_mulai:'2026-10-01',ketentuan:'Aturan pertama'},staff);
  assert.equal(version.status,201,JSON.stringify(version));
  const s=await models.siswa.findOne({where:{identitas_login:'contoh.siswa'}});
  const report=await post('/kesiswaan/reports',{id_siswa:s.id,id_kategori_pelanggaran:cid,waktu_kejadian:'2026-10-22T09:00+07:00',uraian:'Laporan QA'},staff);
  assert.equal(report.status,201,JSON.stringify(report));
  assert.equal(report.data.id_versi_aturan_penanganan,version.data.id);
  assert.equal((await post(`/kesiswaan/categories/${cid}/versions`,{berlaku_mulai:'2026-10-21',ketentuan:'Bertumpuk'},staff)).status,409);
  const newer=await post(`/kesiswaan/categories/${cid}/versions`,{berlaku_mulai:'2026-11-01',ketentuan:'Aturan baru'},staff);
  assert.equal(newer.status,201,JSON.stringify(newer));
  const checked=await post(`/kesiswaan/reports/${report.data.id}/verify`,{status_verifikasi:'TERVERIFIKASI',catatan:'Sesuai fakta'},staff);
  assert.equal(checked.status,200,JSON.stringify(checked));
  assert.equal(checked.data.id_guru_pelapor,checked.data.id_guru_pemeriksa);
  const filtered='?mulai=2026-10-01&sampai=2026-10-31&status=TERVERIFIKASI';
  const csv=await request('/kesiswaan/reports.csv'+filtered,{token:staff});
  assert.equal(csv.status,200);
  assert.match(csv.body,/Kategori QA/);
  assert.doesNotMatch(csv.body,/isi_internal|Laporan QA/);
  assert.equal((await request('/kesiswaan/attendance.csv?mulai=2026-10-01&sampai=2026-10-31',{token:staff})).status,200);
  assert.equal((await request('/kesiswaan/categories',{token:student})).status,403);
});

test('private counseling notes are excluded and concurrent decisions are serialized',async()=>{
  const penanganan=await models.penanganan.findOne();
  const author=await models.guru.findOne({where:{identitas_login:'contoh.guru'}});
  const proposal=await models.riwayat.create({id_penanganan_siswa:penanganan.id,id_guru_pencatat:author.id,
    jenis:'USULAN_ESKALASI',waktu:new Date(),isi_internal:'CATATAN_PRIVAT_QA',ringkasan_diizinkan:'Ringkasan QA',
    orang_tua_dilibatkan:false,status_usulan:'MENUNGGU'});
  const list=await request('/kesiswaan/proposals',{token:staff});
  assert.equal(list.status,200,JSON.stringify(list));
  assert.match(JSON.stringify(list.data),/Ringkasan QA/);
  assert.doesNotMatch(JSON.stringify(list.data),/CATATAN_PRIVAT_QA|isi_internal/);
  const decision={keputusan:'SETUJUI',alasan:'Valid',arahan:'Tindak lanjuti'};
  const results=await Promise.all([post(`/kesiswaan/proposals/${proposal.id}/decision`,decision,staff),post(`/kesiswaan/proposals/${proposal.id}/decision`,decision,staff)]);
  assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
  assert.equal(await models.riwayat.count({where:{id_riwayat_acuan:proposal.id}}),1);
});

test('prestasi peserta and private validated attachments',async()=>{
  const s=await models.siswa.findOne({where:{identitas_login:'contoh.siswa'}});
  const row=await post('/kesiswaan/achievements',{judul:'Prestasi QA',tanggal:'2026-10-22',tingkat_prestasi:'Sekolah',hasil_prestasi:'Juara',peserta:[s.id]},staff);
  assert.equal(row.status,201,JSON.stringify(row));
  const path=`/kesiswaan/achievements/${row.data.id}/attachments`;
  const headers={'Content-Type':'application/pdf','X-Filename':'bukti.pdf'};
  const upload=body=>request(path,{method:'POST',token:staff,headers,body:Buffer.from(body)});
  assert.equal((await upload('invalid')).status,422);
  const attachment=await upload('%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%EOF');
  assert.equal(attachment.status,201,JSON.stringify(attachment));
  assert.equal((await request('/kesiswaan/achievements',{token:staff})).status,200);
  const url='/kesiswaan/attachments/'+attachment.data.id;
  assert.equal((await request(url,{token:student})).status,403);
  assert.match((await request(url,{token:staff})).body,/%PDF-1.4/);
});

test('streak handles exceptions, uncertainty, and resets per semester',()=>{
  const row=(tanggal,status)=>({tanggal,status,jenis_sesi:'PAGI'});
  const events=[row('2026-10-01','HADIR'),row('2026-10-02','PENGECUALIAN_SAH'),row('2026-10-03',null),row('2026-10-04','HADIR')];
  assert.deepEqual([measure(events,'BERUNTUN','HADIR').score,measure(events,'BERUNTUN','HADIR').possible],[1,3]);
  assert.equal(measure(events,'AKUMULASI','HADIR').score,2);
  const semesters=[{id:1,tanggal_mulai:'2026-07-01',tanggal_selesai:'2026-12-31'},{id:2,tanggal_mulai:'2027-01-01',tanggal_selesai:'2027-06-30'}];
  const level={id_semester_mulai:1,cara_hitung:'BERUNTUN',status_kehadiran_yang_dihitung:'HADIR',jenis_presensi:'PAGI',cakupan_perhitungan:'SEMESTER',target:2};
  assert.equal(evaluate(level,semesters,[row('2026-12-30','HADIR'),row('2027-01-03','HADIR')],'2027-01-04').achievedOn,null);
});

test('recalculation revokes and restores one earned row after corrections',async()=>{
  const s=await models.siswa.findOne({where:{identitas_login:'contoh.siswa'}});
  const presence=await models.presensi.findOne({where:{id_siswa:s.id}});
  const award=await models.pencapaian.findOne({where:{id_siswa:s.id}});
  assert.ok(award);
  const before=presence.status_kehadiran;
  try {
    await presence.update({status_kehadiran:'ALFA'});
    await reconcile();
    assert.equal((await award.reload()).aktif,false);
    assert.equal((await reconcile()).changed,0);
    await presence.update({status_kehadiran:before});
    await reconcile();
    assert.equal((await award.reload()).aktif,true);
    const result=await request('/student/badges',{token:student});
    assert.equal(result.status,200,JSON.stringify(result));
    assert.ok(result.data.some(b=>b.diperoleh));
    assert.equal(await models.pencapaian.count({where:{id_siswa:s.id,id_level_badge:award.id_level_badge}}),1);
  } finally {await presence.update({status_kehadiran:before});}
  assert.ok(today());
});
