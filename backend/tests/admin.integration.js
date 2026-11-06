const {
  test,
  before,
  after
} = require('node:test');
const assert = require('node:assert/strict');
const {
  models,
  sequelize,
  schema
} = require('../src/models');
const {
  issueToken
} = require('../src/utils/security');
let server, base, token, studentToken, admin;
before(async () => {
  if (!/_qa$/.test(process.env.DB_NAME || '')) throw new Error('Pengujian integrasi hanya untuk database *_qa yang terpisah.');
  const app = require('../src/app');
  server = app.listen(0, '127.0.0.1');
  await new Promise(r => server.once('listening', r));
  base = `http://127.0.0.1:${server.address().port}/api/v1`;
  admin = await models.guru.unscoped().findOne({
    where: {
      identitas_login: 'admin'
    }
  });
  token = issueToken('guru', admin);
  const student = await models.siswa.unscoped().findOne({
    where: {
      identitas_login: 'contoh.siswa'
    }
  });
  studentToken = issueToken('siswa', student);
});
after(async () => {
  if (server) await new Promise(r => server.close(r));
  await sequelize.close();
});
async function call(path, method = 'GET', body, access = token) {
  const r = await fetch(base + path, {
    method,
    headers: {
      ...(access ? {
        Authorization: `Bearer ${access}`
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
test('38 tables and full foreign keys imported', async () => {
  assert.equal(Object.keys(models).length, 38);
  const [rows] = await sequelize.query("SELECT COUNT(*) n FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE()");
  assert.equal(Number(rows[0].n), 65);
  for (const k of Object.keys(models)) assert.ok((await models[k].count()) > 0, k);
});
test('real login, safe response and me', async () => {
  const r = await call('/auth/login', 'POST', {
    identitas_akun: 'admin',
    kata_sandi: process.env.SEED_ADMIN_PASSWORD
  }, null);
  assert.equal(r.status, 200);
  assert.ok(r.data.user.roles.includes('ADMIN'));
  assert.ok(!JSON.stringify(r).includes('hash_kata_sandi'));
  assert.equal((await call('/auth/me')).data.id, admin.id);
});
test('wrong password, unknown account and nonadmin access rejected', async () => {
  assert.equal((await call('/auth/login', 'POST', {
    identitas_akun: 'admin',
    kata_sandi: 'wrong'
  }, null)).status, 401);
  assert.equal((await call('/auth/login', 'POST', {
    identitas_akun: 'missing',
    kata_sandi: 'wrong'
  }, null)).status, 401);
  assert.equal((await call('/admin/summary', 'GET', null, null)).status, 401);
  assert.equal((await call('/admin/summary', 'GET', null, studentToken)).status, 403);
});
test('expiry and tampering rejected', async () => {
  assert.equal((await call('/auth/me', 'GET', null, issueToken('guru', admin, Date.now() - 1000000))).status, 401);
  assert.equal((await call('/auth/me', 'GET', null, token + 'x')).status, 401);
});
test('master create, search, persistence, update, pagination and delete', async () => {
  const a = await call('/admin/guru', 'POST', {
    nama: 'Guru QA Temporary',
    identitas_login: 'qa.temporary',
    kata_sandi: 'QaTemporary123!',
    status_akun: 'AKTIF'
  });
  assert.equal(a.status, 201, JSON.stringify(a));
  assert.ok(!a.data.hash_kata_sandi);
  const id = a.data.id;
  assert.equal((await call(`/admin/guru?q=qa.temporary&page=1&limit=1`)).meta.total, 1);
  assert.equal((await call(`/admin/guru/${id}`, 'PATCH', {
    nama: 'Updated QA'
  })).status, 200);
  assert.equal((await call(`/admin/guru/${id}`)).data.nama, 'Updated QA');
  assert.equal((await call(`/admin/guru/${id}`, 'DELETE')).status, 200);
});
test('global identity uniqueness across account types and racing writes', async () => {
  assert.equal((await call('/admin/orang_tua', 'POST', {
    nama: 'Conflict',
    identitas_login: 'admin',
    kata_sandi: 'QaTemporary123!',
    status_akun: 'AKTIF'
  })).status, 409);
  const body = {
    nama: 'Race',
    identitas_login: 'qa.race',
    kata_sandi: 'QaTemporary123!',
    status_akun: 'AKTIF'
  };
  const rs = await Promise.all([call('/admin/guru', 'POST', body), call('/admin/orang_tua', 'POST', body)]);
  assert.deepEqual(rs.map(r => r.status).sort(), [201, 409]);
  for (let i = 0; i < 2; i++) if (rs[i].status === 201) await call(`/admin/${i ? 'orang_tua' : 'guru'}/${rs[i].data.id}`, 'DELETE');
});
test('last Admin protected from deactivation or role termination', async () => {
  assert.equal((await call(`/admin/guru/${admin.id}`, 'PATCH', {
    status_akun: 'NONAKTIF'
  })).status, 409);
  const role = await models.peran.findOne({
      where: {
        kode: 'ADMIN'
      }
    }),
    assignment = await models.guru_peran.findOne({
      where: {
        id_guru: admin.id,
        id_peran: role.id
      }
    });
  assert.equal((await call(`/admin/guru_peran/${assignment.id}`, 'PATCH', {
    tanggal_selesai: '2026-01-02'
  })).status, 409);
  assert.equal((await models.guru.findByPk(admin.id)).status_akun, 'AKTIF');
});
test('references prevent destructive deletion and active history protected', async () => {
  const siswa = await models.siswa.findOne({
    where: {
      identitas_login: 'contoh.siswa'
    }
  });
  assert.equal((await call(`/admin/siswa/${siswa.id}`, 'DELETE')).status, 409);
  const r = await models.hubungan.findOne({
    where: {
      id_siswa: siswa.id
    }
  });
  assert.equal((await call(`/admin/hubungan/${r.id}`, 'DELETE')).status, 409);
  assert.equal((await call('/admin/hubungan', 'POST', {
    id_orang_tua: r.id_orang_tua,
    id_siswa: siswa.id,
    jenis_hubungan: 'IBU',
    tanggal_mulai: '2026-08-01',
    tanggal_selesai: null
  })).status, 409);
});
test('validation, unknown fields and invalid foreign keys', async () => {
  assert.equal((await call('/admin/siswa', 'POST', {
    nama: 'Invalid',
    nisn: 'abc',
    identitas_login: 'bad',
    kata_sandi: 'QaTemporary123!',
    status_siswa: 'AKTIF',
    status_akun: 'AKTIF'
  })).status, 422);
  assert.equal((await call('/admin/guru/' + admin.id, 'PATCH', {
    hash_kata_sandi: 'plaintext'
  })).status, 422);
  assert.equal((await call('/admin/kelas', 'POST', {
    id_tahun_ajaran: 999999,
    nama: 'Invalid',
    tingkat: 'X',
    status: 'AKTIF'
  })).status, 422);
});
test('badge old version immutable, future level supports one structured condition', async () => {
  const old = await models.versi_badge.findOne({
    where: {
      nomor_versi: 1
    }
  });
  assert.equal((await call(`/admin/versi_badge/${old.id}`, 'PATCH', {
    nomor_versi: 99
  })).status, 409);
  const next = await models.versi_badge.findOne({
    where: {
      nomor_versi: 2
    }
  });
  const r = await call('/admin/level', 'POST', {
    id_versi_aturan_badge: next.id,
    urutan: 2,
    nama: 'QA Level',
    sumber_data: 'PRESENSI_EKSKUL',
    cara_hitung: 'AKUMULASI',
    target: 3,
    jenis_presensi: null,
    status_kehadiran_yang_dihitung: 'HADIR',
    cakupan_perhitungan: 'SEMESTER'
  });
  assert.equal(r.status, 201, JSON.stringify(r));
  assert.equal((await call(`/admin/level/${r.data.id}`, 'DELETE')).status, 200);
});
test('password reset revokes token and audit excludes secrets', async () => {
  const g = await call('/admin/guru', 'POST', {
    nama: 'Reset QA',
    identitas_login: 'qa.reset',
    kata_sandi: 'QaTemporary123!',
    status_akun: 'AKTIF'
  });
  const user = await models.guru.unscoped().findByPk(g.data.id);
  const old = issueToken('guru', user);
  assert.equal((await call(`/admin/accounts/guru/${user.id}/reset-password`, 'POST', {
    kata_sandi: 'QaChanged123!'
  })).status, 200);
  assert.equal((await call('/auth/me', 'GET', null, old)).status, 401);
  assert.equal((await call(`/admin/guru/${user.id}`, 'PATCH', {
    status_akun: 'NONAKTIF'
  })).status, 200);
  assert.equal((await call('/auth/login', 'POST', {
    identitas_akun: 'qa.reset',
    kata_sandi: 'QaChanged123!'
  }, null)).status, 401);
  const details = await models.detail_audit.findAll();
  assert.ok(!JSON.stringify(details).includes('QaTemporary'));
  assert.ok(!details.some(d => ['hash_kata_sandi', 'kata_sandi'].includes(d.nama_atribut)));
  await call(`/admin/guru/${user.id}`, 'DELETE');
});
test('all Admin resources and lookups respond', async () => {
  const meta = await call('/admin/metadata');
  for (const key of Object.keys(meta.data)) {
    assert.equal((await call(`/admin/${key}?page=1&limit=10`)).status, 200, key);
    assert.equal((await call(`/admin/lookups/${key}?page=1&limit=20`)).status, 200, key);
  }
  assert.equal((await call('/admin/accounts')).status, 200);
});
test('atomic class transfer and rollback of invalid replacement', async () => {
  const tahun = await models.tahun.findOne({
    where: {
      nama: '2026/2027'
    }
  });
  const kelas = await models.kelas.findOne({
    where: {
      nama: 'X Contoh'
    }
  });
  const extra = await models.kelas.create({
    id_tahun_ajaran: tahun.id,
    nama: 'QA Transfer',
    tingkat: 'X',
    status: 'AKTIF'
  });
  const s = await call('/admin/siswa', 'POST', {
    nama: 'Transfer QA',
    nisn: '0099990002',
    identitas_login: 'qa.transfer',
    kata_sandi: 'QaTemporary123!',
    status_akun: 'AKTIF',
    status_siswa: 'AKTIF'
  });
  assert.equal(s.status, 201);
  const r = await call('/admin/riwayat_kelas', 'POST', {
    id_siswa: s.data.id,
    id_kelas: kelas.id,
    tanggal_mulai: '2026-07-01',
    tanggal_selesai: null
  });
  assert.equal(r.status, 201, JSON.stringify(r));
  assert.equal((await call(`/admin/riwayat_kelas/${r.data.id}/replace`, 'POST', {
    id_kelas: 999999,
    tanggal_mulai: '2026-11-15'
  })).status, 422);
  assert.equal((await models.riwayat_kelas.findByPk(r.data.id)).tanggal_selesai, null);
  const move = await call(`/admin/riwayat_kelas/${r.data.id}/replace`, 'POST', {
    id_kelas: extra.id,
    tanggal_mulai: '2026-11-15'
  });
  assert.equal(move.status, 201, JSON.stringify(move));
  assert.equal((await models.riwayat_kelas.findByPk(r.data.id)).tanggal_selesai, '2026-11-14');
  assert.equal(move.data.id_kelas, extra.id);
  await models.riwayat_kelas.destroy({
    where: {
      id_siswa: s.data.id
    }
  });
  await models.siswa.destroy({
    where: {
      id: s.data.id
    }
  });
  await extra.destroy();
});
test('academic date containment and repeat constraint prevent incompatible edits', async () => {
  const tahun = await models.tahun.findOne({
    where: {
      nama: '2026/2027'
    }
  });
  assert.equal((await call(`/admin/tahun/${tahun.id}`, 'PATCH', {
    tanggal_selesai: '2026-12-31'
  })).status, 422);
  assert.equal((await call('/admin/semester', 'POST', {
    id_tahun_ajaran: tahun.id,
    nama: 'QA Overlap',
    tanggal_mulai: '2026-08-01',
    tanggal_selesai: '2026-09-01'
  })).status, 422);
});
test('teacher replacement preserves previous assignment', async () => {
  const old = await models.wali.findOne();
  const g = await call('/admin/guru', 'POST', {
    nama: 'Pengganti QA',
    identitas_login: 'qa.pengganti',
    kata_sandi: 'QaTemporary123!',
    status_akun: 'AKTIF'
  });
  const before = old.toJSON();
  const r = await call(`/admin/wali/${old.id}/replace`, 'POST', {
    id_guru: g.data.id,
    tanggal_mulai: '2026-11-15'
  });
  assert.equal(r.status, 201, JSON.stringify(r));
  assert.equal((await models.wali.findByPk(old.id)).tanggal_selesai, '2026-11-14');
  await models.wali.destroy({
    where: {
      id: r.data.id
    }
  });
  await models.wali.update({ tanggal_selesai: before.tanggal_selesai }, { where: { id: old.id } });
  await models.guru.destroy({
    where: {
      id: g.data.id
    }
  });
});
test('changing active academic year is atomic and audited', async () => {
  const old = await models.tahun.findOne({
    where: {
      aktif: true
    }
  });
  const y = await call('/admin/tahun', 'POST', {
    nama: '2027/2028 QA',
    tanggal_mulai: '2027-07-01',
    tanggal_selesai: '2028-06-30',
    aktif: true
  });
  assert.equal(y.status, 201, JSON.stringify(y));
  assert.equal(await models.tahun.count({
    where: {
      aktif: true
    }
  }), 1);
  assert.equal((await models.tahun.findByPk(old.id)).aktif, false);
  assert.ok(await models.audit.count({
    where: {
      jenis_tindakan: 'NONAKTIFKAN_TAHUN_LAMA',
      identitas_data: String(old.id)
    }
  }));
  assert.equal((await call(`/admin/tahun/${old.id}`, 'PATCH', {
    aktif: true
  })).status, 200);
  assert.equal((await call(`/admin/tahun/${y.data.id}`, 'DELETE')).status, 200);
});
