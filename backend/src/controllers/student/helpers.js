'use strict';
const { models } = require('../../models');
const fail = require('../../utils/api-error');

const ID_MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const ID_MONTHS_FULL = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const ID_DAYS = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

function ensureStudent(req) {
  if (req.user.kind !== 'siswa') {
    throw fail(403, 'FORBIDDEN', 'Fitur ini hanya dapat diakses oleh Siswa.');
  }
}

async function getStudentProfile(req) {
  const student = await models.siswa.findByPk(req.user.id);
  if (!student) throw fail(404, 'NOT_FOUND', 'Data siswa tidak ditemukan.');

  const rk = await models.riwayat_kelas.findOne({
    where: { id_siswa: req.user.id },
    order: [['id', 'DESC']],
  });
  const kelas = rk ? await models.kelas.findByPk(rk.id_kelas) : null;

  return {
    id: student.id,
    name: student.nama,
    nisn: student.nisn,
    nis: student.nis,
    classroom: kelas?.nama ?? null,
    photo_url: null,
  };
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

module.exports = {
  ID_MONTHS,
  ID_MONTHS_FULL,
  ID_DAYS,
  ensureStudent,
  getStudentProfile,
  jakartaDate,
  fmtTime,
  fmtDate,
  fmtDateLong,
};
