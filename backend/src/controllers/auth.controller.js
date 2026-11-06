const {
  Op
} = require('sequelize');
const {
  models
} = require('../models');
const {
  verifyPassword,
  issueToken,
  readToken,
  stamp
} = require('../utils/security');
const fail = require('../utils/api-error');
const attempts = new Map();
const today = () => new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Jakarta',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit'
}).format(new Date());
async function roles(user) {
  if (user.kind !== 'guru') return [];
  const rows = await models.guru_peran.findAll({
    where: {
      id_guru: user.id,
      tanggal_mulai: {
        [Op.lte]: today()
      },
      [Op.or]: [{
        tanggal_selesai: null
      }, {
        tanggal_selesai: {
          [Op.gte]: today()
        }
      }]
    },
    include: [{
      model: models.peran,
      as: 'peran'
    }]
  });
  return rows.map(r => r.peran.kode);
}
function publicUser(kind, user, rs) {
  return {
    id: user.id,
    kind,
    name: user.nama,
    identitas_login: user.identitas_login,
    roles: rs,
    role: rs.includes('ADMIN') ? 'admin' : kind,
    roleLabel: rs.includes('ADMIN') ? 'Administrator' : kind
  };
}
exports.login = async (req, res) => {
  const identity = typeof req.body?.identitas_akun === 'string' ? req.body.identitas_akun.trim().toLowerCase() : '';
  const password = req.body?.kata_sandi;
  if (!identity || identity.length > 191 || typeof password !== 'string' || !password || password.length > 128) throw fail(422, 'VALIDATION_ERROR', 'Identitas akun dan kata sandi wajib diisi.');
  const now = Date.now();
  for (const [k, v] of attempts) if (v.until < now) attempts.delete(k);
  const keys = [`ip:${req.ip}`, `account:${identity}`];
  if (keys.some(k => (attempts.get(k)?.count || 0) >= 10)) throw fail(429, 'TOO_MANY_ATTEMPTS', 'Terlalu banyak percobaan. Coba lagi dalam 15 menit.');
  for (const k of keys) {
    const v = attempts.get(k) || {
      count: 0,
      until: now + 900000
    };
    v.count++;
    attempts.set(k, v);
  }
  let found = null;
  for (const kind of ['guru', 'siswa', 'orang_tua']) {
    const u = await models[kind].unscoped().findOne({
      where: {
        identitas_login: identity
      }
    });
    if (u) {
      if (found) throw fail(409, 'ACCOUNT_CONFLICT', 'Identitas akun bentrok. Hubungi Admin.');
      found = {
        kind,
        u
      };
    }
  }
  // Same KDF work for unknown accounts to avoid a fast account-existence signal.
  const dummy = 'scrypt$00000000000000000000000000000000$' + '0'.repeat(128);
  const valid = await verifyPassword(password, found?.u.hash_kata_sandi || dummy);
  if (!found || !valid || found.u.status_akun !== 'AKTIF') throw fail(401, 'INVALID_CREDENTIALS', 'Identitas akun atau kata sandi tidak sesuai, atau akun tidak aktif.');
  attempts.delete(`account:${identity}`);
  const rs = await roles({
    kind: found.kind,
    id: found.u.id
  });
  res.json({
    data: {
      access_token: issueToken(found.kind, found.u),
      expires_in: 900,
      user: publicUser(found.kind, found.u, rs)
    }
  });
};
exports.authenticate = async (req, res, next) => {
  const bearer = req.get('Authorization');
  const data = readToken(bearer?.startsWith('Bearer ') ? bearer.slice(7) : '');
  if (!data) throw fail(401, 'UNAUTHENTICATED', 'Sesi berakhir. Silakan masuk kembali.');
  const u = await models[data.kind].unscoped().findByPk(data.id);
  if (!u || u.status_akun !== 'AKTIF' || stamp(u.hash_kata_sandi) !== data.stamp) throw fail(401, 'UNAUTHENTICATED', 'Sesi tidak berlaku. Silakan masuk kembali.');
  req.user = publicUser(data.kind, u, await roles({
    kind: data.kind,
    id: u.id
  }));
  next();
};
exports.requireAdmin = (req, res, next) => {
  if (!req.user.roles.includes('ADMIN')) throw fail(403, 'FORBIDDEN', 'Fitur ini hanya dapat diakses Admin aktif.');
  next();
};
exports.me = (req, res) => res.json({
  data: req.user
});
exports.today = today;
