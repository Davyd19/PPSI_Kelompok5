const {
  randomBytes,
  scrypt,
  timingSafeEqual,
  createHmac
} = require('node:crypto');
const {
  promisify
} = require('node:util');
const derive = promisify(scrypt);
function secret() {
  const s = process.env.AUTH_SECRET;
  if (!s || s.length < 32) throw Object.assign(new Error('Konfigurasi autentikasi belum lengkap.'), {
    status: 503,
    code: 'AUTH_NOT_CONFIGURED'
  });
  return s;
}
async function hashPassword(value) {
  if (typeof value !== 'string' || value.length < 10 || value.length > 128) throw Object.assign(new Error('Kata sandi harus 10–128 karakter.'), {
    status: 422,
    code: 'VALIDATION_ERROR'
  });
  const salt = randomBytes(16).toString('hex');
  const hash = await derive(value, salt, 64, {
    N: 32768,
    r: 8,
    p: 1,
    maxmem: 64 * 1024 * 1024
  });
  return `scrypt$${salt}$${hash.toString('hex')}`;
}
async function verifyPassword(value, encoded) {
  try {
    const [method, salt, h] = encoded.split('$');
    if (method !== 'scrypt' || !salt || h.length !== 128) return false;
    const expected = Buffer.from(h, 'hex');
    const actual = await derive(value, salt, 64, {
      N: 32768,
      r: 8,
      p: 1,
      maxmem: 64 * 1024 * 1024
    });
    return timingSafeEqual(actual, expected);
  } catch {
    return false;
  }
}
const sign = v => createHmac('sha256', secret()).update(v).digest('base64url');
const stamp = hash => sign('password:' + hash);
function issueToken(kind, user, now = Date.now(), sid) {
  const payload = Buffer.from(JSON.stringify({
    kind,
    id: user.id,
    stamp: stamp(user.hash_kata_sandi),
    exp: Math.floor(now / 1000) + 900,
    aud: 'sim-kesiswaan',
    ...(sid ? { sid } : {})
  })).toString('base64url');
  return `${payload}.${sign(payload)}`;
}
function readToken(token, now = Date.now()) {
  try {
    const [p, s, ...rest] = token.split('.');
    if (rest.length || !p || !s || s.length !== 43 || !timingSafeEqual(Buffer.from(s), Buffer.from(sign(p)))) return null;
    const data = JSON.parse(Buffer.from(p, 'base64url'));
    if (data.aud !== 'sim-kesiswaan' || !['guru', 'siswa', 'orang_tua'].includes(data.kind) || !Number.isSafeInteger(data.id) || data.id < 1 || !Number.isInteger(data.exp) || data.exp <= now / 1000) return null;
    return data;
  } catch {
    return null;
  }
}
module.exports = {
  hashPassword,
  verifyPassword,
  issueToken,
  readToken,
  stamp
};
