const {
  Op,
  QueryTypes
} = require('sequelize');
const {
  models,
  schema,
  sequelize
} = require('../models');
const {
  clean,
  validate,
  invalid
} = require('../validators/admin.validation');
const {
  hashPassword
} = require('../utils/security');
const audit = require('../utils/audit');
const fail = require('../utils/api-error');
const {
  today
} = require('./auth.controller');
const {
  lock,
  badgeLocked
} = require('./admin.controller').operations;
const safe = row => {
  const data = row.toJSON ? row.toJSON() : row;
  const {
    hash_kata_sandi,
    hash_token_qr,
    ...rest
  } = data;
  return rest;
};
const identifier = value => {
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n < 1) throw invalid('Identitas data tidak sah.');
  return n;
};
const joins = key => schema[key].fields.filter(f => f.ref).map(f => ({
  ...(f.ref === 'periode_ekskul' ? {
    include: [{
      model: models.ekskul,
      as: 'ekstrakurikuler',
      attributes: ['id', 'nama']
    }, {
      model: models.tahun,
      as: 'tahun_ajaran',
      attributes: ['id', 'nama']
    }]
  } : {}),
  model: models[f.ref],
  as: f.name.slice(3),
  attributes: ['id', ...schema[f.ref].fields.filter(x => ['nama', 'identitas_login', 'tanggal_mulai', 'tanggal_selesai', 'nomor_versi', 'id_tahun_ajaran', 'id_ekstrakurikuler'].includes(x.name)).map(x => x.name)]
}));
const groups = {
  siswa: [['riwayat_kelas', 'Kelas & riwayat', 'id_siswa'], ['hubungan', 'Orang tua', 'id_siswa']],
  orang_tua: [['hubungan', 'Anak terhubung', 'id_orang_tua']],
  guru: [['wali', 'Wali kelas', 'id_guru'], ['pembina', 'Pembina ekstrakurikuler', 'id_guru']],
  kelas: [['riwayat_kelas', 'Anggota kelas', 'id_kelas'], ['wali', 'Wali kelas', 'id_kelas']],
  ekskul: [['periode_ekskul', 'Periode kegiatan', 'id_ekstrakurikuler']],
  periode_ekskul: [['pembina', 'Pembina kegiatan', 'id_periode_ekstrakurikuler']],
  badge: [['versi_badge', 'Versi aturan', 'id_badge']],
  versi_badge: [['level', 'Level & syarat', 'id_versi_aturan_badge']]
};
exports.catalog = (req, res) => res.json({
  data: require('../utils/badge-catalog')
});
exports.workspace = async (req, res) => {
  const key = req.params.resource;
  if (!groups[key]) throw fail(404, 'NOT_FOUND', 'Detail tidak tersedia.');
  const row = await models[key].findByPk(identifier(req.params.id), {
    include: joins(key)
  });
  if (!row) throw fail(404, 'NOT_FOUND', 'Data tidak ditemukan.');
  const relations = [];
  for (const [resource, label, field] of groups[key]) {
    const where = {
      [field]: row.id
    };
    if (req.query.at && ['wali', 'riwayat_kelas', 'pembina'].includes(resource)) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(req.query.at)) throw invalid('Tanggal konteks tidak sah.');
      where.tanggal_mulai = {
        [Op.lte]: req.query.at
      };
      where[Op.or] = [{
        tanggal_selesai: null
      }, {
        tanggal_selesai: {
          [Op.gte]: req.query.at
        }
      }];
    }
    const page = req.query.group === resource ? identifier(req.query.page || 1) : 1;
    const result = await models[resource].findAndCountAll({
      where,
      include: joins(resource),
      order: [['id', 'DESC']],
      limit: 20,
      offset: (page - 1) * 20
    });
    relations.push({
      resource,
      label,
      field,
      rows: result.rows.map(safe),
      page,
      total: result.count,
      totalPages: Math.ceil(result.count / 20)
    });
  }
  let locked = false;
  if (key === 'versi_badge') {
    const semester = await models.semester.findByPk(row.id_semester_mulai);
    locked = semester.tanggal_mulai <= today() || (await models.pencapaian.count({
      include: [{
        model: models.level,
        as: 'level_badge',
        where: {
          id_versi_aturan_badge: row.id
        }
      }]
    })) > 0;
  }
  res.json({
    data: {
      resource: key,
      row: safe(row),
      relations,
      locked
    }
  });
};
async function insert(req, key, body, t, atomicLevel = false) {
  const data = clean(key, body, true);
  if (['guru', 'siswa', 'orang_tua'].includes(key)) data.hash_kata_sandi = await hashPassword(body.kata_sandi);
  await validate(key, data, null, t);
  if (!atomicLevel) await badgeLocked(key, data, null, t, body);
  const row = await models[key].create(data, {
    transaction: t
  });
  await audit(req, key, row.id, null, data, 'TAMBAH', t);
  return row;
}
async function linkParent(req, studentId, input, t) {
  if (!(await models.siswa.findByPk(identifier(studentId), {
    transaction: t
  }))) throw invalid('Siswa tidak ditemukan.');
  if (Boolean(input.id_orang_tua) === Boolean(input.data)) throw invalid('Pilih orang tua yang ada atau isi akun baru.');
  const parent = input.id_orang_tua ? {
    id: identifier(input.id_orang_tua)
  } : await insert(req, 'orang_tua', input.data, t);
  return insert(req, 'hubungan', {
    id_siswa: Number(studentId),
    id_orang_tua: parent.id,
    jenis_hubungan: input.jenis_hubungan,
    tanggal_mulai: input.tanggal_mulai,
    tanggal_selesai: input.tanggal_selesai || null
  }, t);
}
exports.student = async (req, res) => {
  const result = await sequelize.transaction(async t => {
    await lock(t);
    const row = await insert(req, 'siswa', req.body.siswa, t);
    if (req.body.kelas) await insert(req, 'riwayat_kelas', {
      ...req.body.kelas,
      id_siswa: row.id,
      tanggal_selesai: null
    }, t);
    if (req.body.orang_tua) await linkParent(req, row.id, req.body.orang_tua, t);
    return safe(row);
  });
  res.status(201).json({
    data: result
  });
};
exports.parent = async (req, res) => {
  const row = await sequelize.transaction(async t => {
    await lock(t);
    return linkParent(req, req.body.id_siswa, req.body.orang_tua, t);
  });
  res.status(201).json({
    data: safe(row)
  });
};
exports.badge = async (req, res) => {
  const result = await sequelize.transaction(async t => {
    await lock(t);
    if (!Array.isArray(req.body.levels) || !req.body.levels.length || req.body.levels.length > 20) throw invalid('Isi 1–20 level badge.');
    const badge = req.body.id_badge ? await models.badge.findByPk(identifier(req.body.id_badge), {
      transaction: t,
      lock: t.LOCK.UPDATE
    }) : await insert(req, 'badge', req.body.badge, t);
    if (!badge) throw invalid('Badge tidak ditemukan.');
    const versionData = {
      ...req.body.versi,
      id_badge: badge.id
    };
    const start = await models.semester.findByPk(identifier(versionData.id_semester_mulai), {
      transaction: t
    });
    if (!start) throw invalid('Semester tidak ditemukan.');
    const previous = await models.versi_badge.findAll({
      where: {
        id_badge: badge.id
      },
      transaction: t,
      lock: t.LOCK.UPDATE
    });
    if (previous.length && start.tanggal_mulai <= today()) throw invalid('Versi baru mulai pada semester mendatang.');
    if (previous.length) {
      const ends = await models.semester.findAll({
        where: {
          tanggal_selesai: {
            [Op.lt]: start.tanggal_mulai
          }
        },
        order: [['tanggal_selesai', 'DESC']],
        transaction: t
      });
      const end = ends[0];
      for (const v of previous) {
        const vs = await models.semester.findByPk(v.id_semester_mulai, {
          transaction: t
        });
        const ve = v.id_semester_selesai ? await models.semester.findByPk(v.id_semester_selesai, {
          transaction: t
        }) : null;
        if (vs.tanggal_mulai >= start.tanggal_mulai) continue;
        if (!ve || ve.tanggal_selesai >= start.tanggal_mulai) {
          if (!end) throw invalid('Semester penutup versi sebelumnya tidak tersedia.');
          await badgeLocked('versi_badge', v.toJSON(), v.id, t, {
            id_semester_selesai: end.id
          });
          const before = v.toJSON();
          await v.update({
            id_semester_selesai: end.id
          }, {
            transaction: t
          });
          await audit(req, 'versi_badge', v.id, before, v.toJSON(), 'AKHIRI_VERSI', t);
        }
      }
    }
    const version = await insert(req, 'versi_badge', versionData, t);
    const levels = [];
    for (const [i, level] of req.body.levels.entries()) levels.push(safe(await insert(req, 'level', {
      ...level,
      urutan: i + 1,
      id_versi_aturan_badge: version.id
    }, t, true)));
    return {
      badge: safe(badge),
      versi: safe(version),
      levels
    };
  });
  res.status(201).json({
    data: result
  });
};
exports.overview = async (req, res) => {
  const year = req.query.id_tahun_ajaran ? await models.tahun.findByPk(identifier(req.query.id_tahun_ajaran)) : await models.tahun.findOne({
    where: {
      aktif: true
    }
  });
  if (req.query.id_tahun_ajaran && !year) throw invalid('Tahun ajaran tidak ditemukan.');
  const day = today(),
    yearId = year?.id ?? 0;
  const select = (sql, replacements = {}) => sequelize.query(sql, {
    type: QueryTypes.SELECT,
    replacements: {
      day,
      yearId,
      ...replacements
    }
  });
  const activeRoster = `r.tanggal_mulai<=:day AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=:day)`;
  const [counts, distribution, accounts, missingStudents, missingClasses, assignments, activity] = await Promise.all([Promise.all(['siswa', 'guru', 'kelas', 'ekskul'].map(key => models[key].count({
    where: key === 'siswa' ? {
      status_siswa: 'AKTIF'
    } : key === 'kelas' ? {
      id_tahun_ajaran: yearId
    } : {}
  }))).then(values => Object.fromEntries(['siswa', 'guru', 'kelas', 'ekskul'].map((key, i) => [key, values[i]]))), select(`SELECT c.id,c.nama,c.tingkat,COUNT(DISTINCT CASE WHEN ${activeRoster} AND s.status_siswa='AKTIF' THEN s.id END) AS total FROM kelas c LEFT JOIN riwayat_kelas_siswa r ON r.id_kelas=c.id LEFT JOIN siswa s ON s.id=r.id_siswa WHERE c.id_tahun_ajaran=:yearId GROUP BY c.id,c.nama,c.tingkat ORDER BY c.tingkat,c.nama`), select(`SELECT status_akun,COUNT(*) AS total FROM (SELECT status_akun FROM guru UNION ALL SELECT status_akun FROM siswa UNION ALL SELECT status_akun FROM orang_tua) a GROUP BY status_akun`), select(`SELECT s.id,s.nama FROM siswa s WHERE s.status_siswa='AKTIF' AND NOT EXISTS (SELECT 1 FROM riwayat_kelas_siswa r JOIN kelas c ON c.id=r.id_kelas WHERE r.id_siswa=s.id AND c.id_tahun_ajaran=:yearId AND ${activeRoster}) ORDER BY s.nama LIMIT 20`), select(`SELECT c.id,c.nama FROM kelas c WHERE c.id_tahun_ajaran=:yearId AND c.status='AKTIF' AND NOT EXISTS (SELECT 1 FROM penugasan_wali_kelas w WHERE w.id_kelas=c.id AND w.tanggal_mulai<=:day AND (w.tanggal_selesai IS NULL OR w.tanggal_selesai>=:day)) ORDER BY c.nama LIMIT 20`), select(`SELECT 'Wali kelas' AS label,COUNT(*) AS total FROM penugasan_wali_kelas w JOIN kelas c ON c.id=w.id_kelas WHERE c.id_tahun_ajaran=:yearId AND w.tanggal_mulai<=:day AND (w.tanggal_selesai IS NULL OR w.tanggal_selesai>=:day) UNION ALL SELECT 'Pembina ekskul',COUNT(*) FROM penugasan_pembina p JOIN periode_ekstrakurikuler e ON e.id=p.id_periode_ekstrakurikuler WHERE e.id_tahun_ajaran=:yearId AND p.tanggal_mulai<=:day AND (p.tanggal_selesai IS NULL OR p.tanggal_selesai>=:day)`), select(`SELECT a.id,a.jenis_tindakan,a.nama_tabel,a.identitas_data,a.waktu,g.nama AS pelaku FROM audit_perubahan a LEFT JOIN guru g ON g.id=a.id_guru WHERE a.id_guru IS NOT NULL ORDER BY a.waktu DESC,a.id DESC LIMIT 8`)]);
  res.json({
    data: {
      counts,
      schoolYear: year,
      distribution,
      accounts,
      missingStudents,
      missingClasses,
      assignments,
      activity
    }
  });
};
