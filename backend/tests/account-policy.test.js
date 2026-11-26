const {test,after,mock}=require('node:test');
const assert=require('node:assert/strict');
const {models,sequelize}=require('../src/models');
const {allowedPlatform,publicUser}=require('../src/utils/account-access');
after(()=>sequelize.close());
test('platform matrix isolates each main role',()=>{
  for(const role of ['ADMIN','KESISWAAN','KEPALA_SEKOLAH']){assert.ok(allowedPlatform(role,'web'));assert.ok(!allowedPlatform(role,'mobile'));}
  for(const role of ['GURU','GURU_BK','SISWA','ORANG_TUA']){assert.ok(allowedPlatform(role,'mobile'));assert.ok(!allowedPlatform(role,'web'));}
  assert.ok(!allowedPlatform('UNKNOWN','web'));
});
test('BK inherits teacher features while active duties remain supplementary',async()=>{
  mock.method(models.peran,'findByPk',async()=>({kode:'GURU_BK'}));
  mock.method(models.wali,'count',async()=>1);mock.method(models.pembina,'count',async()=>1);
  try {
    const profile=await publicUser('guru',{id:3,id_peran_utama:5,nama:'BK',identitas_login:'bk'},'mobile');
    assert.equal(profile.primary_role,'GURU_BK');assert.deepEqual(profile.duties,['WALI_KELAS','PEMBINA_EKSTRAKURIKULER']);
    assert.ok(profile.available_roles.includes('GURU'));assert.ok(!profile.roles.includes('KESISWAAN'));
    assert.deepEqual((await publicUser('guru',{id:3},'web')).available_roles,[]);
  }finally{mock.restoreAll();}
});
test('evidence cannot be read by teacher/student/parent or mobile requests',async()=>{
  const evidence=require('../src/controllers/report-evidence.controller');
  for(const user of [{id:1,kind:'guru',primary_role:'GURU'},{id:1,kind:'siswa',primary_role:'SISWA'},{id:1,kind:'orang_tua',primary_role:'ORANG_TUA'}]) {
    await assert.rejects(evidence.list({user,authPlatform:'web',params:{id:'1'}},{}),e=>e.status===403);
    await assert.rejects(evidence.download({user,authPlatform:'web',params:{id:'1'}},{}),e=>e.status===403);
  }
  await assert.rejects(evidence.list({user:{id:1,kind:'guru',primary_role:'KESISWAAN'},authPlatform:'mobile',params:{id:'1'}},{}),e=>e.status===403);
});
test('conflicting legacy roles stop migration before DDL or data updates',async()=>{
  const migration=require('../database/migrations/20261125000100-primary-account-role');
  let calls=0;
  const query={sequelize:{query:async()=>{calls++;return [[{identitas_login:'conflict',peran:'ADMIN,GURU_BK'}]];}}};
  await assert.rejects(migration.up(query,{}),/conflict/);assert.equal(calls,1);
});

test('new badge rules reject late without changing the historical calculation',async()=>{
  const {validate}=require('../src/validators/admin.validation');
  const level={target:1,urutan:1,sumber_data:'PRESENSI_SEKOLAH',jenis_presensi:'PAGI',status_kehadiran_yang_dihitung:'TERLAMBAT'};
  await assert.rejects(validate('level',level,null,null),e=>e.status===422 && /historis/.test(e.message));
  await validate('level',{...level,status_kehadiran_yang_dihitung:'HADIR'},null,null);
  const {measure}=require('../src/services/badges');
  assert.equal(measure([{tanggal:'2026-10-01',status:'TERLAMBAT'}],'AKUMULASI','TERLAMBAT').score,1);
});
