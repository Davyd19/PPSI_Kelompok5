const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const auth = require('../src/controllers/auth.controller');
const { sequelize } = require('../src/models');

// Exercise router composition without querying or changing a real database.
const mappings = [
  ['GET', '/presensi/sesi', 'presensi-sekolah', 'todaySessions'],
  ['POST', '/presensi/sesi', 'presensi-sekolah', 'open'],
  ['GET', '/presensi/sesi/1/qr', 'presensi-sekolah', 'qr'],
  ['POST', '/presensi/sesi/1/tutup', 'presensi-sekolah', 'close'],
  ['GET', '/presensi/sesi/1/kelas', 'presensi-sekolah', 'classes'],
  ['GET', '/presensi/sesi/1/siswa', 'presensi-sekolah', 'students'],
  ['POST', '/presensi/sesi/1/manual', 'presensi-sekolah', 'manual'],
  ['POST', '/presensi/sesi/1/manual-kelas', 'presensi-sekolah', 'manualBatch'],
  ['POST', '/presensi/sesi/1/koreksi', 'presensi-sekolah', 'correct'],
  ['GET', '/presensi/kelas', 'rekap-kehadiran', 'classes'],
  ['GET', '/presensi/rekap', 'rekap-kehadiran', 'recap'],
  ['GET', '/presensi/rekap/siswa/42', 'rekap-kehadiran', 'studentHistory'],
  ['GET', '/pelanggaran/formulir', 'pelanggaran-guru', 'form'],
  ['GET', '/pelanggaran/siswa', 'pelanggaran-guru', 'students'],
  ['POST', '/pelanggaran', 'pelanggaran-guru', 'create'],
  ['POST', '/pelanggaran/1/bukti', 'pelanggaran-guru', 'upload'],
  ['GET', '/pelanggaran', 'pelanggaran-guru', 'mine'],
  ['GET', '/profil', 'profil-guru', 'show'],
  ['POST', '/profil', 'profil-guru', 'update'],
  ['POST', '/profil/kata-sandi', 'profil-guru', 'changePassword'],
];
let server, base;
const restore = [];
before(async () => {
  for (const [, , module, method] of mappings) {
    const controller = require(`../src/controllers/${module}.controller`);
    if (restore.some(r => r.controller === controller && r.method === method)) continue;
    assert.equal(typeof controller[method], 'function', `${module}.${method} must exist`);
    restore.push({ controller, method, handler: controller[method] });
    controller[method] = (req, res) => res.json({ handler: `${module}.${method}`, params: req.params });
  }
  const authenticate = auth.authenticate;
  restore.push({ controller: auth, method: 'authenticate', handler: authenticate });
  auth.authenticate = (req, res, next) => {
    if (!req.headers['x-test-kind']) return res.status(401).json({ error: { code: 'UNAUTHORIZED' } });
    req.authPlatform = req.headers['x-test-platform'] || 'mobile';
    req.user = { id: 1, kind: req.headers['x-test-kind'], primary_role:req.headers['x-test-role'] || 'GURU', roles: [req.headers['x-test-role'] || 'GURU'] };
    next();
  };
  delete require.cache[require.resolve('../src/routes/guru.routes')];
  const app = express();
  app.use(express.json());
  app.use('/guru', require('../src/routes/guru.routes'));
  app.use((error, req, res, next) => res.status(error.status || 500).json({ error: { code: error.code } }));
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/guru`;
});
after(async () => {
  for (const r of restore) r.controller[r.method] = r.handler;
  if (server) {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
  }
  await sequelize.close();
});
for (const [method, path, module, handler] of mappings) {
  test(`${method} ${path} reaches the Guru controller`, async () => {
    const response = await fetch(base + path, { method, headers: { 'x-test-kind': 'guru' } });
    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.handler, `${module}.${handler}`);
    if (path === '/presensi/rekap/siswa/42') assert.equal(payload.params.id, '42');
  });
}
test('Guru profile and corrections reject anonymous, Student, Parent, web and Headmaster requests', async () => {
  for (const path of ['/profil', '/presensi/sesi/1/koreksi']) {
    const method = path.includes('koreksi') ? 'POST' : 'GET';
    for (const [headers, expected] of [
      [{}, 401],
      [{ 'x-test-kind': 'siswa' }, 403],
      [{ 'x-test-kind': 'orang_tua' }, 403],
      [{ 'x-test-kind': 'guru', 'x-test-platform': 'web' }, 403],
      [{ 'x-test-kind': 'guru', 'x-test-role': 'KEPALA_SEKOLAH' }, 403],
    ]) {
      assert.equal((await fetch(base + path, { method, headers })).status, expected);
    }
  }
});
