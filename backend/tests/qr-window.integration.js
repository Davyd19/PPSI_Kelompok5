const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {models,sequelize}=require('../src/models');
const {today}=require('../src/controllers/auth.controller');
let server,base,teacher,bk,student,session,code,child;
async function request(path,token,body) {
 const response=await fetch(base+path,{method:body?'POST':'GET',headers:{...(token?{Authorization:'Bearer '+token}:{}),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});
 return {status:response.status,...await response.json()};
}
async function login(identity,platform='mobile') {
 const r=await request('/auth/login',null,{identitas_akun:identity,kata_sandi:'Contoh123!',platform});
 assert.equal(r.status,200,JSON.stringify(r));return r.data.access_token;
}
const iso=offset=>new Date(Date.now()+offset).toISOString();
before(async()=>{
 if(!/^sim_qr_window_.*_qa$/.test(process.env.DB_NAME||''))throw Error('Use a dedicated QR QA database.');
 server=require('../src/app').listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));base=`http://127.0.0.1:${server.address().port}/api/v1`;
 teacher=await login('contoh.guru');bk=await login('contoh.bk');student=await login('contoh.siswa');
 child=await models.siswa.findOne({where:{identitas_login:'contoh.siswa'}});
});
after(async()=>{if(server){server.closeAllConnections();await new Promise(r=>server.close(r));}await sequelize.close();});
test('schedule, server scan boundary, manual after expiry, editing and historic records',async()=>{
 // The database is dedicated to this suite; no reset is performed on existing records.
 const badgeRules=JSON.stringify((await models.level.findAll({order:[['id','ASC']]})).map(r=>r.toJSON()));
 const created=await request('/guru/presensi/sesi',teacher,{jenis_sesi:'PAGI',qr_aktif_mulai:iso(60000),qr_aktif_sampai:iso(120000)});
 assert.equal(created.status,201,JSON.stringify(created));session=created.data.sesi;code=created.data.qr.kode;
 assert.equal(created.data.qr.status,'TERJADWAL');
 assert.equal((await request(`/guru/presensi/sesi/${session.id}/koreksi`,teacher,{id_siswa:child.id,status_kehadiran:'PENGECUALIAN_SAH',alasan:'Tidak berlaku pada pagi'})).status,422);
 assert.equal((await request(`/guru/presensi/sesi/${session.id}/manual-kelas`,teacher,{id_kelas:1,entri:[{id_siswa:child.id,status_kehadiran:'TERLAMBAT',alasan:'Status lama tidak ditulis'}]})).status,422);
 assert.equal((await request('/student/attendance/scan',student,{qr_code:code})).status,422);
 const edit=await request(`/guru/presensi/sesi/${session.id}/qr/berlaku`,bk,{qr_aktif_mulai:iso(-60000),qr_aktif_sampai:iso(60000)});
 assert.equal(edit.status,200,JSON.stringify(edit));assert.equal(edit.data.kode,code);assert.equal(edit.data.status,'AKTIF');
 // Old cutoff is deliberately before scan: it must no longer produce TERLAMBAT.
 await models.sesi.update({batas_tepat_waktu:new Date(Date.now()-120000)},{where:{id:session.id}});
 const results=await Promise.all([request('/student/attendance/scan',student,{qr_code:code}),request('/student/attendance/scan',student,{qr_code:code})]);
 assert.deepEqual(results.map(r=>r.status).sort(),[201,409]);assert.equal(results.find(r=>r.status===201).data.status_kehadiran,'HADIR');
 const attendance=await models.presensi.findOne({where:{id_sesi_presensi_sekolah:session.id,id_siswa:child.id}});
 const snapshot=attendance.toJSON();
 const audit=await models.audit.findOne({where:{jenis_tindakan:'ATUR_BERLAKU_QR_PRESENSI',identitas_data:String(session.id)}});
 const bkMe=await request('/auth/me',bk);assert.equal(audit.id_guru,bkMe.data.id);
 assert.ok(await models.detail_audit.count({where:{id_audit_perubahan:audit.id,nama_atribut:'qr_aktif_mulai'}}));
 await models.sesi.update({token_kedaluwarsa:new Date(Date.now()-1)},{where:{id:session.id}});
 assert.equal((await request('/student/attendance/scan',student,{qr_code:code})).status,422);
 const manual=await request(`/guru/presensi/sesi/${session.id}/manual`,teacher,{id_siswa:child.id,status_kehadiran:'TERLAMBAT',alasan:'Percobaan status lama'});
 assert.equal(manual.status,422);
 const correction=await request(`/guru/presensi/sesi/${session.id}/koreksi`,teacher,{id_siswa:child.id,status_kehadiran:'TERLAMBAT',alasan:'Percobaan status lama'});
 assert.equal(correction.status,422);
 assert.deepEqual((await attendance.reload()).toJSON(),snapshot);
 const again=await request(`/guru/presensi/sesi/${session.id}/qr/berlaku`,teacher,{qr_aktif_mulai:iso(-60000),qr_aktif_sampai:iso(60000)});
 assert.equal(again.status,200);assert.equal(again.data.kode,code);
 assert.equal((await request(`/guru/presensi/sesi/${session.id}/qr/tutup`,teacher,{})).status,200);
 assert.equal((await models.sesi.findByPk(session.id)).status,'AKTIF');
 assert.equal(JSON.stringify((await models.level.findAll({order:[['id','ASC']]})).map(r=>r.toJSON())),badgeRules);
 // A second session proves expiry still permits a NEW manual record.
 const z=await request('/guru/presensi/sesi',teacher,{jenis_sesi:'ZUHUR',berlaku_menit:15});assert.equal(z.status,201,JSON.stringify(z));
 await models.sesi.update({token_kedaluwarsa:new Date(Date.now()-1)},{where:{id:z.data.sesi.id}});
 const saved=await request(`/guru/presensi/sesi/${z.data.sesi.id}/manual`,teacher,{id_siswa:child.id,status_kehadiran:'PENGECUALIAN_SAH',alasan:'Pengecualian sah Zuhur QA'});
 assert.equal(saved.status,201,JSON.stringify(saved));
 assert.equal((await request(`/guru/presensi/sesi/${session.id}/tutup`,teacher,{})).status,200);
 assert.equal((await request(`/guru/presensi/sesi/${session.id}/qr/berlaku`,bk,{berlaku_menit:15})).status,409);
 assert.equal((await request(`/guru/presensi/sesi/${session.id}/qr`,teacher)).status,409);
 // Read legacy records: insertion here represents historical imported data, not API writes.
 const legacy=await models.sesi.findOne({where:{jenis_sesi:'PAGI'},order:[['tanggal','ASC']]});
 if(legacy.id!==session.id) {
  const existing=await models.presensi.findOne({where:{id_sesi_presensi_sekolah:legacy.id,id_siswa:child.id}});
  if(existing)await existing.update({status_kehadiran:'TERLAMBAT'});
  assert.ok(await models.presensi.count({where:{status_kehadiran:'TERLAMBAT'}}));
  const [year,month]=legacy.tanggal.split('-');
  const history=await request(`/student/attendance/history?year=${year}&month=${month}`,student);
  assert.equal(history.status,200);assert.ok(history.data.calendar_records.some(r=>r.status==='TERLAMBAT'));
 }
});
test('primary web roles cannot call Guru QR routes; unchanged year and date on invalid edit',async()=>{
 for(const identity of ['contoh.admin','contoh.kesiswaan','contoh.kepsek']) {
  const token=await login(identity,'web');assert.equal((await request('/guru/presensi/sesi',token)).status,403);
 }
 assert.equal((await request('/guru/presensi/sesi',student)).status,403);
 const row=await models.sesi.findOne({where:{tanggal:today(),jenis_sesi:'ZUHUR'}});
 const before=row.toJSON();
 assert.equal((await request(`/guru/presensi/sesi/${row.id}/qr/berlaku`,bk,{qr_aktif_mulai:iso(120000),qr_aktif_sampai:iso(60000)})).status,422);
 assert.equal((await request(`/guru/presensi/sesi/${row.id}/qr/berlaku`,bk,{qr_aktif_mulai:iso(86400000),qr_aktif_sampai:iso(86500000)})).status,422);
 assert.deepEqual((await row.reload()).toJSON(),before);
});
