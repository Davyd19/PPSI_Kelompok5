const audit = require('../utils/audit');
const { revokeAccountSessions } = require('../models/auth-session');
const {
  Op
} = require('sequelize');
const {
  sequelize,
  models,
  schema
} = require('../models');
const {
  editable,
  clean,
  validate,
  invalid
} = require('../validators/admin.validation');
const {
  hashPassword
} = require('../utils/security');
const {
  today
} = require('./auth.controller');
const fail = require('../utils/api-error');
const accounts = ['guru', 'siswa', 'orang_tua'];
function resource(req) {
  const key = req.params.resource;
  if (!editable.includes(key) && key !== 'peran') throw fail(404, 'NOT_FOUND', 'Data tidak ditemukan.');
  return key;
}
const pageParams = req => {
  const page = Number(req.query.page || 1),
    limit = Number(req.query.limit || 10);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(limit) || limit < 1 || limit > 100) throw invalid('Pagination tidak sah.');
  return {
    page,
    limit
  };
};
const publicFields = key => ['id', ...schema[key].fields.filter(f => !f.private).map(f => f.name)];
function whereFor(key, req) {
  const where = {};
  const q = String(req.query.q || '').trim().slice(0, 100);
  if (q) {
    const fields = schema[key].fields.filter(f => f.type === 'string' && !f.private && !f.options).map(f => f.name);
    if (fields.length) where[Op.or] = fields.map(f => ({
      [f]: {
        [Op.like]: `%${q.replace(/[\\%_]/g, '\\$&')}%`
      }
    }));
  }
  for (const f of schema[key].fields) if ((f.ref || f.options) && req.query[f.name]) {
    const v = req.query[f.name];
    if (f.ref && !/^\d+$/.test(v)) throw invalid('Filter tidak sah.');
    where[f.name] = v;
  }
  return where;
}
function includes(key) {
  return schema[key].fields.filter(f => f.ref).map(f => ({
    model: models[f.ref],
    as: f.name.slice(3),
    attributes: ['id', ...(schema[f.ref].fields.some(x => x.name === 'nama') ? ['nama'] : schema[f.ref].fields.some(x => x.name === 'judul') ? ['judul'] : [])]
  }));
}
exports.metadata = (req, res) => res.json({
  data: Object.fromEntries([...editable, 'peran'].map(k => [k, {
    ...schema[k],
    fields: schema[k].fields.filter(f => !f.private),
    readOnly: k === 'peran'
  }]))
});
exports.list = async (req, res) => {
  const key = resource(req),
    {
      page,
      limit
    } = pageParams(req);
  const result = await models[key].findAndCountAll({
    where: whereFor(key, req),
    attributes: publicFields(key),
    include: includes(key),
    order: [['id', 'DESC']],
    limit,
    offset: (page - 1) * limit
  });
  res.json({
    data: result.rows,
    meta: {
      page,
      limit,
      total: result.count,
      totalPages: Math.ceil(result.count / limit)
    }
  });
};
exports.detail = async (req, res) => {
  const k = resource(req);
  const row = await models[k].findByPk(req.params.id, {
    attributes: publicFields(k),
    include: includes(k)
  });
  if (!row) throw fail(404, 'NOT_FOUND', 'Data tidak ditemukan.');
  res.json({
    data: row
  });
};
exports.lookup = async (req, res) => {
  const key = resource(req);
  const {
    page,
    limit
  } = pageParams(req);
  const result = await models[key].findAndCountAll({
    where: whereFor(key, req),
    attributes: publicFields(key),
    include: includes(key),
    order: [['id', 'DESC']],
    limit,
    offset: (page - 1) * limit
  });
  res.json({
    data: result.rows.map(r => ({
      id: r.id,
      label: lookupLabel(key, r),
      ...(r.id_tahun_ajaran ? {
        id_tahun_ajaran: r.id_tahun_ajaran
      } : {})
    })),
    meta: {
      page,
      limit,
      total: result.count
    }
  });
};
function lookupLabel(key, r) {
  if (key === 'periode_ekskul') return `${r.ekstrakurikuler?.nama} · ${r.tahun_ajaran?.nama}`;
  if (key === 'versi_badge') return `${r.badge?.nama} · Versi ${r.nomor_versi}`;
  if (['kelas', 'semester'].includes(key)) return `${r.nama} · ${r.tahun_ajaran?.nama}`;
  return r.nama || r.judul || `${schema[key].label} #${r.id}`;
}
exports.summary = async (req, res) => {
  const counts = {};
  for (const k of ['guru', 'siswa', 'orang_tua', 'kelas', 'ekskul', 'badge']) counts[k] = await models[k].count();
  res.json({
    data: {
      counts,
      schoolYear: await models.tahun.findOne({
        where: {
          aktif: true
        }
      })
    }
  });
};
exports.accounts = async (req, res) => {
  const {
    page,
    limit
  } = pageParams(req);
  const kinds = req.query.kind ? [req.query.kind] : accounts;
  if (kinds.some(k => !accounts.includes(k))) throw invalid('Jenis akun tidak sah.');
  const search = String(req.query.q || '').trim().slice(0, 100);
  const replacements = {
    q: `%${search.replace(/[\\%_]/g, '\\$&')}%`,
    limit,
    offset: (page - 1) * limit
  };
  const union = kinds.map(k => `SELECT id,nama,identitas_login,status_akun,'${k}' AS kind FROM ${schema[k].table} WHERE (nama LIKE :q OR identitas_login LIKE :q)`).join(' UNION ALL ');
  const [rows] = await sequelize.query(`SELECT * FROM (${union}) accounts ORDER BY nama,kind,id LIMIT :limit OFFSET :offset`, {
    replacements
  });
  const [[count]] = await sequelize.query(`SELECT COUNT(*) total FROM (${union}) accounts`, {
    replacements
  });
  res.json({
    data: rows,
    meta: {
      page,
      limit,
      total: Number(count.total),
      totalPages: Math.ceil(count.total / limit)
    }
  });
};
async function activateYear(req, id, t) {
  const rows = await models.tahun.findAll({
    where: {
      aktif: true,
      ...(id ? {
        id: {
          [Op.ne]: id
        }
      } : {})
    },
    transaction: t,
    lock: t.LOCK.UPDATE
  });
  for (const row of rows) {
    const before = row.toJSON();
    await row.update({
      aktif: false
    }, {
      transaction: t
    });
    await audit(req, 'tahun', row.id, before, row.toJSON(), 'NONAKTIFKAN_TAHUN_LAMA', t);
  }
}
async function lock(t) {
  const role = await models.peran.findOne({
    where: {
      kode: 'ADMIN'
    },
    transaction: t,
    lock: t.LOCK.UPDATE
  });
  if (!role) throw fail(503, 'SETUP_REQUIRED', 'Seed peran Admin belum dijalankan.');
}
async function protectLastAdmin(t) {
  const rs = await models.guru_peran.findAll({
    where: {
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
      as: 'peran',
      where: {
        kode: 'ADMIN'
      }
    }, {
      model: models.guru,
      as: 'guru',
      where: {
        status_akun: 'AKTIF'
      }
    }],
    transaction: t
  });
  if (!rs.length) throw fail(409, 'LAST_ADMIN', 'Minimal satu Admin aktif harus tetap tersedia.');
}
async function badgeLocked(key, data, id, t, body) {
  if (!['versi_badge', 'level'].includes(key)) return;
  const vid = key === 'versi_badge' ? id : data.id_versi_aturan_badge;
  if (!vid) return;
  const v = await models.versi_badge.findByPk(vid, {
    transaction: t
  });
  const semester = await models.semester.findByPk(v.id_semester_mulai, {
    transaction: t
  });
  const used = await models.pencapaian.count({
    include: [{
      model: models.level,
      as: 'level_badge',
      where: {
        id_versi_aturan_badge: vid
      }
    }],
    transaction: t
  });
  if (used || semester.tanggal_mulai <= today()) {
    // Only close the applicability range of an old version; its scoring fields stay immutable.
    if (key === 'versi_badge' && body && Object.keys(body).every(k => k === 'id_semester_selesai') && body.id_semester_selesai) {
      const end = await models.semester.findByPk(body.id_semester_selesai, {
        transaction: t
      });
      if (end && end.tanggal_selesai >= today()) return;
    }
    throw fail(409, 'IMMUTABLE_BADGE_VERSION', 'Versi yang berlaku/sudah digunakan tidak dapat diubah. Buat versi pada semester berikutnya.');
  }
}
exports.create = async (req, res) => {
  const key = resource(req);
  if (key === 'peran') throw fail(403, 'FIXED_ROLES', 'Peran sistem bersifat tetap.');
  const data = clean(key, req.body, true);
  if (accounts.includes(key)) data.hash_kata_sandi = await hashPassword(req.body.kata_sandi);
  const row = await sequelize.transaction(async t => {
    await lock(t);
    await validate(key, data, null, t);
    await badgeLocked(key, data, null, t, req.body);
    if (key === 'tahun' && data.aktif) await activateYear(req, null, t);
    const row = await models[key].create(data, {
      transaction: t
    });
    await audit(req, key, row.id, null, data, 'TAMBAH', t);
    return row;
  });
  const safe = row.toJSON();
  delete safe.hash_kata_sandi;
  res.status(201).json({
    data: safe
  });
};
async function usedData(key, id, t) {
  for (const [k, spec] of Object.entries(schema)) for (const f of spec.fields.filter(f => f.ref === key)) if (await models[k].count({
    where: {
      [f.name]: id
    },
    transaction: t
  })) return true;
  return false;
}
exports.update = async (req, res) => {
  const key = resource(req);
  if (key === 'peran') throw fail(403, 'FIXED_ROLES', 'Peran sistem bersifat tetap.');
  const patch = clean(key, req.body, false);
  if (req.body.kata_sandi) throw invalid('Gunakan tindakan reset kata sandi.');
  const row = await sequelize.transaction(async t => {
    await lock(t);
    const row = await models[key].unscoped().findByPk(req.params.id, {
      transaction: t,
      lock: t.LOCK.UPDATE
    });
    if (!row) throw fail(404, 'NOT_FOUND', 'Data tidak ditemukan.');
    const before = row.toJSON(),
      data = {
        ...before,
        ...patch
      };
    await validate(key, data, row.id, t);
    await badgeLocked(key, data, row.id, t, req.body);
    if (key === 'level' && patch.id_versi_aturan_badge !== undefined && patch.id_versi_aturan_badge !== before.id_versi_aturan_badge) await badgeLocked(key, before, row.id, t, req.body);
    if (['hubungan', 'wali', 'pembina', 'guru_peran', 'riwayat_kelas'].includes(key) && before.tanggal_mulai <= today()) {
      const immutable = Object.keys(before).filter(k => !['tanggal_selesai'].includes(k));
      if (immutable.some(k => k in patch && String(patch[k]) !== String(before[k]))) throw fail(409, 'HISTORY_PROTECTED', 'Data yang sudah berlaku tidak ditimpa. Akhiri masa berlaku lalu buat penugasan/hubungan baru.');
    }
    if (['kelas', 'semester', 'periode_ekskul'].includes(key) && (await usedData(key, row.id, t))) {
      for (const f of schema[key].fields.filter(f => f.ref)) if (f.name in patch && patch[f.name] !== before[f.name]) throw fail(409, 'HISTORY_PROTECTED', 'Konteks data yang telah dirujuk tidak dapat dipindah.');
    }
    if (key === 'tahun' && patch.aktif) await activateYear(req, row.id, t);
    await row.update(patch, {
      transaction: t
    });
    if (accounts.includes(key) && before.status_akun === 'AKTIF' && row.status_akun !== 'AKTIF') await revokeAccountSessions(key, row.id, t);
    await protectLastAdmin(t);
    await audit(req, key, row.id, before, row.toJSON(), 'UBAH', t);
    return row;
  });
  const safe = row.toJSON();
  delete safe.hash_kata_sandi;
  res.json({
    data: safe
  });
};
exports.remove = async (req, res) => {
  const key = resource(req);
  if (key === 'peran') throw fail(403, 'FIXED_ROLES', 'Peran sistem bersifat tetap.');
  await sequelize.transaction(async t => {
    await lock(t);
    const row = await models[key].findByPk(req.params.id, {
      transaction: t,
      lock: t.LOCK.UPDATE
    });
    if (!row) throw fail(404, 'NOT_FOUND', 'Data tidak ditemukan.');
    if (['hubungan', 'wali', 'pembina', 'guru_peran', 'riwayat_kelas'].includes(key) && row.tanggal_mulai <= today()) throw fail(409, 'HISTORY_PROTECTED', 'Data yang telah berlaku tidak boleh dihapus. Akhiri masa berlakunya.');
    await badgeLocked(key, row.toJSON(), row.id, t, null);
    if (await usedData(key, row.id, t)) throw fail(409, 'DATA_IN_USE', 'Data telah dirujuk dan tidak dapat dihapus. Gunakan status atau pengakhiran masa berlaku.');
    await row.destroy({
      transaction: t
    });
    await protectLastAdmin(t);
    await audit(req, key, row.id, row.toJSON(), null, 'HAPUS', t);
  });
  res.json({
    data: {
      deleted: true
    }
  });
};
exports.resetPassword = async (req, res) => {
  const kind = req.params.kind;
  if (!accounts.includes(kind)) throw fail(404, 'NOT_FOUND', 'Akun tidak ditemukan.');
  const hash = await hashPassword(req.body?.kata_sandi);
  await sequelize.transaction(async t => {
    await lock(t);
    const u = await models[kind].findByPk(req.params.id, {
      transaction: t,
      lock: t.LOCK.UPDATE
    });
    if (!u) throw fail(404, 'NOT_FOUND', 'Akun tidak ditemukan.');
    await u.update({
      hash_kata_sandi: hash
    }, {
      transaction: t
    });
    await revokeAccountSessions(kind, u.id, t);
    await audit(req, kind, u.id, null, null, 'RESET_KATA_SANDI', t);
  });
  res.json({
    data: {
      reset: true
    }
  });
};
exports.replace = async (req, res) => {
  const key = resource(req);
  if (!['riwayat_kelas', 'wali', 'pembina'].includes(key)) throw fail(404, 'NOT_FOUND', 'Tindakan tidak tersedia.');
  const field = key === 'riwayat_kelas' ? 'id_kelas' : 'id_guru';
  if (Object.keys(req.body || {}).some(k => ![field, 'tanggal_mulai'].includes(k))) throw invalid('Atribut pergantian tidak sah.');
  const result = await sequelize.transaction(async t => {
    await lock(t);
    const old = await models[key].findByPk(req.params.id, {
      transaction: t,
      lock: t.LOCK.UPDATE
    });
    if (!old) throw fail(404, 'NOT_FOUND', 'Data tidak ditemukan.');
    const before = old.toJSON();
    const next = clean(key, {
      ...Object.fromEntries(schema[key].fields.map(f => [f.name, before[f.name]])),
      [field]: req.body[field],
      tanggal_mulai: req.body.tanggal_mulai,
      tanggal_selesai: null
    }, true);
    if (next[field] === before[field]) throw invalid('Pilih kelas/guru pengganti yang berbeda.');
    if (next.tanggal_mulai <= before.tanggal_mulai || before.tanggal_selesai && next.tanggal_mulai > before.tanggal_selesai) throw invalid('Tanggal pergantian harus sesudah awal dan masih dalam masa penugasan/keanggotaan lama.');
    const end = new Date(`${next.tanggal_mulai}T00:00:00Z`);
    end.setUTCDate(end.getUTCDate() - 1);
    await old.update({
      tanggal_selesai: end.toISOString().slice(0, 10)
    }, {
      transaction: t
    });
    await validate(key, next, null, t);
    const row = await models[key].create(next, {
      transaction: t
    });
    await audit(req, key, old.id, before, old.toJSON(), 'AKHIRI_UNTUK_PERGANTIAN', t);
    await audit(req, key, row.id, null, next, 'PERGANTIAN', t);
    return row;
  });
  res.status(201).json({
    data: result
  });
};
