const {
  test,
  before,
  after
} = require('node:test');
const assert = require('node:assert/strict');
const {
  Op
} = require('sequelize');
const {
  sequelize,
  models
} = require('../src/models');
const {
  today
} = require('../src/controllers/auth.controller');
const {
  reconcile
} = require('../src/services/badges');
const suffix = require('node:crypto').randomBytes(4).toString('hex');
const day = offset => new Date(Date.parse(today()) + offset * 86400000).toISOString().slice(0, 10);
let server, base, ks, admin, teacher, bk, studentA, studentB, studentTokenA, studentTokenB, schoolClass, author, category, report, achievement, level;
async function request(path, body, method = body ? 'POST' : 'GET', token = ks, headers = {}) {
  const raw = Buffer.isBuffer(body);
  const response = await fetch(base + path, {
    method,
    headers: {
      ...(token ? {
        Authorization: 'Bearer ' + token
      } : {}),
      ...(body && !raw ? {
        'Content-Type': 'application/json'
      } : {}),
      ...headers
    },
    body: body ? raw ? body : JSON.stringify(body) : undefined
  });
  const json = response.headers.get('content-type')?.includes('json');
  const result = json ? await response.json() : await response.text();
  return {
    status: response.status,
    ...(json ? result : {
      text: result
    })
  };
}
async function login(name, platform = 'web') {
  const result = await request('/auth/login', {
    identitas_akun: name,
    kata_sandi: 'Contoh123!',
    platform
  }, 'POST', null);
  assert.equal(result.status, 200, JSON.stringify(result));
  return result.data;
}
const good = (r, status = 200) => {
  assert.equal(r.status, status, JSON.stringify(r));
  return r.data;
};
before(async () => {
  if (!/^sim_admin_.*_qa$/.test(process.env.DB_NAME || '')) throw Error('Dedicated workspace QA database required');
  server = require('../src/app').listen(0, '127.0.0.1');
  await new Promise(r => server.once('listening', r));
  base = `http://127.0.0.1:${server.address().port}/api/v1`;
  ks = (await login('contoh.kesiswaan')).access_token;
  admin = (await login('contoh.admin')).access_token;
  teacher = (await login('contoh.guru', 'mobile')).access_token;
  bk = (await login('contoh.bk', 'mobile')).access_token;
  schoolClass = await models.kelas.findOne();
  author = await models.guru.findOne({
    where: {
      identitas_login: 'contoh.bk'
    }
  });
  const createStudent = async n => {
    const person = good(await request('/admin/siswa', {
      nama: `Siswa Workspace ${suffix} ${n}`,
      nisn: String((parseInt(suffix, 16) + n) % 10000000000).padStart(10, '0'),
      identitas_login: `qa.workspace.${suffix}.${n}`,
      kata_sandi: 'Contoh123!',
      status_siswa: 'AKTIF',
      status_akun: 'AKTIF'
    }, 'POST', admin), 201);
    await models.riwayat_kelas.create({
      id_siswa: person.id,
      id_kelas: schoolClass.id,
      tanggal_mulai: '2026-07-01'
    });
    return person;
  };
  studentA = await createStudent(1);
  studentB = await createStudent(2);
  studentTokenA = (await login(studentA.identitas_login, 'mobile')).access_token;
  studentTokenB = (await login(studentB.identitas_login, 'mobile')).access_token;
});
after(async () => {
  if (server) {
    server.closeAllConnections();
    await new Promise(r => server.close(r));
  }
  await sequelize.close();
});
test('directory filters and all aggregate reads are real and safe', async () => {
  const rows = good(await request(`/kesiswaan/students?q=${suffix}&kelas=${schoolClass.id}`));
  assert.equal(rows.length, 2);
  assert.ok(rows.every(r => r.id_kelas === schoolClass.id));
  assert.equal(good(await request('/kesiswaan/students?q=%25')).length, 0);
  for (const path of ['/kesiswaan/students', '/kesiswaan/dashboard', '/kesiswaan/proposal-queue', '/kesiswaan/categories', '/kesiswaan/achievements']) good(await request(path));
  assert.equal((await request('/kesiswaan/students?page=0')).status, 422);
  assert.equal((await request('/kesiswaan/students', null, 'GET', teacher)).status, 403);
  assert.equal((await request('/kesiswaan/students', null, 'GET', admin)).status, 403);
  assert.equal((await request('/kesiswaan/students', null, 'GET', null)).status, 401);
  const detail = good(await request(`/kesiswaan/students/${studentA.id}`));
  assert.equal(detail.siswa.id, studentA.id);
  assert.equal(detail.kelas_sekarang.id, schoolClass.id);
  assert.doesNotMatch(JSON.stringify(detail), /hash_kata_sandi|identitas_login|isi_internal/);
});
test('category and first rule are atomic; active rules lock; future rules edit/delete without overlap', async () => {
  const count = await models.kategori.count();
  assert.equal((await request('/kesiswaan/categories', {
    nama: 'Gagal ' + suffix,
    ketentuan: '',
    berlaku_mulai: day(-1)
  })).status, 422);
  assert.equal(await models.kategori.count(), count);
  category = good(await request('/kesiswaan/categories', {
    nama: 'Aturan Workspace ' + suffix,
    ketentuan: 'Aturan yang berlaku',
    berlaku_mulai: day(-2),
    status: 'AKTIF'
  }), 201);
  let detail = good(await request(`/kesiswaan/categories/${category.id}`));
  assert.equal(detail.versions.length, 1);
  assert.equal(detail.versions[0].editable, false);
  assert.equal((await request(`/kesiswaan/categories/${category.id}/versions/${detail.versions[0].id}`, null, 'DELETE')).status, 409);
  const future = good(await request(`/kesiswaan/categories/${category.id}/versions`, {
    ketentuan: 'Versi mendatang',
    berlaku_mulai: day(5)
  }), 201);
  good(await request(`/kesiswaan/categories/${category.id}/versions/${future.id}`, {
    ketentuan: 'Diperbaiki',
    berlaku_mulai: day(5)
  }, 'PUT'));
  assert.equal((await request(`/kesiswaan/categories/${category.id}/versions/${future.id}`, {
    ketentuan: 'Bertumpuk',
    berlaku_mulai: day(2)
  }, 'PUT')).status, 409);
  good(await request(`/kesiswaan/categories/${category.id}/versions/${future.id}`, null, 'DELETE'));
  assert.equal((await request(`/kesiswaan/categories/${category.id}`, null, 'DELETE')).status, 409);
  const unused = good(await request('/kesiswaan/categories', {
    nama: 'Belum berlaku ' + suffix,
    ketentuan: 'Boleh dihapus',
    berlaku_mulai: day(3)
  }), 201);
  good(await request(`/kesiswaan/categories/${unused.id}`, null, 'DELETE'));
});
test('report details retain historical context; private evidence validates type, size, ownership and final status', async () => {
  report = good(await request('/kesiswaan/reports', {
    id_siswa: studentA.id,
    id_kategori_pelanggaran: category.id,
    waktu_kejadian: day(-1) + 'T09:00:00+07:00',
    tempat_kejadian: 'Kelas',
    uraian: 'Uraian ' + suffix
  }), 201);
  const path = `/kesiswaan/reports/${report.id}/bukti`,
    headers = {
      'Content-Type': 'application/pdf',
      'X-Filename': 'bukti.pdf'
    },
    pdf = Buffer.from('%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%EOF');
  assert.equal((await request(path, Buffer.from('bukan pdf'), 'POST', ks, headers)).status, 422);
  assert.equal((await request(path, Buffer.alloc(5 * 1024 * 1024 + 1), 'POST', ks, headers)).status, 413);
  const file = good(await request(path, pdf, 'POST', ks, headers), 201);
  const list = good(await request(path));
  assert.equal(list.length, 1);
  assert.equal(list[0].id, file.id);
  assert.match((await request('/kesiswaan/bukti/' + file.id)).text, /%PDF/);
  assert.equal((await request('/kesiswaan/bukti/' + file.id, null, 'GET', teacher)).status, 403);
  const detail = good(await request(`/kesiswaan/reports/${report.id}`));
  assert.equal(detail.student.id, studentA.id);
  assert.equal(detail.kelas, schoolClass.nama);
  assert.equal(detail.kelas_sekarang.id, schoolClass.id);
  assert.equal(detail.aturan.ketentuan, 'Aturan yang berlaku');
  assert.equal(detail.tempat_kejadian, 'Kelas');
  good(await request(`/kesiswaan/reports/${report.id}/verify`, {
    status_verifikasi: 'TERVERIFIKASI',
    catatan: 'Sesuai fakta'
  }));
  assert.equal((await request(path, pdf, 'POST', ks, headers)).status, 403);
  assert.equal((await models.laporan.findByPk(report.id)).id_guru_pemeriksa, report.id_guru_pelapor);
});
test('profile and CSV use the selected student and period; blank attendance stays distinct from Alfa', async () => {
  const filters = `?mulai=${day(-2)}&sampai=${today()}&siswa=${studentA.id}`;
  const rows = good(await request('/kesiswaan/reports' + filters));
  assert.equal(rows.length, 1);
  assert.ok(rows.every(r => r.id_siswa === studentA.id));
  assert.match((await request('/kesiswaan/reports.csv' + filters)).text, new RegExp(studentA.nama));
  assert.doesNotMatch((await request('/kesiswaan/reports.csv' + filters)).text, /isi_internal/);
  const profile = good(await request(`/kesiswaan/students/${studentA.id}?mulai=${day(-2)}&sampai=${today()}`));
  assert.equal(profile.reports.length, 1);
  const semester = await models.semester.findOne();
  const [session] = await models.sesi.findOrCreate({
    where: {
      jenis_sesi: 'ZUHUR',
      tanggal: day(-1)
    },
    defaults: {
      id_semester: semester.id,
      id_guru_pembuka: author.id,
      waktu_buka: new Date(day(-1) + 'T12:00:00+07:00'),
      waktu_tutup: new Date(day(-1) + 'T13:00:00+07:00'),
      status: 'DITUTUP'
    }
  });
  const attendance = good(await request('/kesiswaan/attendance' + filters));
  assert.equal(attendance.find(r => r.id_sesi === session.id).status_kehadiran, 'BELUM_DIISI');
});
test('BK private notes never appear in profiles/proposals; three decisions and concurrent review preserve case state', async () => {
  const treatment = await models.penanganan.create({
    id_siswa: studentA.id,
    id_guru_bk_penanggung_jawab: author.id,
    tanggal_dibuka: day(-1),
    sumber_pengajuan: 'RUJUKAN',
    alasan_pembukaan: 'Pendampingan QA',
    status: 'TERBUKA',
    ringkasan_diizinkan: 'Ringkasan publik ' + suffix
  });
  await models.riwayat.create({
    id_penanganan_siswa: treatment.id,
    id_guru_pencatat: author.id,
    jenis: 'ASESMEN',
    waktu: new Date(),
    isi_internal: 'PRIVATE_WORKSPACE_' + suffix,
    orang_tua_dilibatkan: false
  });
  for (const action of ['SETUJUI', 'TOLAK', 'MINTA_REVISI']) {
    const proposal = await models.riwayat.create({
      id_penanganan_siswa: treatment.id,
      id_guru_pencatat: author.id,
      jenis: 'USULAN_ESKALASI',
      waktu: new Date(),
      isi_internal: 'PRIVATE_WORKSPACE_' + suffix,
      ringkasan_diizinkan: 'Usulan publik ' + suffix,
      orang_tua_dilibatkan: false,
      status_usulan: 'MENUNGGU'
    });
    const detail = good(await request(`/kesiswaan/proposals/${proposal.id}`));
    assert.equal(detail.student.id, studentA.id);
    assert.equal(detail.proposer.id, author.id);
    assert.doesNotMatch(JSON.stringify(detail), /PRIVATE_WORKSPACE_|isi_internal/);
    const body = {
      keputusan: action,
      alasan: 'Alasan ' + action,
      arahan: 'Arahan yang diizinkan'
    };
    const results = await Promise.all([request(`/kesiswaan/proposals/${proposal.id}/decision`, body), request(`/kesiswaan/proposals/${proposal.id}/decision`, body)]);
    assert.deepEqual(results.map(r => r.status).sort(), [200, 409]);
    assert.equal(await models.riwayat.count({
      where: {
        id_riwayat_acuan: proposal.id
      }
    }), 1);
    assert.equal((await treatment.reload()).status, 'TERBUKA');
  }
  const profile = good(await request(`/kesiswaan/students/${studentA.id}`));
  assert.doesNotMatch(JSON.stringify(profile), /PRIVATE_WORKSPACE_|isi_internal/);
  const list = good(await request('/kesiswaan/proposals'));
  assert.doesNotMatch(JSON.stringify(list), /PRIVATE_WORKSPACE_|isi_internal/);
});
test('achievement creation, correction and cancellation reconcile the union of old/new participants and preserve evidence', async () => {
  const semester = await models.semester.findOne({
    where: {
      tanggal_mulai: {
        [Op.lte]: today()
      },
      tanggal_selesai: {
        [Op.gte]: today()
      }
    }
  });
  assert.ok(semester);
  const badge = await models.badge.create({
    nama: 'Prestasi QA ' + suffix,
    status: 'AKTIF',
    ikon: 'trophy'
  });
  const version = await models.versi_badge.create({
    id_badge: badge.id,
    nomor_versi: 1,
    id_semester_mulai: semester.id,
    status: 'AKTIF'
  });
  level = await models.level.create({
    id_versi_aturan_badge: version.id,
    urutan: 1,
    nama: 'Satu prestasi',
    sumber_data: 'PRESTASI',
    cara_hitung: 'AKUMULASI',
    target: 1,
    cakupan_perhitungan: 'SEMESTER'
  });
  const body = {
    judul: 'Prestasi Workspace ' + suffix,
    tanggal: day(-1),
    tingkat_prestasi: 'Sekolah',
    hasil_prestasi: 'Juara',
    peserta: [studentA.id]
  };
  achievement = good(await request('/kesiswaan/achievements', body), 201);
  assert.equal((await models.pencapaian.findOne({
    where: {
      id_siswa: studentA.id,
      id_level_badge: level.id
    }
  })).aktif, true);
  const file = good(await request(`/kesiswaan/achievements/${achievement.id}/attachments`, Buffer.from('%PDF-1.4\n%%EOF'), 'POST', ks, {
    'Content-Type': 'application/pdf',
    'X-Filename': 'prestasi.pdf'
  }), 201);
  good(await request(`/kesiswaan/achievements/${achievement.id}`, {
    ...body,
    peserta: [studentB.id]
  }, 'PUT'));
  assert.equal((await models.pencapaian.findOne({
    where: {
      id_siswa: studentA.id,
      id_level_badge: level.id
    }
  })).aktif, false);
  assert.equal((await models.pencapaian.findOne({
    where: {
      id_siswa: studentB.id,
      id_level_badge: level.id
    }
  })).aktif, true);
  good(await request(`/kesiswaan/achievements/${achievement.id}/cancel`, {
    alasan_tindakan: 'Salah pencatatan QA'
  }));
  assert.equal((await models.pencapaian.findOne({
    where: {
      id_siswa: studentB.id,
      id_level_badge: level.id
    }
  })).aktif, false);
  assert.equal(await models.peserta.count({
    where: {
      id_portofolio: achievement.id
    }
  }), 1);
  assert.equal(await models.lampiran.count({
    where: {
      id_portofolio: achievement.id
    }
  }), 1);
  assert.match((await request('/kesiswaan/attachments/' + file.id)).text, /%PDF/);
  const detail = good(await request(`/kesiswaan/achievements/${achievement.id}`));
  assert.equal(detail.editable, false);
  assert.equal(detail.status_catatan, 'DIBATALKAN');
  assert.ok(detail.history.some(h => h.alasan === 'Salah pencatatan QA'));
  assert.equal((await request(`/kesiswaan/achievements/${achievement.id}`, body, 'PUT')).status, 409);
  const filtered = good(await request(`/kesiswaan/achievements?siswa=${studentB.id}&q=${suffix}`));
  assert.equal(filtered.length, 0);
  assert.equal(good(await request(`/kesiswaan/achievements?siswa=${studentB.id}&status=DIBATALKAN&q=${suffix}`)).length, 1);
  assert.doesNotMatch(JSON.stringify(good(await request('/student/achievements', null, 'GET', studentTokenB))), new RegExp(body.judul));
  await reconcile({
    studentIds: [studentA.id, studentB.id]
  });
  assert.equal(await models.pencapaian.count({
    where: {
      id_level_badge: level.id
    }
  }), 2);
});
test('Kesiswaan cannot alter extracurricular records while assigned Pembina can still upload', async () => {
  const period = await models.periode_ekskul.findOne();
  const row = await models.portofolio.create({
    id_periode_ekstrakurikuler: period.id,
    id_guru_pencatat: author.id,
    jenis: 'PRESTASI',
    judul: 'Ekskul read-only ' + suffix,
    tanggal: day(-1),
    tingkat_prestasi: 'Sekolah',
    hasil_prestasi: 'Juara'
  });
  const detail = good(await request(`/kesiswaan/achievements/${row.id}`));
  assert.equal(detail.editable, false);
  assert.equal((await request(`/kesiswaan/achievements/${row.id}`, {
    judul: 'Edit',
    tanggal: today(),
    tingkat_prestasi: 'Sekolah',
    hasil_prestasi: 'Juara',
    peserta: [studentA.id]
  }, 'PUT')).status, 403);
  assert.equal((await request(`/kesiswaan/achievements/${row.id}/cancel`, {
    alasan_tindakan: 'Tidak berwenang'
  })).status, 403);
  const file = Buffer.from('%PDF-1.4\n%%EOF'),
    headers = {
      'Content-Type': 'application/pdf',
      'X-Filename': 'ekskul.pdf'
    };
  assert.equal((await request(`/kesiswaan/achievements/${row.id}/attachments`, file, 'POST', ks, headers)).status, 403);
  good(await request(`/pembina/prestasi/${row.id}/lampiran`, file, 'POST', teacher, headers), 201);
});
test('filtered achievement search and invalid filters retain consistent pagination', async () => {
  const result = await request(`/kesiswaan/achievements?kelas=${schoolClass.id}&status=SEMUA&q=${suffix}&mulai=${day(-2)}&sampai=${today()}`);
  good(result);
  assert.ok(result.data.some(r => r.id === achievement.id));
  assert.equal(result.meta.total, result.data.length);
  assert.equal((await request('/kesiswaan/achievements?status=SALAH')).status, 422);
  assert.equal((await request('/kesiswaan/reports?mulai=2026-12-01&sampai=2026-01-01')).status, 422);
});
test('busy badge worker returns a committed save with pending recalculation and later catches up', async () => {
  const connection = await sequelize.connectionManager.getConnection({
    type: 'WRITE'
  });
  const query = sql => new Promise((resolve, reject) => connection.query(sql, (error, result) => error ? reject(error) : resolve(result)));
  let saved;
  try {
    const [lock] = await query("SELECT GET_LOCK(CONCAT(DATABASE(), ':badge'),0) AS acquired");
    assert.equal(lock.acquired, 1);
    const result = await request('/kesiswaan/achievements', {
      judul: 'Pending Badge ' + suffix,
      tanggal: day(-1),
      tingkat_prestasi: 'Sekolah',
      hasil_prestasi: 'Juara',
      peserta: [studentA.id]
    });
    saved = good(result, 201);
    assert.equal(result.meta.badge_recalculation, 'pending');
    assert.ok(await models.portofolio.findByPk(saved.id));
  } finally {
    await query("SELECT RELEASE_LOCK(CONCAT(DATABASE(), ':badge'))");
    await sequelize.connectionManager.releaseConnection(connection);
  }
  await reconcile({
    studentIds: [studentA.id]
  });
  assert.equal((await models.pencapaian.findOne({
    where: {
      id_siswa: studentA.id,
      id_level_badge: level.id
    }
  })).aktif, true);
});
