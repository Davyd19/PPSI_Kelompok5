const {
  Op
} = require('sequelize');
const {
  models,
  schema
} = require('../models');
const fail = require('../utils/api-error');
const {
  today
} = require('../controllers/auth.controller');
const editable = ['guru', 'siswa', 'orang_tua', 'guru_peran', 'hubungan', 'tahun', 'semester', 'kelas', 'riwayat_kelas', 'wali', 'badge', 'versi_badge', 'level', 'ekskul', 'periode_ekskul', 'pembina'];
const temporal = {
  guru_peran: ['id_guru', 'id_peran'],
  hubungan: ['id_orang_tua', 'id_siswa'],
  riwayat_kelas: ['id_siswa'],
  wali: ['id_kelas'],
  pembina: ['id_guru', 'id_periode_ekstrakurikuler']
};
const invalid = (message, details) => fail(422, 'VALIDATION_ERROR', message, details);
function clean(key, body, creating) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw invalid('Data formulir tidak valid.');
  const data = {};
  const errors = {};
  const allowed = new Set(schema[key].fields.filter(f => !f.private).map(f => f.name));
  allowed.add('kata_sandi');
  for (const n of Object.keys(body)) if (!allowed.has(n)) errors[n] = 'Atribut tidak dapat diubah.';
  for (const f of schema[key].fields.filter(f => !f.private)) {
    if (!(f.name in body)) {
      if (creating && !f.nullable) errors[f.name] = 'Wajib diisi.';
      continue;
    }
    let v = body[f.name];
    if (typeof v === 'string') v = v.trim();
    if (v === '' || v === null) {
      if (!f.nullable) errors[f.name] = 'Wajib diisi.';
      data[f.name] = null;
      continue;
    }
    if (f.type === 'id' || f.type === 'integer') {
      v = Number(v);
      if (!Number.isSafeInteger(v) || f.type === 'id' && v < 1) errors[f.name] = 'Harus berupa angka bulat yang sah.';
    } else if (f.type === 'boolean') {
      if (![true, false, 0, 1, '0', '1'].includes(v)) errors[f.name] = 'Pilihan tidak sah.';
      v = v === true || v === 1 || v === '1';
    } else {
      if (typeof v !== 'string') errors[f.name] = 'Format tidak sah.';else if (v.length > (f.type === 'text' ? 16000 : 191)) errors[f.name] = 'Teks terlalu panjang.';
    }
    if (f.type === 'date' && (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v) || Number.isNaN(Date.parse(v)) || new Date(v).toISOString().slice(0, 10) !== v)) errors[f.name] = 'Tanggal tidak sah.';
    if (f.type === 'datetime' && (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(v) || Number.isNaN(Date.parse(v)))) errors[f.name] = 'Tanggal dan waktu harus berupa ISO 8601.';
    if (f.options && !f.options.includes(v)) errors[f.name] = 'Pilihan tidak sah.';
    if (f.name === 'identitas_login') {
      v = String(v).toLowerCase();
      if (!/^[a-z0-9][a-z0-9._@+-]{2,190}$/.test(v)) errors[f.name] = 'Gunakan minimal 3 karakter: huruf, angka, titik, @, +, -, atau garis bawah.';
    }
    if (f.name === 'nisn' && !/^\d{10}$/.test(v)) errors[f.name] = 'NISN harus 10 digit.';
    if (f.name === 'nis' && !/^\d+$/.test(v)) errors[f.name] = 'NIS harus berupa angka.';
    if (f.name === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)) errors[f.name] = 'Email tidak sah.';
    data[f.name] = v;
  }
  if (Object.keys(errors).length) throw invalid('Periksa kembali isian formulir.', errors);
  return data;
}
async function validate(key, data, id, t) {
  const opts = {
    transaction: t
  };
  const spec = schema[key];
  for (const f of spec.fields.filter(f => f.ref && data[f.name] != null)) if (!(await models[f.ref].findByPk(data[f.name], opts))) throw invalid(`${f.label} tidak ditemukan.`, {
    [f.name]: 'Pilihan tidak ditemukan.'
  });
  if (data.tanggal_mulai && data.tanggal_selesai && data.tanggal_selesai < data.tanggal_mulai) throw invalid('Tanggal selesai tidak boleh mendahului tanggal mulai.');
  if (['guru', 'siswa', 'orang_tua'].includes(key)) for (const k of ['guru', 'siswa', 'orang_tua']) if (await models[k].findOne({
    where: {
      identitas_login: data.identitas_login,
      ...(k === key && id ? {
        id: {
          [Op.ne]: id
        }
      } : {})
    },
    ...opts
  })) throw fail(409, 'DUPLICATE_LOGIN', 'Identitas login sudah digunakan.');
  const fields = temporal[key];
  if (fields) {
    const w = Object.fromEntries(fields.map(f => [f, data[f]]));
    if (id) w.id = {
      [Op.ne]: id
    };
    w.tanggal_mulai = {
      [Op.lte]: data.tanggal_selesai || '9999-12-31'
    };
    w[Op.or] = [{
      tanggal_selesai: null
    }, {
      tanggal_selesai: {
        [Op.gte]: data.tanggal_mulai
      }
    }];
    if (await models[key].findOne({
      where: w,
      ...opts
    })) throw fail(409, 'OVERLAPPING_PERIOD', 'Masa berlaku bertumpuk dengan data yang sudah ada.');
  }
  if (key === 'tahun') {
    const where = {
      ...(id ? {
        id: {
          [Op.ne]: id
        }
      } : {}),
      tanggal_mulai: {
        [Op.lte]: data.tanggal_selesai
      },
      tanggal_selesai: {
        [Op.gte]: data.tanggal_mulai
      }
    };
    if (await models.tahun.findOne({
      where,
      ...opts
    })) throw invalid('Rentang tahun ajaran bertumpuk.');
    if (id) {
      const semesters = await models.semester.findAll({
        where: {
          id_tahun_ajaran: id
        },
        ...opts
      });
      const classes = await models.kelas.findAll({
        where: {
          id_tahun_ajaran: id
        },
        ...opts
      });
      for (const s of semesters) if (s.tanggal_mulai < data.tanggal_mulai || s.tanggal_selesai > data.tanggal_selesai) throw invalid('Rentang tahun ajaran harus mencakup seluruh semester yang sudah dibuat.');
      for (const k of classes) for (const r of ['riwayat_kelas', 'wali']) {
        const rows = await models[r].findAll({
          where: {
            id_kelas: k.id
          },
          ...opts
        });
        if (rows.some(x => x.tanggal_mulai < data.tanggal_mulai || x.tanggal_selesai && x.tanggal_selesai > data.tanggal_selesai)) throw invalid('Rentang tahun ajaran harus mencakup riwayat kelas dan penugasan.');
      }
    }
  }
  if (['semester', 'riwayat_kelas', 'wali'].includes(key)) {
    const tahun = key === 'semester' ? await models.tahun.findByPk(data.id_tahun_ajaran, opts) : await models.tahun.findByPk((await models.kelas.findByPk(data.id_kelas, opts)).id_tahun_ajaran, opts);
    if (data.tanggal_mulai < tahun.tanggal_mulai || data.tanggal_mulai > tahun.tanggal_selesai || data.tanggal_selesai && data.tanggal_selesai > tahun.tanggal_selesai) throw invalid('Masa berlaku harus berada dalam tahun ajaran kelas/semester.');
    if (key === 'semester') if (await models.semester.findOne({
      where: {
        id_tahun_ajaran: data.id_tahun_ajaran,
        ...(id ? {
          id: {
            [Op.ne]: id
          }
        } : {}),
        tanggal_mulai: {
          [Op.lte]: data.tanggal_selesai
        },
        tanggal_selesai: {
          [Op.gte]: data.tanggal_mulai
        }
      },
      ...opts
    })) throw invalid('Rentang semester bertumpuk.');
  }
  if (key === 'guru_peran' || key === 'wali' || key === 'pembina') {
    const guru = await models.guru.findByPk(data.id_guru, opts);
    if (guru.status_akun !== 'AKTIF') throw invalid('Penugasan/peran hanya diberikan kepada guru aktif.');
  }
  if (key === 'hubungan') if (data.tanggal_selesai && data.tanggal_selesai < today() && data.tanggal_mulai > today()) throw invalid('Rentang hubungan tidak sah.');
  if (key === 'periode_ekskul') {
    if (data.kapasitas != null && data.kapasitas < 1) throw invalid('Kapasitas minimal 1.');
    if (data.pendaftaran_mulai && data.pendaftaran_selesai && data.pendaftaran_selesai < data.pendaftaran_mulai) throw invalid('Jendela pendaftaran tidak sah.');
  }
  if (key === 'versi_badge') {
    if (data.nomor_versi < 1) throw invalid('Nomor versi minimal 1.');
    const start = await models.semester.findByPk(data.id_semester_mulai, opts);
    const end = data.id_semester_selesai ? await models.semester.findByPk(data.id_semester_selesai, opts) : null;
    if (end && end.tanggal_selesai < start.tanggal_mulai) throw invalid('Semester akhir mendahului semester awal.');
    const previous = await models.versi_badge.findAll({
      where: {
        id_badge: data.id_badge,
        ...(id ? {
          id: {
            [Op.ne]: id
          }
        } : {})
      },
      ...opts
    });
    for (const v of previous) {
      const a = await models.semester.findByPk(v.id_semester_mulai, opts),
        b = v.id_semester_selesai ? await models.semester.findByPk(v.id_semester_selesai, opts) : null;
      if (start.tanggal_mulai <= (b?.tanggal_selesai || '9999-12-31') && (end?.tanggal_selesai || '9999-12-31') >= a.tanggal_mulai) throw invalid('Rentang versi badge bertumpuk. Akhiri versi lama terlebih dahulu pada semester yang sesuai.');
    }
    if (!id && previous.length && start.tanggal_mulai <= today()) throw invalid('Versi berikutnya harus mulai pada semester mendatang.');
  }
  if (key === 'level') {
    if (data.target < 1 || data.urutan < 1) throw invalid('Target dan urutan level minimal 1.');
    if (data.sumber_data === 'PRESENSI_SEKOLAH' && !data.jenis_presensi) throw invalid('Pilih jenis presensi sekolah.');
    if (data.sumber_data === 'PRESENSI_EKSKUL' && data.jenis_presensi) throw invalid('Jenis presensi harus kosong untuk sumber ekskul.');
    if (!data.status_kehadiran_yang_dihitung) throw invalid('Pilih status kehadiran yang dihitung.');
  }
}
module.exports = {
  editable,
  clean,
  validate,
  invalid
};
