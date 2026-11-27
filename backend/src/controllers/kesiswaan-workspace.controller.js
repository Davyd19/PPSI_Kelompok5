const {
  Op
} = require('sequelize');
const {
  models,
  sequelize
} = require('../models');
const k = require('./kesiswaan.controller');
const {
  id,
  string,
  date,
  invalid,
  missing
} = k.validation;
const {
  select,
  options,
  reportSql,
  attendanceSql,
  verification
} = k.read;
const {
  today
} = require('./auth.controller');
const audit = require('../utils/audit');
const fail = require('../utils/api-error');
const conflict = message => fail(409, 'STATE_CONFLICT', message);
const send = (res, data, status = 200) => res.status(status).json({
  data
});
const studentFields = ['id', 'nama', 'nisn', 'nis', 'status_siswa'];
const historyFields = ['id', 'id_penanganan_siswa', 'id_laporan_pelanggaran', 'id_riwayat_acuan', 'id_guru_pencatat', 'jenis', 'waktu', 'ringkasan_diizinkan', 'status_usulan', 'hasil_keputusan', 'alasan_keputusan', 'arahan_tindak_lanjut'];
async function student(studentId) {
  const row = await models.siswa.findByPk(studentId, {
    attributes: studentFields
  });
  if (!row) throw missing();
  return row;
}
async function sharedHistory(where) {
  const rows = await models.riwayat.findAll({
    where,
    attributes: historyFields,
    order: [['waktu', 'ASC'], ['id', 'ASC']]
  });
  // Only explicitly shared narrative and official proposal responses leave the BK boundary.
  return rows.filter(r => r.ringkasan_diizinkan || ['USULAN_ESKALASI', 'USULAN_RUJUKAN', 'KEPUTUSAN', 'RESPONS'].includes(r.jenis));
}
async function currentClass(studentId) {
  return (await select(`SELECT k.id,k.nama,k.tingkat,t.nama AS tahun_ajaran FROM riwayat_kelas_siswa r JOIN kelas k ON k.id=r.id_kelas JOIN tahun_ajaran t ON t.id=k.id_tahun_ajaran WHERE r.id_siswa=:student AND r.tanggal_mulai<=:day AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=:day) ORDER BY r.tanggal_mulai DESC,r.id DESC LIMIT 1`, {
    student: studentId,
    day: today()
  }))[0] || null;
}
exports.students = async (req, res) => {
  const f = options(req, []);
  const sql = `SELECT s.id,s.nama,s.nisn,s.status_siswa,c.nama AS kelas,c.id AS id_kelas FROM siswa s LEFT JOIN kelas c ON c.id=(SELECT r.id_kelas FROM riwayat_kelas_siswa r WHERE r.id_siswa=s.id AND r.tanggal_mulai<=:day AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=:day) ORDER BY r.tanggal_mulai DESC,r.id DESC LIMIT 1) WHERE (:q IS NULL OR s.nama LIKE :q OR s.nisn LIKE :q) AND (:kelas IS NULL OR c.id=:kelas)`;
  const args = {
    ...f,
    day: today()
  };
  const [rows, [count]] = await Promise.all([select(sql + ' ORDER BY s.nama,s.id LIMIT 25 OFFSET :offset', args), select('SELECT COUNT(*) AS total FROM (' + sql + ') r', args)]);
  res.json({
    data: rows,
    meta: {
      total: Number(count.total),
      page: f.page,
      page_size: 25
    }
  });
};
exports.student = async (req, res) => {
  const studentId = id(req.params.id),
    person = await student(studentId);
  const f = options({
    ...req,
    query: {
      ...req.query,
      siswa: studentId,
      status: undefined
    }
  }, verification);
  const [kelas, reports, attendance, handling, achievements] = await Promise.all([currentClass(studentId), select(reportSql() + ' ORDER BY waktu_kejadian DESC,id DESC', f), select(attendanceSql() + ' ORDER BY tanggal DESC,id_sesi DESC', {
    ...f,
    status: null
  }), models.penanganan.findAll({
    where: {
      id_siswa: studentId
    },
    attributes: ['id', 'tanggal_dibuka', 'status', 'ringkasan_diizinkan'],
    order: [['tanggal_dibuka', 'DESC']]
  }), models.portofolio.findAll({
    where: {
      jenis: 'PRESTASI',
      status_catatan: 'AKTIF',
      tanggal: {
        [Op.between]: [f.start, f.end]
      }
    },
    attributes: ['id', 'judul', 'tanggal', 'tingkat_prestasi', 'hasil_prestasi', 'id_periode_ekstrakurikuler'],
    include: [{
      model: models.peserta,
      as: 'peserta_id_portofolio',
      required: true,
      where: {
        id_siswa: studentId
      },
      attributes: []
    }],
    order: [['tanggal', 'DESC']]
  })]);
  const cases = await Promise.all(handling.map(async h => ({
    ...h.toJSON(),
    riwayat: await sharedHistory({
      id_penanganan_siswa: h.id
    })
  })));
  send(res, {
    siswa: person,
    kelas_sekarang: kelas,
    periode: {
      mulai: f.start,
      sampai: f.end
    },
    reports,
    attendance,
    handling: cases,
    achievements
  });
};
async function reportDetail(reportId) {
  const row = await models.laporan.findByPk(reportId);
  if (!row) throw missing();
  const [person, kelas, aturan, pelapor, pemeriksa, historical, history] = await Promise.all([student(row.id_siswa), currentClass(row.id_siswa), models.aturan.findByPk(row.id_versi_aturan_penanganan), models.guru.findByPk(row.id_guru_pelapor, {
    attributes: ['id', 'nama']
  }), row.id_guru_pemeriksa ? models.guru.findByPk(row.id_guru_pemeriksa, {
    attributes: ['id', 'nama']
  }) : null, select(`SELECT k.id,k.nama FROM riwayat_kelas_siswa r JOIN kelas k ON k.id=r.id_kelas WHERE r.id_siswa=:student AND r.tanggal_mulai<=:day AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=:day) ORDER BY r.tanggal_mulai DESC,r.id DESC LIMIT 1`, {
    student: row.id_siswa,
    day: new Date(new Date(row.waktu_kejadian).getTime() + 7 * 3600000).toISOString().slice(0, 10)
  }), sharedHistory({
    id_laporan_pelanggaran: reportId
  })]);
  const category = await models.kategori.findByPk(aturan.id_kategori_pelanggaran);
  const handling = row.id_penanganan_siswa ? await models.penanganan.findByPk(row.id_penanganan_siswa, {
    attributes: ['id', 'id_siswa', 'status', 'ringkasan_diizinkan']
  }) : null;
  return {
    ...row.toJSON(),
    siswa: person.nama,
    student: person,
    kelas: historical[0]?.nama,
    kelas_sekarang: kelas,
    kategori: category.nama,
    nomor_versi: aturan.nomor_versi,
    aturan: aturan.toJSON(),
    pelapor: pelapor?.nama,
    pemeriksa: pemeriksa?.nama,
    history,
    handling
  };
}
exports.report = async (req, res) => send(res, await reportDetail(id(req.params.id)));
exports.proposal = async (req, res) => {
  const row = await models.riwayat.findByPk(id(req.params.id), {
    attributes: historyFields
  });
  if (!row || !['USULAN_ESKALASI', 'USULAN_RUJUKAN'].includes(row.jenis)) throw missing();
  let handling = null,
    report = null;
  if (row.id_penanganan_siswa) handling = await models.penanganan.findByPk(row.id_penanganan_siswa, {
    attributes: ['id', 'id_siswa', 'status', 'ringkasan_diizinkan']
  });
  if (row.id_laporan_pelanggaran) report = await reportDetail(row.id_laporan_pelanggaran);
  const studentId = handling?.id_siswa || report?.id_siswa;
  const proposer = await models.guru.findByPk(row.id_guru_pencatat, {
    attributes: ['id', 'nama']
  });
  const related = handling ? await models.laporan.findAll({
    where: {
      id_penanganan_siswa: handling.id
    },
    attributes: ['id', 'id_siswa', 'waktu_kejadian', 'status_verifikasi', 'uraian']
  }) : [];
  const history = await sharedHistory(handling ? {
    id_penanganan_siswa: handling.id
  } : {
    id_laporan_pelanggaran: report.id
  });
  send(res, {
    ...row.toJSON(),
    student: await student(studentId),
    kelas_sekarang: await currentClass(studentId),
    proposer,
    penanganan_siswa: handling,
    report,
    related_reports: related,
    history
  });
};
exports.proposalQueue = async (req, res) => {
  const f = options({
    ...req,
    query: {
      ...req.query,
      status: undefined
    }
  }, []);
  const sql = `SELECT r.id,r.jenis,r.waktu,r.status_usulan,r.ringkasan_diizinkan,s.id AS id_siswa,s.nama AS siswa FROM riwayat_penanganan r LEFT JOIN penanganan_siswa p ON p.id=r.id_penanganan_siswa LEFT JOIN laporan_pelanggaran l ON l.id=r.id_laporan_pelanggaran JOIN siswa s ON s.id=COALESCE(p.id_siswa,l.id_siswa) WHERE r.jenis IN ('USULAN_ESKALASI','USULAN_RUJUKAN') AND r.status_usulan='MENUNGGU' AND r.waktu>=TIMESTAMP(:start)-INTERVAL 7 HOUR AND r.waktu<TIMESTAMP(:end)+INTERVAL 17 HOUR AND (:kelas IS NULL OR EXISTS(SELECT 1 FROM riwayat_kelas_siswa h WHERE h.id_siswa=s.id AND h.id_kelas=:kelas AND h.tanggal_mulai<=:end AND (h.tanggal_selesai IS NULL OR h.tanggal_selesai>=:end)))`;
  const [rows, [count]] = await Promise.all([select(sql + ' ORDER BY r.waktu,r.id LIMIT 5', f), select('SELECT COUNT(*) AS total FROM (' + sql + ') q', f)]);
  send(res, {
    rows,
    total: Number(count.total)
  });
};
exports.category = async (req, res) => {
  const row = await models.kategori.findByPk(id(req.params.id));
  if (!row) throw missing();
  const versions = await models.aturan.findAll({
    where: {
      id_kategori_pelanggaran: row.id
    },
    order: [['berlaku_mulai', 'DESC']]
  });
  const rules = await Promise.all(versions.map(async v => ({
    ...v.toJSON(),
    editable: v.berlaku_mulai > today() && !(await models.laporan.count({
      where: {
        id_versi_aturan_penanganan: v.id
      }
    }))
  })));
  const f = options({
    ...req,
    query: {
      ...req.query,
      kategori: row.id,
      status: undefined
    }
  }, verification);
  const reports = await select(reportSql() + ' ORDER BY waktu_kejadian DESC,id DESC LIMIT 25', f);
  send(res, {
    ...row.toJSON(),
    versions: rules,
    reports
  });
};
exports.createCategory = async (req, res) => {
  const b = req.body || {};
  if (b.ketentuan === undefined && b.berlaku_mulai === undefined) return k.saveCategory(req, res);
  const start = date(b.berlaku_mulai, 'Tanggal mulai'),
    end = b.berlaku_sampai ? date(b.berlaku_sampai, 'Tanggal akhir') : null;
  if (end && end < start) throw invalid('Tanggal akhir mendahului tanggal mulai.');
  if (!['AKTIF', 'NONAKTIF'].includes(b.status || 'AKTIF')) throw invalid('Status kategori tidak valid.');
  const patch = {
    nama: string(b.nama, 'Nama kategori', 191),
    deskripsi: string(b.deskripsi, 'Deskripsi', 10000, true),
    status: b.status || 'AKTIF'
  };
  const ketentuan = string(b.ketentuan, 'Ketentuan awal', 20000);
  const row = await sequelize.transaction(async t => {
    const c = await models.kategori.create(patch, {
      transaction: t
    });
    const v = await models.aturan.create({
      id_kategori_pelanggaran: c.id,
      nomor_versi: 1,
      ketentuan,
      berlaku_mulai: start,
      berlaku_sampai: end
    }, {
      transaction: t
    });
    await audit(req, 'kategori', c.id, null, c.toJSON(), 'TAMBAH', t);
    await audit(req, 'aturan', v.id, null, v.toJSON(), 'TAMBAH_VERSI', t);
    return c;
  });
  send(res, row, 201);
};
exports.version = async (req, res) => {
  const categoryId = id(req.params.id),
    versionId = id(req.params.versionId);
  const row = await sequelize.transaction(async t => {
    const parent = await models.kategori.findByPk(categoryId, {
      transaction: t,
      lock: t.LOCK.UPDATE
    });
    if (!parent) throw missing();
    const rule = await models.aturan.findOne({
      where: {
        id: versionId,
        id_kategori_pelanggaran: categoryId
      },
      transaction: t,
      lock: t.LOCK.UPDATE
    });
    if (!rule) throw missing();
    if (rule.berlaku_mulai <= today() || (await models.laporan.count({
      where: {
        id_versi_aturan_penanganan: rule.id
      },
      transaction: t
    }))) throw conflict('Versi yang sudah berlaku atau digunakan tidak dapat diubah/dihapus.');
    const before = rule.toJSON();
    if (req.method === 'DELETE') {
      await rule.destroy({
        transaction: t
      });
      await audit(req, 'aturan', rule.id, before, null, 'HAPUS_VERSI', t);
      return {
        id: rule.id
      };
    }
    const start = date(req.body?.berlaku_mulai, 'Tanggal mulai'),
      end = req.body?.berlaku_sampai ? date(req.body.berlaku_sampai, 'Tanggal akhir') : null;
    if (start <= today() || end && end < start) throw invalid('Versi baru harus mulai pada tanggal mendatang dengan rentang yang sah.');
    const others = await models.aturan.findAll({
      where: {
        id_kategori_pelanggaran: categoryId,
        id: {
          [Op.ne]: rule.id
        }
      },
      transaction: t
    });
    if (others.some(v => (!end || v.berlaku_mulai <= end) && (!v.berlaku_sampai || v.berlaku_sampai >= start))) throw conflict('Masa berlaku aturan bertumpuk.');
    await rule.update({
      ketentuan: string(req.body?.ketentuan, 'Ketentuan', 20000),
      berlaku_mulai: start,
      berlaku_sampai: end
    }, {
      transaction: t
    });
    await audit(req, 'aturan', rule.id, before, rule.toJSON(), 'UBAH_VERSI', t);
    return rule;
  });
  send(res, row);
};
exports.deleteCategory = async (req, res) => {
  const result = await sequelize.transaction(async t => {
    const row = await models.kategori.findByPk(id(req.params.id), {
      transaction: t,
      lock: t.LOCK.UPDATE
    });
    if (!row) throw missing();
    const versions = await models.aturan.findAll({
      where: {
        id_kategori_pelanggaran: row.id
      },
      transaction: t,
      lock: t.LOCK.UPDATE
    });
    if (versions.some(v => v.berlaku_mulai <= today()) || (await models.laporan.count({
      where: {
        id_versi_aturan_penanganan: versions.map(v => v.id)
      },
      transaction: t
    }))) throw conflict('Kategori memiliki aturan berlaku/riwayat laporan; gunakan nonaktifkan secara terpisah.');
    for (const v of versions) {
      await v.destroy({
        transaction: t
      });
      await audit(req, 'aturan', v.id, v.toJSON(), null, 'HAPUS_VERSI', t);
    }
    await row.destroy({
      transaction: t
    });
    await audit(req, 'kategori', row.id, row.toJSON(), null, 'HAPUS', t);
    return {
      id: row.id
    };
  });
  send(res, result);
};
