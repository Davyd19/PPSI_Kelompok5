const path = require('node:path');
const fs = require('node:fs/promises');
const {
  randomUUID
} = require('node:crypto');
const {
  sequelize,
  models
} = require('../models');
const audit = require('../utils/audit');
const {
  Op
} = require('sequelize');
const {
  id,
  date,
  string,
  invalid,
  missing,
  like
} = require('./kesiswaan.controller').validation;
const directory = path.resolve(process.env.PRESTASI_UPLOAD_DIR || path.join(__dirname, '../../storage/prestasi'));
const accepted = {
  'application/pdf': data => data.subarray(0, 5).toString() === '%PDF-' && data.subarray(-1024).toString().includes('%%EOF'),
  'image/jpeg': data => data[0] === 255 && data[1] === 216 && data[2] === 255 && data.at(-2) === 255 && data.at(-1) === 217,
  'image/png': data => data.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) && data.subarray(-8, -4).toString() === 'IEND'
};
exports.list = async (req, res) => {
  const page = req.query.page ? id(req.query.page) : 1;
  if (page > 100000) throw invalid('Halaman tidak valid.');
  const q = like(req.query.q);
  const filters = require('./kesiswaan.controller').read.options(req, ['AKTIF', 'DIBATALKAN', 'SEMUA']);
  const scope = [];
  if (filters.student) scope.push({
    id: {
      [Op.in]: sequelize.literal(`(SELECT id_portofolio FROM peserta_portofolio WHERE id_siswa=${filters.student})`)
    }
  });
  if (filters.kelas) scope.push({
    id: {
      [Op.in]: sequelize.literal(`(SELECT pp.id_portofolio FROM peserta_portofolio pp JOIN riwayat_kelas_siswa r ON r.id_siswa=pp.id_siswa WHERE r.id_kelas=${filters.kelas} AND r.tanggal_mulai<=Portofolio.tanggal AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=Portofolio.tanggal))`)
    }
  });
  // Cocokkan judul, tim, tingkat, hasil, atau nama/NISN salah satu peserta.
  const search = q ? {
    [Op.or]: [{
      judul: {
        [Op.like]: q
      }
    }, {
      nama_tim: {
        [Op.like]: q
      }
    }, {
      tingkat_prestasi: {
        [Op.like]: q
      }
    }, {
      hasil_prestasi: {
        [Op.like]: q
      }
    }, {
      id: {
        [Op.in]: sequelize.literal(`(SELECT pp.id_portofolio FROM peserta_portofolio pp JOIN siswa s ON s.id=pp.id_siswa
      WHERE s.nama LIKE ${sequelize.escape(q)} OR s.nisn LIKE ${sequelize.escape(q)})`)
      }
    }]
  } : {};
  const rows = await models.portofolio.findAndCountAll({
    where: {
      jenis: 'PRESTASI',
      status_catatan: req.query.status === 'SEMUA' ? {
        [Op.in]: ['AKTIF', 'DIBATALKAN']
      } : req.query.status === 'DIBATALKAN' ? 'DIBATALKAN' : 'AKTIF',
      ...search,
      tanggal: {
        [Op.between]: [filters.start, filters.end]
      },
      [Op.and]: scope
    },
    order: [['tanggal', 'DESC'], ['id', 'DESC']],
    limit: 25,
    offset: (page - 1) * 25,
    include: [{
      model: models.peserta,
      as: 'peserta_id_portofolio',
      separate: true,
      include: [{
        model: models.siswa,
        as: 'siswa',
        attributes: ['id', 'nama', 'nisn']
      }]
    }, {
      model: models.lampiran,
      as: 'lampiran_id_portofolio',
      separate: true,
      attributes: ['id', 'nama_berkas', 'jenis_berkas']
    }]
  });
  res.json({
    data: rows.rows,
    meta: {
      total: rows.count,
      page,
      page_size: 25
    }
  });
};
exports.create = async (req, res) => {
  const body = req.body || {};
  if (!Array.isArray(body.peserta) || body.peserta.length < 1 || body.peserta.length > 100) throw invalid('Pilih 1 sampai 100 siswa.');
  const ids = [...new Set(body.peserta.map(id))];
  const data = {
    id_guru_pencatat: req.user.id,
    jenis: 'PRESTASI',
    judul: string(body.judul, 'Judul', 191),
    tanggal: date(body.tanggal, 'Tanggal prestasi'),
    deskripsi: string(body.deskripsi, 'Deskripsi', 20000, true),
    tingkat_prestasi: string(body.tingkat_prestasi, 'Tingkat prestasi', 191),
    hasil_prestasi: string(body.hasil_prestasi, 'Hasil prestasi', 191),
    nama_tim: string(body.nama_tim, 'Nama tim', 191, ids.length === 1)
  };
  const saved = await sequelize.transaction(async t => {
    if ((await models.siswa.count({
      where: {
        id: ids
      },
      transaction: t
    })) !== ids.length) throw invalid('Peserta tidak ditemukan.');
    const row = await models.portofolio.create(data, {
      transaction: t
    });
    await models.peserta.bulkCreate(ids.map(student => ({
      id_portofolio: row.id,
      id_siswa: student
    })), {
      transaction: t
    });
    await audit(req, 'portofolio', row.id, null, {
      ...row.toJSON(),
      peserta: ids.join(',')
    }, 'CATAT_PRESTASI', t);
    return row;
  });
  res.status(201).json({
    data: saved,
    meta: await recalculate(ids)
  });
};
exports.upload = async (req, res) => {
  const type = req.get('Content-Type')?.split(';')[0];
  if (!Object.hasOwn(accepted, type) || !Buffer.isBuffer(req.body) || req.body.length > 5 * 1024 * 1024 || !accepted[type](req.body)) throw invalid('Gunakan file PDF, JPEG, atau PNG yang valid.');
  let name;
  try {
    name = path.basename(decodeURIComponent(req.get('X-Filename') || 'bukti'));
  } catch {
    throw invalid('Nama berkas tidak valid.');
  }
  name = string(name, 'Nama berkas', 191);
  if (/[\x00-\x1f\x7f]/.test(name)) throw invalid('Nama berkas tidak valid.');
  const key = randomUUID();
  const file = path.join(directory, key);
  await fs.mkdir(directory, {
    recursive: true
  });
  await fs.writeFile(file, req.body, {
    flag: 'wx',
    mode: 0o600
  });
  let attachment;
  try {
    attachment = await sequelize.transaction(async t => {
      const item = await models.portofolio.findByPk(id(req.params.id), {
        transaction: t,
        lock: t.LOCK.UPDATE
      });
      if (!item || item.jenis !== 'PRESTASI') throw missing();
      if (req.authPlatform === 'mobile' && req.pembinaPortfolioId === item.id) {
        const day = require('./auth.controller').today();
        const assigned = await models.pembina.findOne({
          where: {
            id_guru: req.user.id,
            id_periode_ekstrakurikuler: item.id_periode_ekstrakurikuler,
            tanggal_mulai: {
              [Op.lte]: day
            },
            [Op.or]: [{
              tanggal_selesai: null
            }, {
              tanggal_selesai: {
                [Op.gte]: day
              }
            }]
          },
          transaction: t,
          lock: t.LOCK.UPDATE
        });
        if (!assigned || item.status_catatan !== 'AKTIF') throw require('../utils/api-error')(403, 'FORBIDDEN', 'Prestasi aktif dan penugasan Pembina diperlukan.');
      } else writable(item);
      const row = await models.lampiran.create({
        id_portofolio: item.id,
        nama_berkas: name,
        lokasi_berkas: key,
        jenis_berkas: type,
        waktu_unggah: new Date()
      }, {
        transaction: t
      });
      await audit(req, 'lampiran', row.id, null, {
        id_portofolio: item.id,
        nama_berkas: name
      }, 'UNGGAH_BUKTI', t);
      return row;
    });
  } catch (error) {
    await fs.unlink(file).catch(() => {});
    throw error;
  }
  res.status(201).json({
    data: {
      id: attachment.id,
      nama_berkas: name,
      jenis_berkas: type
    }
  });
};
exports.download = async (req, res, next) => {
  const row = await models.lampiran.findByPk(id(req.params.id));
  if (!row || !/^[a-f0-9-]{36}$/.test(row.lokasi_berkas)) throw missing();
  const item = await models.portofolio.findByPk(row.id_portofolio);
  if (item?.jenis !== 'PRESTASI') throw missing();
  try {
    await fs.access(path.join(directory, row.lokasi_berkas));
  } catch {
    throw missing();
  }
  res.set('X-Content-Type-Options', 'nosniff').set('Cache-Control', 'private, no-store').type(row.jenis_berkas);
  res.download(path.join(directory, row.lokasi_berkas), row.nama_berkas, error => {
    if (error) next(error);
  });
};
function writable(row) {
  if (row.id_periode_ekstrakurikuler != null) throw require('../utils/api-error')(403, 'FORBIDDEN', 'Prestasi ekstrakurikuler dikelola Pembina.');
  if (row.status_catatan !== 'AKTIF') throw require('../utils/api-error')(409, 'STATE_CONFLICT', 'Prestasi sudah dibatalkan dan hanya dapat dilihat.');
}
async function recalculate(ids) {
  try {
    const result = await require('../services/badges').reconcile({
      studentIds: ids
    });
    return {
      badge_recalculation: result.skipped ? 'pending' : 'complete'
    };
  } catch {
    return {
      badge_recalculation: 'pending'
    };
  } // Saved data is committed; periodic reconciliation retries safely.
}
exports.detail = async (req, res) => {
  const row = await models.portofolio.findByPk(id(req.params.id), {
    include: [{
      model: models.peserta,
      as: 'peserta_id_portofolio',
      include: [{
        model: models.siswa,
        as: 'siswa',
        attributes: ['id', 'nama', 'nisn']
      }]
    }, {
      model: models.lampiran,
      as: 'lampiran_id_portofolio',
      attributes: ['id', 'nama_berkas', 'jenis_berkas', 'waktu_unggah']
    }]
  });
  if (!row || row.jenis !== 'PRESTASI') throw missing();
  const history = await models.audit.findAll({
    where: {
      nama_tabel: 'portofolio',
      identitas_data: String(row.id)
    },
    attributes: ['id', 'id_guru', 'jenis_tindakan', 'waktu', 'alasan'],
    order: [['waktu', 'DESC']]
  });
  res.json({
    data: {
      ...row.toJSON(),
      editable: row.id_periode_ekstrakurikuler == null && row.status_catatan === 'AKTIF',
      history
    }
  });
};
exports.update = async (req, res) => {
  const b = req.body || {};
  if (!Array.isArray(b.peserta) || !b.peserta.length || b.peserta.length > 100) throw invalid('Pilih 1 sampai 100 siswa.');
  const ids = [...new Set(b.peserta.map(id))];
  const patch = {
    judul: string(b.judul, 'Judul', 191),
    tanggal: date(b.tanggal, 'Tanggal prestasi'),
    deskripsi: string(b.deskripsi, 'Deskripsi', 20000, true),
    tingkat_prestasi: string(b.tingkat_prestasi, 'Tingkat', 191),
    hasil_prestasi: string(b.hasil_prestasi, 'Hasil', 191),
    nama_tim: string(b.nama_tim, 'Nama tim', 191, ids.length === 1)
  };
  let affected = [];
  const result = await sequelize.transaction(async t => {
    const row = await models.portofolio.findByPk(id(req.params.id), {
      transaction: t,
      lock: t.LOCK.UPDATE
    });
    if (!row || row.jenis !== 'PRESTASI') throw missing();
    writable(row);
    if ((await models.siswa.count({
      where: {
        id: ids
      },
      transaction: t
    })) !== ids.length) throw invalid('Peserta tidak ditemukan.');
    const old = await models.peserta.findAll({
      where: {
        id_portofolio: row.id
      },
      transaction: t
    });
    affected = [...new Set([...ids, ...old.map(p => p.id_siswa)])];
    const before = {
      ...row.toJSON(),
      peserta: old.map(p => p.id_siswa).sort((a, b) => a - b).join(',')
    };
    await row.update(patch, {
      transaction: t
    });
    await models.peserta.destroy({
      where: {
        id_portofolio: row.id
      },
      transaction: t
    });
    await models.peserta.bulkCreate(ids.map(student => ({
      id_portofolio: row.id,
      id_siswa: student
    })), {
      transaction: t
    });
    await audit(req, 'portofolio', row.id, before, {
      ...row.toJSON(),
      peserta: [...ids].sort((a, b) => a - b).join(',')
    }, 'KOREKSI_PRESTASI', t);
    return row;
  });
  res.json({
    data: result,
    meta: await recalculate(affected)
  });
};
exports.cancel = async (req, res) => {
  const reason = string(req.body?.alasan_tindakan, 'Alasan pembatalan', 2000);
  let affected = [];
  const result = await sequelize.transaction(async t => {
    const row = await models.portofolio.findByPk(id(req.params.id), {
      transaction: t,
      lock: t.LOCK.UPDATE
    });
    if (!row || row.jenis !== 'PRESTASI') throw missing();
    writable(row);
    const before = row.toJSON();
    await row.update({
      status_catatan: 'DIBATALKAN'
    }, {
      transaction: t
    });
    affected = (await models.peserta.findAll({
      where: {
        id_portofolio: row.id
      },
      transaction: t
    })).map(p => p.id_siswa);
    await audit({
      ...req,
      body: {
        ...req.body,
        alasan_tindakan: reason
      }
    }, 'portofolio', row.id, before, row.toJSON(), 'BATALKAN_PRESTASI', t);
    return row;
  });
  res.json({
    data: result,
    meta: await recalculate(affected)
  });
};
exports.fileValidation = {
  accepted
};
