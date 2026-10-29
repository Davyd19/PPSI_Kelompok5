const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const app = require('../src/app');
let server, base;
before(async () => { server = app.listen(0, '127.0.0.1'); await new Promise(resolve => server.once('listening', resolve)); base = `http://127.0.0.1:${server.address().port}/api/v1`; });
after(() => new Promise(resolve => server.close(resolve)));
test('health does not pretend to check MySQL', async () => { const r = await fetch(base+'/health'); assert.equal(r.status,200); assert.equal((await r.json()).data.database,'not_checked'); });
test('nine profiles and all role dashboards share one student', async () => {
  const { data: profiles } = await (await fetch(base+'/demo/profiles')).json(); assert.equal(profiles.length,9);
  for (const profile of profiles) { const r = await fetch(base+'/demo/dashboard?role='+profile.role); const { data } = await r.json(); assert.equal(r.status,200); assert.equal(data.profile.role,profile.role); assert.equal(data.student.name,'Farhan Ramadhan'); assert.equal(data.simulation,true); assert.ok(data.menus.length); }
});
test('invalid, missing and repeated role rejected',async () => { for (const query of ['', '?role=invalid', '?role=siswa&role=guru']) {const r=await fetch(base+'/demo/dashboard'+query); assert.equal(r.status,400); assert.equal((await r.json()).error.code,'INVALID_ROLE');} });
test('unknown route, malformed JSON and CORS have safe errors', async () => {
  assert.equal((await fetch(base+'/missing')).status,404);
  assert.equal((await fetch(base+'/demo/profiles',{headers:{Origin:'https://untrusted.example'}})).status,403);
  const allowed=await fetch(base+'/demo/profiles',{headers:{Origin:'http://localhost:5173'}}); assert.equal(allowed.headers.get('access-control-allow-origin'),'http://localhost:5173');
  const bad=await fetch(base+'/missing',{method:'POST',headers:{'Content-Type':'application/json'},body:'{'}); assert.equal(bad.status,400); assert.equal((await bad.json()).error.code,'INVALID_JSON');
});

test('period and grade filter changes charts while preserving current snapshot',async()=>{
 const get=async query=>(await(await fetch(base+'/demo/dashboard?role=kepala_sekolah'+query)).json()).data;
 const oct=await get('&period=2026-10&grade=all'),sep=await get('&period=2026-09&grade=all'),grade=await get('&period=2026-10&grade=x');
 assert.notDeepEqual(oct.trend,sep.trend);assert.notDeepEqual(oct.trend,grade.trend);assert.equal(sep.period,'September 2026');assert.equal(oct.analytics.attendance.reduce((s,a)=>s+a.value,0),oct.analytics.totalStudents);assert.equal(oct.analytics.participation.reduce((s,a)=>s+a.value,0),180);
 for(const q of ['&period=invalid','&grade=invalid','&period=2026-10&period=2026-09']){assert.equal((await fetch(base+'/demo/dashboard?role=admin'+q)).status,400);}
});
