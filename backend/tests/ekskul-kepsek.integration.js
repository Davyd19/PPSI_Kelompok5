const {test,before,after} = require('node:test');
const assert = require('node:assert/strict');
const {sequelize} = require('../src/models');
const {today} = require('../src/controllers/auth.controller');

let server, base;
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
async function request(path,{method='GET',body,token}={}) {
  const response = await fetch(base+path,{method,
    headers:{...(token?{Authorization:'Bearer '+token}:{}),...(body?{'Content-Type':'application/json'}:{})},
    body:body?JSON.stringify(body):undefined});
  const type = response.headers.get('content-type') || '';
  const payload = type.includes('json') ? await response.json() : await response.text();
  return {status:response.status,data:payload.data,error:payload.error,text:typeof payload==='string'?payload:null};
}
async function login(identity,platform) {
  const r = await request('/auth/login',{method:'POST',body:{identitas_akun:identity,kata_sandi:'Contoh123!',platform}});
  assert.equal(r.status,200,JSON.stringify(r));
  return r.data.access_token;
}

test('Pembina: alur pertemuan, presensi manual, koreksi, rekap, dan prestasi',async()=>{
  const token = await login('contoh.guru','mobile');
  const web = await login('contoh.guru','web');
  assert.equal((await request('/pembina/kegiatan',{token:web})).status,403, 'token web ditolak');
  assert.equal((await request('/pembina/kegiatan')).status,401);

  const home = await request('/pembina/kegiatan',{token});
  assert.equal(home.status,200);
  const period = home.data.activities[0];
  assert.ok(period.anggota_aktif >= 1);

  const created = await request(`/pembina/kegiatan/${period.id}/pertemuan`,{method:'POST',token,
    body:{tanggal:today(),jam_mulai:'15:00',jam_selesai:'16:30',lokasi:'Lapangan',agenda:'Uji'}});
  assert.equal(created.status,201,JSON.stringify(created));
  const meeting = created.data.id;
  assert.equal((await request(`/pembina/kegiatan/${period.id}/pertemuan`,{method:'POST',token,
    body:{tanggal:today(),jam_mulai:'16:00',jam_selesai:'15:00',lokasi:'X'}})).status,422);

  // Presensi sebelum sesi dibuka ditolak.
  const list0 = await request(`/pembina/pertemuan/${meeting}/presensi`,{token});
  const member = list0.data.anggota[0].id_keanggotaan;
  assert.equal((await request(`/pembina/pertemuan/${meeting}/presensi`,{method:'PUT',token,
    body:{presensi:[{id_keanggotaan:member,status_kehadiran:'HADIR'}]}})).status,409);

  assert.equal((await request(`/pembina/pertemuan/${meeting}/buka`,{method:'POST',token})).status,200);
  assert.equal((await request(`/pembina/pertemuan/${meeting}/buka`,{method:'POST',token})).status,409);
  assert.equal((await request(`/pembina/pertemuan/${meeting}/presensi`,{method:'PUT',token,
    body:{presensi:[{id_keanggotaan:member,status_kehadiran:'TERLAMBAT'}]}})).status,422);
  const mark = await request(`/pembina/pertemuan/${meeting}/presensi`,{method:'PUT',token,
    body:{presensi:[{id_keanggotaan:member,status_kehadiran:'HADIR'}]}});
  assert.equal(mark.status,200,JSON.stringify(mark));

  assert.equal((await request(`/pembina/pertemuan/${meeting}/tutup`,{method:'POST',token})).status,200);
  const fix = await request(`/pembina/pertemuan/${meeting}/presensi`,{method:'PUT',token,
    body:{presensi:[{id_keanggotaan:member,status_kehadiran:'SAKIT',keterangan:'Surat dokter'}]}});
  assert.equal(fix.data.koreksi,true);

  const recap = await request(`/pembina/kegiatan/${period.id}/rekap`,{token});
  assert.equal(recap.status,200);
  assert.ok(recap.data.total_pertemuan >= 1);

  const win = await request(`/pembina/kegiatan/${period.id}/prestasi`,{method:'POST',token,
    body:{judul:'Juara Uji',tanggal:today(),tingkat_prestasi:'KOTA',hasil_prestasi:'Juara 1',peserta:[home.data.activities[0] && list0.data.anggota[0].id_siswa],nama_tim:'Tim Uji'}});
  assert.equal(win.status,201,JSON.stringify(win));
  assert.equal((await request(`/pembina/kegiatan/${period.id}/prestasi`,{method:'POST',token,
    body:{judul:'X',tanggal:today(),tingkat_prestasi:'GALAKSI',hasil_prestasi:'J',peserta:[1],nama_tim:'T'}})).status,422);
  // Pembina tidak boleh menyentuh periode lain.
  assert.equal((await request('/pembina/kegiatan/999999/anggota',{token})).status,403);
});

test('Kepala Sekolah: dashboard agregat, ringkasan kasus tanpa data pribadi, ekspor CSV',async()=>{
  const signIn = (identitas_akun,platform) => request('/auth/login',{method:'POST',body:{identitas_akun,kata_sandi:'Contoh123!',platform}});
  // Tanpa memilih peran: guru langsung Kesiswaan, Kepala Sekolah memakai akun sendiri dan tidak masuk mobile.
  assert.deepEqual((await signIn('contoh.guru','web')).data.user.available_roles,['KESISWAAN']);
  assert.deepEqual((await signIn('contoh.kepsek','web')).data.user.available_roles,['KEPALA_SEKOLAH']);
  assert.equal((await signIn('contoh.kepsek','mobile')).status,403);
  const token = await login('contoh.kepsek','web');
  // Guru biasa tidak dapat membuka portal Kepala Sekolah; token mobile juga ditolak.
  assert.equal((await request('/kepala-sekolah/dashboard',{token:await login('contoh.guru','web')})).status,403);
  assert.equal((await request('/kepala-sekolah/dashboard',{token:await login('contoh.guru','mobile')})).status,403);
  const d = await request('/kepala-sekolah/dashboard',{token});
  assert.equal(d.status,200,JSON.stringify(d));
  for (const key of ['periode','kehadiran','pelanggaran','kasus','ekskul']) assert.ok(key in d.data,key);
  const cases = await request('/kepala-sekolah/kasus',{token});
  assert.equal(cases.status,200);
  assert.ok(!JSON.stringify(cases.data).match(/siswa|nama|isi_internal|ringkasan/i),'tidak membocorkan data pribadi');
  assert.equal((await request('/kepala-sekolah/ekskul',{token})).status,200);
  const csv = await request('/kepala-sekolah/laporan.csv',{token});
  assert.equal(csv.status,200);
  assert.match(csv.text,/Bagian,Indikator,Nilai|"Bagian","Indikator","Nilai"/);
  assert.equal((await request('/kepala-sekolah/dashboard?tingkat=XIII',{token})).status,422);
});

test('Siswa: daftar ekskul, tidak bisa daftar ganda, dan hanya melihat presensi sendiri',async()=>{
  const token = await login('contoh.siswa','mobile');
  assert.equal((await request('/siswa/ekskul',{token:await login('contoh.siswa','web').catch(()=>null)})).status,401);
  const catalog = await request('/siswa/ekskul',{token});
  assert.equal(catalog.status,200,JSON.stringify(catalog));
  const mine = await request('/siswa/ekskul/saya',{token});
  assert.equal(mine.status,200);
  const member = catalog.data.find(c=>c.anggota);
  if (member) {
    assert.equal((await request(`/siswa/ekskul/${member.id}/daftar`,{method:'POST',token,body:{}})).status,409);
    assert.equal((await request(`/siswa/ekskul/${member.id}/presensi`,{token})).status,200);
  }
  assert.equal((await request('/siswa/ekskul',{token:await login('contoh.guru','mobile')})).status,403);
});

test('Presensi ekskul mandiri: siswa memindai QR pembina, token berputar dan tidak bisa dipakai ulang',async()=>{
  const coach = await login('contoh.guru','mobile');
  const student = await login('contoh.siswa','mobile');
  const scan = (kode,token=student) => request('/siswa/ekskul/presensi/scan',{method:'POST',token,body:{kode}});
  const period = (await request('/pembina/kegiatan',{token:coach})).data.activities[0];
  const meeting = (await request(`/pembina/kegiatan/${period.id}/pertemuan`,{method:'POST',token:coach,
    body:{tanggal:today(),jam_mulai:'17:00',jam_selesai:'18:00',lokasi:'Aula',agenda:'Uji QR'}})).data.id;

  assert.equal((await request(`/pembina/pertemuan/${meeting}/qr`,{method:'POST',token:coach})).status,409,'QR butuh sesi dibuka');
  assert.equal((await request(`/pembina/pertemuan/${meeting}/buka`,{method:'POST',token:coach})).status,200);
  const first = await request(`/pembina/pertemuan/${meeting}/qr`,{method:'POST',token:coach});
  assert.equal(first.status,200,JSON.stringify(first));
  assert.match(first.data.kode,new RegExp(`^EKSKUL:${meeting}:`));
  const fresh = (await request(`/pembina/pertemuan/${meeting}/qr`,{method:'POST',token:coach})).data.kode;
  assert.equal((await scan(first.data.kode)).status,422,'token lama tidak berlaku setelah QR diperbarui');
  assert.equal((await scan('bukan-qr')).status,422);
  assert.equal((await scan(fresh,coach)).status,403,'hanya siswa yang dapat memindai');

  const ok = await scan(fresh);
  assert.equal(ok.status,201,JSON.stringify(ok));
  assert.equal(ok.data.status_kehadiran,'HADIR');
  assert.equal((await scan(fresh)).status,409,'tidak dapat presensi dua kali');
  const list = await request(`/pembina/pertemuan/${meeting}/presensi`,{token:coach});
  assert.ok(list.data.anggota.some(a=>a.status_kehadiran==='HADIR'));
  assert.ok(!JSON.stringify(list).includes('hash_token_qr'),'hash token tidak dikirim');
  const [audit] = await sequelize.query("SELECT id_guru,id_siswa FROM audit_perubahan WHERE jenis_tindakan='SCAN_PRESENSI_EKSKUL' ORDER BY id DESC LIMIT 1");
  assert.ok(audit[0].id_siswa && !audit[0].id_guru,'pelaku audit tercatat sebagai siswa');

  const expiring = (await request(`/pembina/pertemuan/${meeting}/qr`,{method:'POST',token:coach})).data.kode;
  await sequelize.query('UPDATE pertemuan_ekstrakurikuler SET token_kedaluwarsa = NOW(3) - INTERVAL 1 MINUTE WHERE id = ?',{replacements:[meeting]});
  assert.equal((await scan(expiring)).status,422,'QR kedaluwarsa ditolak');
  assert.equal((await request(`/pembina/pertemuan/${meeting}/tutup`,{method:'POST',token:coach})).status,200);
  assert.equal((await request(`/pembina/pertemuan/${meeting}/qr`,{method:'POST',token:coach})).status,409);
});

test('Profil memuat data kontak dari database',async()=>{
  const me = await request('/auth/me',{token:await login('contoh.siswa','mobile')});
  assert.equal(me.status,200);
  for (const key of ['email','telepon','nisn','nis']) assert.ok(key in me.data,key);
  const teacher = await request('/auth/me',{token:await login('contoh.guru','mobile')});
  assert.equal(teacher.data.email,'guru@example.invalid');
  assert.ok(!('nisn' in teacher.data));
});
