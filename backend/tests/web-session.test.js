const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
process.env.AUTH_SECRET ||= randomBytes(48).toString('hex');
const { issueToken, readToken } = require('../src/utils/security');
const { Session } = require('../src/models/auth-session');
const { keepAlive } = require('../src/controllers/auth-session.controller');
const account = { id: 7, hash_kata_sandi: 'test-hash-only' };
test('mobile default expiry stays fifteen minutes; web expiry is thirty minutes', () => {
  const now = Date.now();
  assert.ok(readToken(issueToken('guru', account, now, 'web', 1800), now + 16 * 60000));
  assert.equal(readToken(issueToken('guru', account, now, 'web', 1800), now + 30 * 60000), null);
  assert.equal(readToken(issueToken('guru', account, now, 'mobile'), now + 15 * 60000), null);
});
test('keep-alive extends only an unrevoked, unexpired web session and signs a renewed token', async () => {
  const original = Session.update;
  let query, response;
  Session.update = async (values, options) => { query = { values, options }; return [1]; };
  try {
    await keepAlive({ authSession: { id: 'session', platform: 'web', jenis_akun: 'guru' }, authAccount: account },
      { set: () => ({ json: body => { response = body.data; } }) });
    assert.equal(response.expires_in, 1800);
    assert.equal(readToken(response.access_token).id, account.id);
    assert.equal(query.options.where.dicabut, null);
    assert.ok(query.options.where.kedaluwarsa[require('sequelize').Op.gt] instanceof Date);
    assert.ok(query.values.kedaluwarsa > new Date(Date.now() + 29 * 60000));
  } finally { Session.update = original; }
});
test('keep-alive rejects mobile and sessions revoked while request is in progress', async () => {
  await assert.rejects(() => keepAlive({ authSession: { platform: 'mobile' } }, {}), error => error.status === 403);
  const original = Session.update;
  Session.update = async () => [0];
  try {
    await assert.rejects(() => keepAlive({ authSession: { id: 'revoked', platform: 'web' }, authAccount: account }, {}), error => error.status === 401);
  } finally { Session.update = original; }
});
