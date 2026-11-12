const { createHash, randomBytes, randomUUID } = require('node:crypto');
const { sequelize, models } = require('../models');
const { Session, RefreshToken } = require('../models/auth-session');
const { issueToken, stamp, readToken } = require('../utils/security');
const fail = require('../utils/api-error');

const DAY = 86400000;
const digest = value => createHash('sha256').update(value).digest('hex');
const unauthorized = () => fail(401, 'UNAUTHENTICATED', 'Sesi berakhir. Silakan masuk kembali.');
const tokenInput = req => req.body?.refresh_token;
const validInput = token => typeof token === 'string' && /^[A-Za-z0-9_-]{43}$/.test(token);

async function addRefreshToken(session, transaction) {
  const token = randomBytes(32).toString('base64url');
  await RefreshToken.create({ hash: digest(token), id_sesi: session.id }, { transaction });
  return token;
}

async function createSession(kind, user, platform) {
  return sequelize.transaction(async transaction => {
    const current = await models[kind].unscoped().findByPk(user.id, { transaction, lock: transaction.LOCK.UPDATE });
    if (!current || current.status_akun !== 'AKTIF' || current.hash_kata_sandi !== user.hash_kata_sandi) throw unauthorized();
    const session = await Session.create({
      id: randomUUID(), jenis_akun: kind, id_akun: user.id, platform,
      sidik_sandi: stamp(user.hash_kata_sandi),
      kedaluwarsa: new Date(Date.now() + (platform === 'mobile' ? 30 * DAY : 900000))
    }, { transaction });
    return {
      access_token: issueToken(kind, user, Date.now(), session.id),
      ...(platform === 'mobile' ? { refresh_token: await addRefreshToken(session, transaction) } : {})
    };
  });
}

async function refresh(req, res) {
  const token = tokenInput(req);
  if (!validInput(token)) throw unauthorized();
  const hash = digest(token);
  const reference = await RefreshToken.findByPk(hash);
  if (!reference) throw unauthorized();

  const result = await sequelize.transaction(async transaction => {
    // Lock the account first, in the same order as password reset and login.
    const candidate = await Session.findByPk(reference.id_sesi, { transaction });
    if (!candidate) return null;
    const user = await models[candidate.jenis_akun].unscoped().findByPk(candidate.id_akun, {
      transaction, lock: transaction.LOCK.UPDATE
    });
    const session = await Session.findByPk(candidate.id, { transaction, lock: transaction.LOCK.UPDATE });
    if (!session || session.dicabut || session.kedaluwarsa <= new Date() || session.platform !== 'mobile') return null;
    const stored = await RefreshToken.findByPk(hash, { transaction, lock: transaction.LOCK.UPDATE });
    if (!stored) return null;
    if (stored.dipakai || !user || user.status_akun !== 'AKTIF' || stamp(user.hash_kata_sandi) !== session.sidik_sandi) {
      await session.update({ dicabut: new Date() }, { transaction });
      return null;
    }
    await stored.update({ dipakai: new Date() }, { transaction });
    return {
      access_token: issueToken(session.jenis_akun, user, Date.now(), session.id),
      refresh_token: await addRefreshToken(session, transaction),
      expires_in: 900
    };
  });
  if (!result) throw unauthorized();
  res.set('Cache-Control', 'no-store').json({ data: result });
}

async function logout(req, res) {
  const bearer = req.get('Authorization');
  const access = readToken(bearer?.startsWith('Bearer ') ? bearer.slice(7) : '');
  const token = tokenInput(req);
  const stored = validInput(token) ? await RefreshToken.findByPk(digest(token)) : null;
  const id = stored?.id_sesi || access?.sid;
  if (id) await Session.update({ dicabut: new Date() }, { where: { id, dicabut: null } });
  res.status(204).end();
}

module.exports = { createSession, refresh, logout };
