const {
  test,
  before,
  after
} = require('node:test');
const assert = require('node:assert/strict');
const {
  sequelize,
  models
} = require('../src/models');
const {
  today
} = require('../src/controllers/auth.controller');
let server, base, token;
const suffix = require('node:crypto').randomBytes(4).toString('hex');
async function request(path, body, method = body ? 'POST' : 'GET', auth = token) {
  const r = await fetch(base + path, {
    method,
    headers: {
      ...(auth ? {
        Authorization: 'Bearer ' + auth
      } : {}),
      ...(body ? {
        'Content-Type': 'application/json'
      } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });
  return {
    status: r.status,
    ...(await r.json())
  };
}
before(async () => {
  if (!/^sim_admin_.*_qa$/.test(process.env.DB_NAME || '')) throw Error('Dedicated Admin QA database required');
  server = require('../src/app').listen(0, '127.0.0.1');
  await new Promise(r => server.once('listening', r));
  base = `http://127.0.0.1:${server.address().port}/api/v1`;
  const login = await request('/auth/login', {
    identitas_akun: 'contoh.admin',
    kata_sandi: 'Contoh123!',
    platform: 'web'
  });
  assert.equal(login.status, 200);
  token = login.data.access_token;
});
after(async () => {
  if (server) {
    server.closeAllConnections();
    await new Promise(r => server.close(r));
  }
  await sequelize.close();
});
test('overview, catalog, teacher duty listings and all aggregate details are real and safe', async () => {
  const overview = await request('/admin/overview');
  assert.equal(overview.status, 200, JSON.stringify(overview));
  assert.ok(overview.data.distribution.length);
  assert.equal(typeof overview.data.counts.siswa, 'number');
  assert.equal((await request('/admin/badge-options')).data.icons.length, 24);
  const teachers = await request('/admin/guru');
  assert.equal(teachers.status, 200);
  assert.equal(typeof teachers.data[0].tugas_wali, 'number');
  for (const key of ['siswa', 'guru', 'orang_tua', 'kelas', 'ekskul', 'periode_ekskul', 'badge', 'versi_badge']) {
    const row = await models[key].findOne();
    const result = await request(`/admin/${key}/${row.id}/workspace`);
    assert.equal(result.status, 200, key + ': ' + JSON.stringify(result));
    assert.ok(result.data.relations);
    assert.ok(!JSON.stringify(result).includes('hash_kata_sandi'));
  }
  const ks = await request('/auth/login', {
    identitas_akun: 'contoh.kesiswaan',
    kata_sandi: 'Contoh123!',
    platform: 'web'
  });
  assert.equal((await request('/admin/overview', null, 'GET', ks.data.access_token)).status, 403);
});
test('student, class, parent account and family relationship commit together or all roll back', async () => {
  const kelas = await models.kelas.findOne();
  const before = await models.siswa.count();
  const data = {
    siswa: {
      nama: 'Siswa Integrasi QA',
      nisn: String(parseInt(suffix, 16)).padStart(10, '0'),
      identitas_login: 'qa.integrated.student.' + suffix,
      kata_sandi: 'Contoh123!',
      status_siswa: 'AKTIF',
      status_akun: 'AKTIF'
    },
    kelas: {
      id_kelas: kelas.id,
      tanggal_mulai: today()
    },
    orang_tua: {
      data: {
        nama: 'Orang Tua QA',
        identitas_login: 'qa.integrated.parent.' + suffix,
        kata_sandi: 'Contoh123!',
        status_akun: 'AKTIF'
      },
      jenis_hubungan: 'WALI',
      tanggal_mulai: today()
    }
  };
  const failed = await request('/admin/workflows/student', {
    ...data,
    orang_tua: {
      ...data.orang_tua,
      data: {
        ...data.orang_tua.data,
        identitas_login: 'contoh.admin'
      }
    }
  });
  assert.equal(failed.status, 409, JSON.stringify(failed));
  assert.equal(await models.siswa.count(), before);
  assert.equal(await models.siswa.count({
    where: {
      identitas_login: data.siswa.identitas_login
    }
  }), 0);
  const saved = await request('/admin/workflows/student', data);
  assert.equal(saved.status, 201, JSON.stringify(saved));
  assert.ok(!saved.data.hash_kata_sandi);
  const view = await request(`/admin/siswa/${saved.data.id}/workspace`);
  assert.equal(view.data.relations.find(r => r.resource === 'hubungan').total, 1);
  assert.equal(view.data.relations.find(r => r.resource === 'riwayat_kelas').total, 1);
  const parent = await models.orang_tua.findOne({
    where: {
      identitas_login: 'qa.integrated.parent.' + suffix
    }
  });
  const existing = await models.siswa.findOne({
    where: {
      identitas_login: 'contoh.siswa'
    }
  });
  const sibling = await request('/admin/workflows/parent-link', {
    id_siswa: existing.id,
    orang_tua: {
      id_orang_tua: parent.id,
      jenis_hubungan: 'WALI',
      tanggal_mulai: today()
    }
  });
  assert.equal(sibling.status, 201, JSON.stringify(sibling));
  assert.equal(await models.orang_tua.count({
    where: {
      identitas_login: parent.identitas_login
    }
  }), 1);
});
test('badge creates identity, current version and all source levels atomically; invalid rules roll back', async () => {
  const semester = await models.semester.findOne({
    where: {
      tanggal_mulai: {
        [require('sequelize').Op.lte]: today()
      },
      tanggal_selesai: {
        [require('sequelize').Op.gte]: today()
      }
    }
  });
  const child = await models.siswa.findOne({
    where: {
      identitas_login: 'contoh.siswa'
    }
  });
  const initialPrestasi = await models.peserta.count({
    where: {
      id_siswa: child.id
    },
    include: [{
      model: models.portofolio,
      as: 'portofolio',
      where: {
        jenis: 'PRESTASI',
        tanggal: {
          [require('sequelize').Op.between]: [semester.tanggal_mulai, today()]
        }
      }
    }]
  });
  const sources = require('../src/utils/badge-catalog').sources;
  const body = {
    badge: {
      nama: 'Badge Enam Sumber QA ' + suffix,
      ikon: 'trophy',
      status: 'AKTIF'
    },
    versi: {
      nomor_versi: 1,
      id_semester_mulai: semester.id,
      id_semester_selesai: null,
      status: 'AKTIF'
    },
    levels: sources.map((s, i) => ({
      nama: 'Level ' + (i + 1),
      sumber_data: s.code,
      cara_hitung: s.methods[0],
      target: s.code === 'PRESTASI' ? initialPrestasi + 2 : 2,
      jenis_presensi: s.code === 'PRESENSI_SEKOLAH' ? 'PAGI' : null,
      status_kehadiran_yang_dihitung: s.code.startsWith('PRESENSI_') ? 'HADIR' : null,
      cakupan_perhitungan: 'SEMESTER',
      id_ekstrakurikuler: null
    }))
  };
  const bad = await request('/admin/workflows/badge', {
    ...body,
    levels: [{
      ...body.levels[0],
      target: 0
    }]
  });
  assert.equal(bad.status, 422, JSON.stringify(bad));
  assert.equal(await models.badge.count({
    where: {
      nama: body.badge.nama
    }
  }), 0);
  const good = await request('/admin/workflows/badge', body);
  assert.equal(good.status, 201, JSON.stringify(good));
  assert.equal(good.data.levels.length, 6);
  const protectedVersion = await request(`/admin/versi_badge/${good.data.versi.id}/workspace`);
  assert.equal(protectedVersion.data.locked, true);
  const editing = await request('/admin/level/' + good.data.levels[0].id, {
    target: 3
  }, 'PATCH');
  assert.equal(editing.status, 409);
  const student = await models.siswa.findOne({
    where: {
      identitas_login: 'contoh.siswa'
    }
  });
  const collection = await require('../src/services/badges').collection(student.id);
  assert.ok(collection.some(r => r.ikon === 'trophy'));
  await require('../src/services/badges').reconcile();
  await require('../src/services/badges').reconcile();
  const teacher = await models.guru.findOne({
    where: {
      identitas_login: 'contoh.guru'
    }
  });
  const created = [];
  for (let i = 0; i < 2; i++) {
    const p = await models.portofolio.create({
      id_guru_pencatat: teacher.id,
      jenis: 'PRESTASI',
      tingkat_prestasi: 'SEKOLAH',
      hasil_prestasi: 'Juara 1',
      judul: 'Prestasi tim QA ' + suffix + ' ' + i,
      tanggal: today()
    });
    await models.peserta.create({
      id_portofolio: p.id,
      id_siswa: child.id
    });
    created.push(p);
  }
  const earnedLevel = good.data.levels.find(l => l.sumber_data === 'PRESTASI');
  await require('../src/services/badges').reconcile();
  const earned = await models.pencapaian.findOne({
    where: {
      id_siswa: child.id,
      id_level_badge: earnedLevel.id
    }
  });
  assert.equal(earned.aktif, true);
  assert.ok(earned.periode_bukti_mulai);
  assert.ok(earned.periode_bukti_selesai);
  for (const p of created) await p.update({
    tanggal: require('../src/utils/badge-evaluation').shift(semester.tanggal_mulai, -1)
  });
  await require('../src/services/badges').reconcile();
  assert.equal((await earned.reload()).aktif, false);
  for (const p of created) await p.update({
    tanggal: today()
  });
  await require('../src/services/badges').reconcile();
  assert.equal((await earned.reload()).aktif, true);
  for (const p of created) await p.update({
    tanggal: require('../src/utils/badge-evaluation').shift(semester.tanggal_mulai, -1)
  });
  const future = await models.semester.findOne({
    where: {
      tanggal_mulai: {
        [require('sequelize').Op.gt]: today()
      }
    },
    order: [['tanggal_mulai', 'ASC']]
  });
  const beforeLevels = JSON.stringify((await models.level.findAll({
    where: {
      id_versi_aturan_badge: good.data.versi.id
    },
    order: [['id', 'ASC']]
  })).map(r => r.toJSON()));
  const next = await request('/admin/workflows/badge', {
    id_badge: good.data.badge.id,
    versi: {
      nomor_versi: 2,
      id_semester_mulai: future.id,
      id_semester_selesai: null,
      status: 'AKTIF'
    },
    levels: [body.levels[0]]
  });
  assert.equal(next.status, 201, JSON.stringify(next));
  assert.equal(JSON.stringify((await models.level.findAll({
    where: {
      id_versi_aturan_badge: good.data.versi.id
    },
    order: [['id', 'ASC']]
  })).map(r => r.toJSON())), beforeLevels);
  assert.equal((await models.versi_badge.findByPk(good.data.versi.id)).id_semester_selesai, semester.id);
  const [duplicates] = await sequelize.query('SELECT id_siswa,id_level_badge,COUNT(*) n FROM pencapaian_badge GROUP BY id_siswa,id_level_badge HAVING n>1');
  assert.equal(duplicates.length, 0);
});
test('changing a teacher into a web primary role requires ending active duties first', async () => {
  const teacher = await models.guru.findOne({
    where: {
      identitas_login: 'contoh.guru'
    }
  });
  const role = await models.peran.findOne({
    where: {
      kode: 'KESISWAAN'
    }
  });
  const result = await request('/admin/guru/' + teacher.id, {
    id_peran_utama: role.id
  }, 'PATCH');
  assert.equal(result.status, 409, JSON.stringify(result));
  assert.equal(result.error.code, 'END_ASSIGNMENTS_FIRST');
  assert.equal((await models.guru.findByPk(teacher.id)).id_peran_utama, teacher.id_peran_utama);
});
