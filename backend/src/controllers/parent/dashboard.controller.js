'use strict';
const { Op } = require('sequelize');
const { models } = require('../../models');
const {
  ID_MONTHS_FULL,
  requireParent,
  jakartaDate,
  fmtTime,
  fmtDate,
  pointsFromHasil,
  resolveChildContext,
  getHomeroomTeacher,
} = require('./helpers');

exports.dashboard = async (req, res) => {
  requireParent(req);
  const { children, child } = await resolveChildContext(req);
  const today = jakartaDate();
  const [curYear, curMonth] = today.split('-').map(Number);
  const pad = (n) => String(n).padStart(2, '0');
  const lastDay = new Date(curYear, curMonth, 0).getDate();
  const startDate = `${curYear}-${pad(curMonth)}-01`;
  const endDate = `${curYear}-${pad(curMonth)}-${pad(lastDay)}`;
  const monthName = `${ID_MONTHS_FULL[curMonth - 1]} ${curYear}`;

  const unreadNotifs = await models.penerima.count({
    where: { id_orang_tua: req.user.id, waktu_dibaca: null },
  });

  if (!child) {
    return res.set('Cache-Control', 'no-store').json({
      data: {
        children: [],
        child: null,
        month_name: monthName,
        attendance_summary: {
          hadir: 0,
          izin: 0,
          terlambat: 0,
          alfa: 0,
          total_sessions: 0,
          rate_percentage: 0,
          predicate: 'Belum Ada Data',
        },
        points_summary: { total_points: 0, total_achievements: 0, earned_badges: 0, total_badges: 0 },
        discipline_summary: { active_cases: 0, status_label: '0 Pelanggaran • Tertib' },
        extracurricular_summary: { enrolled_count: 0 },
        recent_activity: null,
        homeroom_teacher: null,
        unread_notifications: unreadNotifs,
      },
    });
  }

  const monthSessions = await models.sesi.findAll({
    where: { tanggal: { [Op.between]: [startDate, endDate] } },
    order: [['tanggal', 'ASC']],
    raw: true,
  });
  const monthSessionIds = monthSessions.map((s) => s.id);
  const monthPresensi = monthSessionIds.length > 0
    ? await models.presensi.findAll({
        where: { id_siswa: child.id, id_sesi_presensi_sekolah: { [Op.in]: monthSessionIds } },
        raw: true,
      })
    : [];
  const bySession = new Map();
  for (const p of monthPresensi) bySession.set(p.id_sesi_presensi_sekolah, p);

  const stats = { hadir: 0, izin: 0, terlambat: 0, alfa: 0 };
  let countedSessions = 0;
  for (const s of monthSessions) {
    const p = bySession.get(s.id);
    const tgl = typeof s.tanggal === 'string' ? s.tanggal.slice(0, 10) : jakartaDate(s.tanggal);
    if (p) {
      countedSessions++;
      if (p.status_kehadiran === 'HADIR') stats.hadir++;
      else if (p.status_kehadiran === 'TERLAMBAT') stats.terlambat++;
      else if (p.status_kehadiran === 'IZIN' || p.status_kehadiran === 'SAKIT') stats.izin++;
      else if (p.status_kehadiran === 'ALFA') stats.alfa++;
    } else if (!(tgl === today && s.status !== 'DITUTUP')) {
      countedSessions++;
      stats.alfa++;
    }
  }
  const ratePercentage = countedSessions > 0
    ? Math.round(((stats.hadir + stats.terlambat) / countedSessions) * 1000) / 10
    : 0;
  const predicate = countedSessions === 0
    ? 'Belum Ada Data'
    : ratePercentage >= 90
      ? 'Sangat Baik'
      : ratePercentage >= 75
        ? 'Baik'
        : 'Perlu Perhatian';

  const participations = await models.peserta.findAll({
    where: { id_siswa: child.id },
    include: [{ model: models.portofolio, as: 'portofolio', required: true, where: { jenis: 'PRESTASI', status_catatan: 'AKTIF' } }],
  });
  let totalPoints = 0;
  for (const pp of participations) {
    totalPoints += pointsFromHasil(pp.portofolio?.hasil_prestasi);
  }

  const [totalBadges, earnedBadges, activeViolations, enrolledEkskul, latestPresensi, homeroomTeacher] =
    await Promise.all([
      models.level.count(),
      models.pencapaian.count({ where: { id_siswa: child.id, aktif: true } }),
      models.laporan.count({
        where: { id_siswa: child.id, status_tindak_lanjut: { [Op.notIn]: ['SELESAI', 'DIBATALKAN'] } },
      }),
      models.anggota.count({ where: { id_siswa: child.id } }),
      models.presensi.findOne({
        where: { id_siswa: child.id },
        include: [{ model: models.sesi, as: 'sesi_presensi_sekolah', required: true }],
        order: [['waktu_presensi', 'DESC'], ['id', 'DESC']],
      }),
      getHomeroomTeacher(child.classroom_id),
    ]);

  let recentActivity = null;
  if (latestPresensi) {
    const s = latestPresensi.sesi_presensi_sekolah;
    const statusLabel = latestPresensi.status_kehadiran === 'HADIR'
      ? 'Tercatat hadir tepat waktu'
      : latestPresensi.status_kehadiran === 'TERLAMBAT'
        ? 'Tercatat terlambat'
        : `Status: ${latestPresensi.status_kehadiran}`;
    recentActivity = {
      title: s.jenis_sesi === 'ZUHUR' ? 'Presensi Salat Zuhur' : 'Gerbang Masuk SMAN 12',
      description: `${statusLabel}${latestPresensi.keterangan ? ` • ${latestPresensi.keterangan}` : ''}`,
      time: fmtTime(latestPresensi.waktu_presensi),
      date: fmtDate(s.tanggal),
      status: latestPresensi.status_kehadiran,
    };
  }

  res.set('Cache-Control', 'no-store').json({
    data: {
      children,
      child,
      month_name: monthName,
      attendance_summary: {
        hadir: stats.hadir,
        izin: stats.izin,
        terlambat: stats.terlambat,
        alfa: stats.alfa,
        total_sessions: countedSessions,
        rate_percentage: ratePercentage,
        predicate,
      },
      points_summary: {
        total_points: totalPoints,
        total_achievements: participations.length,
        earned_badges: earnedBadges,
        total_badges: totalBadges,
      },
      discipline_summary: {
        active_cases: activeViolations,
        status_label: activeViolations === 0
          ? '0 Pelanggaran • Tertib'
          : `${activeViolations} Pelanggaran Aktif`,
      },
      extracurricular_summary: {
        enrolled_count: enrolledEkskul,
      },
      recent_activity: recentActivity,
      homeroom_teacher: homeroomTeacher,
      unread_notifications: unreadNotifs,
    },
  });
};
