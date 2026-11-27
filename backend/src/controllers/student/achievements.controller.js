'use strict';
const { models } = require('../../models');
const fail = require('../../utils/api-error');
const { ensureStudent, jakartaDate, fmtDate } = require('./helpers');

exports.achievements = async (req, res) => {
  ensureStudent(req);

  const participations = await models.peserta.findAll({
    where: { id_siswa: req.user.id },
    include: [
      {
        model: models.portofolio,
        as: 'portofolio',
        required: true,
        where: { jenis: 'PRESTASI', status_catatan: 'AKTIF' },
        include: [{ model: models.guru, as: 'guru_pencatat', required: false }],
      },
    ],
    order: [[{ model: models.portofolio, as: 'portofolio' }, 'tanggal', 'DESC']],
  });

  if (participations.length === 0) {
    return res.set('Cache-Control', 'no-store').json({
      data: {
        summary: { total_achievements: 0, total_points: 0 },
        categories: ['Semua'],
        groups: [],
      },
    });
  }

  function pointsFromHasil(h) {
    if (!h) return 30;
    const hl = h.toLowerCase();
    if (hl.includes('1') || hl.includes('pertama') || hl.includes('emas') || hl.includes('juara 1')) return 45;
    if (hl.includes('2') || hl.includes('kedua') || hl.includes('perak') || hl.includes('juara 2')) return 40;
    if (hl.includes('3') || hl.includes('ketiga') || hl.includes('perunggu') || hl.includes('juara 3')) return 35;
    return 30;
  }

  let totalPoints = 0;
  const groupsMap = {};
  const categorySet = new Set();

  for (const pp of participations) {
    const port = pp.portofolio;
    const pts = pointsFromHasil(port.hasil_prestasi);
    totalPoints += pts;

    const [portYear, portMonth] = jakartaDate(port.tanggal ?? new Date()).split('-').map(Number);
    const ayStart = portMonth >= 8 ? portYear : portYear - 1;
    const ayLabel = `${ayStart} / ${ayStart + 1}`;

    const category = port.tingkat_prestasi ?? 'Umum';
    categorySet.add(category);

    if (!groupsMap[ayLabel]) groupsMap[ayLabel] = [];
    groupsMap[ayLabel].push({
      id: port.id,
      title: port.judul,
      category,
      reward_points: `+${pts} Poin`,
      date: fmtDate(port.tanggal),
      verified: true,
      attachment_name: null,
    });
  }

  const groups = Object.entries(groupsMap)
    .sort(([a], [b]) => b.localeCompare(a))
    .map(([academic_year, items]) => ({ academic_year, items }));

  res.set('Cache-Control', 'no-store').json({
    data: {
      summary: { total_achievements: participations.length, total_points: totalPoints },
      categories: ['Semua', ...categorySet],
      groups,
    },
  });
};

exports.submitAchievement = async (req, res) => {
  ensureStudent(req);
  const { judul, deskripsi, tingkat_prestasi, hasil_prestasi, tanggal } = req.body ?? {};
  if (!judul) throw fail(422, 'VALIDATION_ERROR', 'Judul prestasi wajib diisi.');

  const guru = await models.guru.findOne({ where: { status_akun: 'AKTIF' }, order: [['id', 'ASC']] });
  if (!guru) throw fail(503, 'NO_STAFF', 'Tidak ada staf aktif untuk mencatat pengajuan.');

  const port = await models.portofolio.create({
    id_guru_pencatat: guru.id,
    jenis: 'PRESTASI',
    judul,
    tanggal: tanggal ? new Date(tanggal) : new Date(),
    deskripsi: deskripsi ?? null,
    tingkat_prestasi: tingkat_prestasi ?? null,
    hasil_prestasi: hasil_prestasi ?? null,
  });

  await models.peserta.create({ id_portofolio: port.id, id_siswa: req.user.id });

  res.set('Cache-Control', 'no-store').json({
    data: {
      status: 'success',
      message: 'Berkas Prestasi Berhasil Diajukan',
      description: 'Berkas prestasi telah diterima dan sedang dalam antrean verifikasi Kesiswaan.',
      portofolio_id: port.id,
    },
  });
};
