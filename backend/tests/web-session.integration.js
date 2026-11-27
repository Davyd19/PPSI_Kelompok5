const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { sequelize } = require('../src/models');
const { Session } = require('../src/models/auth-session');
const { readToken } = require('../src/utils/security');
let server, base;
const ids = [];
before(async () => {
  if (!/_qa$/.test(process.env.DB_NAME || '')) throw new Error('Use a separate *_qa database.');
  server = require('../src/app').listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api/v1`;
});
after(async () => {
  if (/_qa$/.test(process.env.DB_NAME || '') && ids.length) await Session.update({ dicabut: new Date() }, { where: { id: ids } });
  if (server) await new Promise(resolve => server.close(resolve));
  await sequelize.close();
});
async function request(path, token, body) {
  const response = await fetch(base + path, { method: body ? 'POST' : 'GET', headers: {
    ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body ? { 'Content-Type': 'application/json' } : {})
  }, ...(body ? { body: JSON.stringify(body) } : {}) });
  return { status: response.status, data: response.status === 204 ? null : await response.json() };
}
async function login(identity, platform) {
  const result = await request('/auth/login', null, { identitas_akun: identity, kata_sandi: 'Contoh123!', platform });
  assert.equal(result.status, 200);
  ids.push(readToken(result.data.data.access_token).sid);
  return result.data.data;
}
test('web renewal extends server deadline; expired and revoked sessions cannot revive; mobile is unchanged', async () => {
  const web = await login('contoh.admin', 'web');
  assert.equal(web.expires_in, 1800);
  assert.equal(web.refresh_token, undefined);
  const sid = readToken(web.access_token).sid;
  await Session.update({ kedaluwarsa: new Date(Date.now() + 60000) }, { where: { id: sid } });
  const renewal = await request('/auth/keep-alive', web.access_token, {});
  assert.equal(renewal.status, 200);
  assert.equal(renewal.data.data.expires_in, 1800);
  assert.ok((await Session.findByPk(sid)).kedaluwarsa > new Date(Date.now() + 29 * 60000));
  const token = renewal.data.data.access_token;
  assert.equal((await request('/auth/me', token)).status, 200);
  await Session.update({ kedaluwarsa: new Date(Date.now() - 1000) }, { where: { id: sid } });
  assert.equal((await request('/auth/keep-alive', token, {})).status, 401);
  const again = await login('contoh.admin', 'web');
  assert.equal((await request('/auth/logout', again.access_token, {})).status, 204);
  assert.equal((await request('/auth/keep-alive', again.access_token, {})).status, 401);
  const mobile = await login('contoh.siswa', 'mobile');
  assert.equal(mobile.expires_in, 900);
  assert.ok(mobile.refresh_token);
  assert.equal((await request('/auth/keep-alive', mobile.access_token, {})).status, 403);
  assert.equal((await request('/auth/refresh', null, { refresh_token: mobile.refresh_token })).status, 200);
  assert.equal((await request('/auth/keep-alive', null, {})).status, 401);
});
