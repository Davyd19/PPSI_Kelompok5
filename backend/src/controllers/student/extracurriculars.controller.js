'use strict';
const { Op } = require('sequelize');
const { models } = require('../../models');
const fail = require('../../utils/api-error');
const { ensureStudent } = require('./helpers');

exports.extracurriculars = async (req, res) => {
  ensureStudent(req);

  const periods = await models.periode_ekskul.findAll({
    where: { status_kegiatan: { [Op.in]: ['AKTIF', 'BERJALAN'] } },
    include: [{ model: models.ekskul, as: 'ekstrakurikuler', required: true }],
    order: [['id', 'ASC']],
  });

  if (periods.length === 0) {
    return res.set('Cache-Control', 'no-store').json({
      data: { summary: { enrolled_count: 0, academic_year: '-' }, categories: [], items: [] },
    });
  }

  const memberships = await models.anggota.findAll({ where: { id_siswa: req.user.id } });
  const memberPeriodIds = new Set(memberships.map((m) => m.id_periode_ekstrakurikuler));

  const pendingRegs = await models.pendaftaran.findAll({
    where: { id_siswa: req.user.id, status_keputusan: 'MENUNGGU' },
  });
  const pendingPeriodIds = new Set(pendingRegs.map((r) => r.id_periode_ekstrakurikuler));

  const coaches = await models.pembina.findAll({
    where: { id_periode_ekstrakurikuler: { [Op.in]: periods.map((p) => p.id) }, tanggal_selesai: null },
    include: [{ model: models.guru, as: 'guru', required: false }],
  });
  const coachByPeriod = {};
  for (const c of coaches) {
    if (!coachByPeriod[c.id_periode_ekstrakurikuler]) {
      coachByPeriod[c.id_periode_ekstrakurikuler] = c.guru?.nama ?? null;
    }
  }

  const tahun = await models.tahun.findOne({ where: { aktif: true } });

  const categoryColors = {
    Kepemimpinan: '#0D9488',
    Olahraga: '#F97316',
    'Sains & TI': '#0284C7',
    'Seni & Budaya': '#8B5CF6',
    Kemanusiaan: '#EF4444',
    Kepanduan: '#10B981',
  };

  const items = periods.map((p) => {
    const ekskul = p.ekstrakurikuler;
    const isEnrolled = memberPeriodIds.has(p.id);
    const isPending = pendingPeriodIds.has(p.id);

    const enrolled = memberships.filter((m) => m.id_periode_ekstrakurikuler === p.id).length;
    const remaining = p.kapasitas != null ? Math.max(0, p.kapasitas - enrolled) : null;

    const tag = isEnrolled
      ? 'Terdaftar'
      : isPending
        ? 'Menunggu Persetujuan'
        : remaining === 0
          ? 'Penuh'
          : remaining != null
            ? `Sisa ${remaining} Kursi`
            : 'Terbuka';

    return {
      id: p.id,
      ekskul_id: ekskul.id,
      name: ekskul.nama,
      category: ekskul.status ?? 'Umum',
      description: ekskul.deskripsi ?? '',
      schedule: null,
      coach: coachByPeriod[p.id] ?? null,
      is_enrolled: isEnrolled,
      is_pending: isPending,
      status: tag,
      tag,
      remaining_seats: remaining,
      capacity: p.kapasitas ?? null,
      registration_open: p.status_pendaftaran === 'BUKA',
      category_color: categoryColors[ekskul.status] ?? '#64748B',
    };
  });

  const categories = ['Semua', 'Diikuti', ...new Set(items.map((i) => i.category).filter(Boolean))];

  res.set('Cache-Control', 'no-store').json({
    data: {
      summary: {
        enrolled_count: memberPeriodIds.size,
        academic_year: tahun?.nama ?? '-',
      },
      categories,
      items,
    },
  });
};

exports.extracurricularDetail = async (req, res) => {
  ensureStudent(req);
  const periodeId = parseInt(req.params.id, 10);

  const period = await models.periode_ekskul.findByPk(periodeId, {
    include: [{ model: models.ekskul, as: 'ekstrakurikuler', required: true }],
  });
  if (!period) throw fail(404, 'NOT_FOUND', 'Ekstrakurikuler tidak ditemukan.');

  const ekskul = period.ekstrakurikuler;
  const memberships = await models.anggota.count({ where: { id_periode_ekstrakurikuler: periodeId } });
  const myMembership = await models.anggota.findOne({
    where: { id_siswa: req.user.id, id_periode_ekstrakurikuler: periodeId },
  });
  const myPending = await models.pendaftaran.findOne({
    where: { id_siswa: req.user.id, id_periode_ekstrakurikuler: periodeId, status_keputusan: 'MENUNGGU' },
  });

  const coach = await models.pembina.findOne({
    where: { id_periode_ekstrakurikuler: periodeId, tanggal_selesai: null },
    include: [{ model: models.guru, as: 'guru', required: false }],
  });

  const remaining = period.kapasitas != null ? Math.max(0, period.kapasitas - memberships) : null;
  const regStatus = myMembership
    ? 'Sudah Terdaftar'
    : myPending
      ? 'Menunggu Persetujuan'
      : period.status_pendaftaran === 'BUKA'
        ? 'Pendaftaran Terbuka'
        : 'Pendaftaran Tutup';

  res.set('Cache-Control', 'no-store').json({
    data: {
      id: periodeId,
      ekskul_id: ekskul.id,
      title: ekskul.nama,
      subtitle: ekskul.nama,
      school: 'SMAN 12 Padang',
      category: ekskul.status ?? 'Umum',
      coach: coach?.guru?.nama ? `${coach.guru.nama} • Pembina Ekskul` : null,
      stats: {
        active_students: period.kapasitas ? `${memberships} / ${period.kapasitas} Siswa Aktif` : `${memberships} Siswa`,
        track: 'Peminatan',
        accreditation: null,
      },
      description: ekskul.deskripsi ?? null,
      schedule_place: { days_time: null, location: null },
      requirements: [
        'Siswa/i aktif SMAN 12 Padang.',
        'Komitmen presensi minimal 80% per semester.',
      ],
      remaining_quota: remaining,
      registration_status: regStatus,
      is_registered: !!myMembership,
      is_pending: !!myPending,
    },
  });
};

exports.registerExtracurricular = async (req, res) => {
  ensureStudent(req);
  const periodeId = parseInt(req.params.id, 10);

  const period = await models.periode_ekskul.findByPk(periodeId);
  if (!period) throw fail(404, 'NOT_FOUND', 'Ekstrakurikuler tidak ditemukan.');

  if (period.status_pendaftaran !== 'BUKA') {
    throw fail(422, 'REG_CLOSED', 'Pendaftaran ekstrakurikuler ini saat ini tidak dibuka.');
  }

  const existing = await models.anggota.findOne({
    where: { id_siswa: req.user.id, id_periode_ekstrakurikuler: periodeId },
  });
  if (existing) throw fail(409, 'ALREADY_ENROLLED', 'Anda sudah terdaftar di ekstrakurikuler ini.');

  const pending = await models.pendaftaran.findOne({
    where: { id_siswa: req.user.id, id_periode_ekstrakurikuler: periodeId, status_keputusan: 'MENUNGGU' },
  });
  if (pending) throw fail(409, 'ALREADY_PENDING', 'Pengajuan Anda sedang menunggu persetujuan.');

  await models.pendaftaran.create({
    id_siswa: req.user.id,
    id_periode_ekstrakurikuler: periodeId,
    tanggal_daftar: new Date(),
    status_keputusan: 'MENUNGGU',
  });

  res.set('Cache-Control', 'no-store').json({
    data: {
      status: 'success',
      message: 'Pendaftaran Berhasil Diajukan',
      description: 'Pengajuan pendaftaran telah diterima dan menunggu persetujuan Pembina.',
      status_keputusan: 'MENUNGGU',
    },
  });
};
