'use strict';
const { Op } = require('sequelize');
const { models } = require('../../models');
const fail = require('../../utils/api-error');

const ID_MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const ID_MONTHS_FULL = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const ID_DAYS = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

function requireParent(req) {
  if (req.user.kind !== 'orang_tua') {
    throw fail(403, 'FORBIDDEN', 'Fitur ini hanya dapat diakses oleh Orang Tua / Wali Siswa.');
  }
}

function jakartaDate(d = new Date()) {
  if (typeof d === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(d)) return d;
  const dt = d instanceof Date ? d : new Date(d);
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(dt);
}

function fmtTime(d) {
  if (!d) return null;
  const dt = new Date(d);
  const hhmm = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Jakarta',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(dt);
  return `${hhmm} WIB`;
}

function fmtDate(d) {
  if (!d) return null;
  const [y, m, day] = jakartaDate(d).split('-').map(Number);
  return `${day} ${ID_MONTHS[m - 1]} ${y}`;
}

function fmtDateLong(d) {
  if (!d) return null;
  const [y, m, day] = jakartaDate(d).split('-').map(Number);
  const dow = new Date(Date.UTC(y, m - 1, day)).getUTCDay();
  return `${ID_DAYS[dow]}, ${day} ${ID_MONTHS[m - 1]} ${y}`;
}

function pointsFromHasil(h) {
  if (!h) return 30;
  const hl = h.toLowerCase();
  if (hl.includes('1') || hl.includes('pertama') || hl.includes('emas') || hl.includes('juara 1')) return 45;
  if (hl.includes('2') || hl.includes('kedua') || hl.includes('perak') || hl.includes('juara 2')) return 40;
  if (hl.includes('3') || hl.includes('ketiga') || hl.includes('perunggu') || hl.includes('juara 3')) return 35;
  return 30;
}

async function resolveChildContext(req) {
  const today = jakartaDate();
  const links = await models.hubungan.findAll({
    where: {
      id_orang_tua: req.user.id,
      tanggal_mulai: { [Op.lte]: today },
      [Op.or]: [{ tanggal_selesai: null }, { tanggal_selesai: { [Op.gte]: today } }],
    },
    include: [{ model: models.siswa, as: 'siswa', required: true }],
    order: [['id', 'ASC']],
  });

  const activeYear = await models.tahun.findOne({ where: { aktif: true } });

  const children = [];
  for (const link of links) {
    const st = link.siswa;
    const rk = await models.riwayat_kelas.findOne({
      where: { id_siswa: st.id },
      order: [['id', 'DESC']],
    });
    const kelas = rk ? await models.kelas.findByPk(rk.id_kelas) : null;
    children.push({
      id: st.id,
      name: st.nama,
      nis: st.nis ?? null,
      nisn: st.nisn ?? null,
      classroom: kelas?.nama ?? null,
      classroom_id: kelas?.id ?? null,
      relation: link.jenis_hubungan ?? 'WALI',
      academic_year: activeYear?.nama ?? null,
      status: st.status_siswa ?? 'AKTIF',
    });
  }

  const requestedId = req.query.child_id ? parseInt(req.query.child_id, 10) : null;
  let child = children[0] ?? null;
  if (requestedId) {
    const match = children.find((c) => c.id === requestedId);
    if (!match) {
      throw fail(403, 'FORBIDDEN', 'Anda tidak memiliki akses ke data siswa tersebut.');
    }
    child = match;
  }

  return { children, child };
}

async function getHomeroomTeacher(classroomId) {
  if (!classroomId) return null;
  const today = jakartaDate();
  const wali = await models.wali.findOne({
    where: {
      id_kelas: classroomId,
      tanggal_mulai: { [Op.lte]: today },
      [Op.or]: [{ tanggal_selesai: null }, { tanggal_selesai: { [Op.gte]: today } }],
    },
    include: [{ model: models.guru, as: 'guru', required: true }],
    order: [['id', 'DESC']],
  });
  if (!wali?.guru) return null;
  return {
    name: wali.guru.nama,
    telepon: wali.guru.telepon ?? null,
    email: wali.guru.email ?? null,
  };
}

module.exports = {
  ID_MONTHS,
  ID_MONTHS_FULL,
  ID_DAYS,
  requireParent,
  jakartaDate,
  fmtTime,
  fmtDate,
  fmtDateLong,
  pointsFromHasil,
  resolveChildContext,
  getHomeroomTeacher,
};
