const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');const {models,sequelize}=require('../src/models');
let server,base,student,parent,teacher;
async function request(path,token,body){const r=await fetch(base+path,{method:body?'POST':'GET',headers:{...(token?{Authorization:'Bearer '+token}:{}),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});const p=await r.json();return{status:r.status,...p};}
async function login(id,platform='mobile'){const r=await request('/auth/login',null,{identitas_akun:id,kata_sandi:'Contoh123!',platform});assert.equal(r.status,200,JSON.stringify(r));return r.data.access_token;}
before(async()=>{if(!/_qa$/.test(process.env.DB_NAME||''))throw Error('Database QA wajib.');server=require('../src/app').listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));base=`http://127.0.0.1:${server.address().port}/api/v1`;student=await login('contoh.siswa');parent=await login('contoh.ortu');teacher=await login('contoh.guru');});
after(async()=>{if(server){server.closeAllConnections();await new Promise(r=>server.close(r));}await sequelize.close();});
test('teammate Student and Parent read-only modules remain connected',async()=>{
 for(const path of ['/student/dashboard','/student/attendance/history','/student/counseling','/student/badges','/student/extracurriculars','/student/achievements','/student/notifications']){const r=await request(path,student);assert.equal(r.status,200,path+': '+JSON.stringify(r));}
 for(const path of ['/parent/dashboard','/parent/attendance','/parent/achievements','/parent/badges','/parent/extracurriculars','/parent/counseling','/parent/notifications']){const r=await request(path,parent);assert.equal(r.status,200,path+': '+JSON.stringify(r));assert.ok(!JSON.stringify(r).includes('isi_internal'),path);}
 assert.equal((await request('/parent/dashboard',student)).status,403);
 assert.equal((await request('/student/dashboard',parent)).status,403);
});
test('Guru profile remains editable and uses primary role',async()=>{
 const r=await request('/guru/profil',teacher);assert.equal(r.status,200,JSON.stringify(r));assert.ok(r.data.peran.includes('Guru'));assert.ok(!r.data.peran.includes('Guru BK'));
 const saved=await request('/guru/profil',teacher,{email:'guru@example.invalid',telepon:'081234567890'});assert.equal(saved.status,200,JSON.stringify(saved));
});
test('school QR emitted by Guru is accepted by retained Student scanner exactly once',async()=>{
 const opened=await request('/guru/presensi/sesi',teacher,{jenis_sesi:'ZUHUR',batas_tepat_waktu:'23:59'});assert.equal(opened.status,201,JSON.stringify(opened));
 const scanned=await request('/student/attendance/scan',student,{qr_code:opened.data.qr.kode});assert.equal(scanned.status,201,JSON.stringify(scanned));assert.ok(scanned.data.presensi_id);assert.equal(scanned.data.student_name,'Siswa Contoh');
 assert.equal((await request('/student/attendance/scan',student,{qr_code:opened.data.qr.kode})).status,409);
 assert.equal((await request('/student/attendance/scan',student,{qr_code:'EKSKUL:1:disabled'})).status,422);
 assert.equal((await request('/student/attendance/scan',student,{manual_code:'arbitrary'})).status,422);
});

test('role changes revoke existing sessions and last Admin stays protected',async()=>{
 const admin=await login('contoh.admin','web');
 const role=await models.peran.findOne({where:{kode:'KESISWAAN'}});
 const teacherRole=await models.peran.findOne({where:{kode:'GURU'}});
 const created=await request('/admin/guru',admin,{nama:'Akun uji perubahan peran',identitas_login:'qa.role.change',id_peran_utama:role.id,kata_sandi:'Contoh123!',status_akun:'AKTIF'});assert.equal(created.status,201,JSON.stringify(created));
 const session=await login('qa.role.change','web');
 const changed=await fetch(base+'/admin/guru/'+created.data.id,{method:'PATCH',headers:{Authorization:'Bearer '+admin,'Content-Type':'application/json'},body:JSON.stringify({id_peran_utama:teacherRole.id})});assert.equal(changed.status,200);
 assert.equal((await request('/auth/me',session)).status,401);
 assert.equal((await request('/auth/login',null,{identitas_akun:'qa.role.change',kata_sandi:'Contoh123!',platform:'web'})).status,403);
 const me=await request('/auth/me',admin);
 const denied=await fetch(base+'/admin/guru/'+me.data.id,{method:'PATCH',headers:{Authorization:'Bearer '+admin,'Content-Type':'application/json'},body:JSON.stringify({id_peran_utama:teacherRole.id})});assert.equal(denied.status,409);assert.equal((await request('/auth/me',admin)).status,200);
});
test('Guru evidence remains private and Kesiswaan can review the uploaded file',async()=>{
 const author=await request('/auth/me',teacher);const child=await models.siswa.findOne({where:{identitas_login:'contoh.siswa'}});const version=await models.aturan.findOne();
 const report=await models.laporan.create({id_siswa:child.id,id_versi_aturan_penanganan:version.id,id_guru_pelapor:author.data.id,waktu_kejadian:new Date(),uraian:'Bukti QA',status_verifikasi:'MENUNGGU',status_tindak_lanjut:'BELUM_DITANGANI'});
 const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=','base64');
 const upload=await fetch(base+'/guru/pelanggaran/'+report.id+'/bukti',{method:'POST',headers:{Authorization:'Bearer '+teacher,'Content-Type':'image/png','X-Filename':'bukti-qa.png'},body:png});assert.equal(upload.status,201);
 const ks=await login('contoh.kesiswaan','web');const list=await request('/kesiswaan/reports/'+report.id+'/bukti',ks);assert.equal(list.status,200);assert.equal(list.data.length,1);assert.ok(!('lokasi_berkas' in list.data[0]));
 const file=await fetch(base+'/kesiswaan/bukti/'+list.data[0].id,{headers:{Authorization:'Bearer '+ks}});assert.equal(file.status,200);assert.deepEqual(Buffer.from(await file.arrayBuffer()),png);
 assert.equal((await request('/kesiswaan/reports/'+report.id+'/bukti',student)).status,403);
});
