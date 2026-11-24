'use strict';
const { Op } = require('sequelize');
const { models } = require('../../models');
const {
  ensureStudent,
  getStudentProfile,
  jakartaDate,
  fmtTime,
  fmtDate,
} = require('./helpers');

exports.dashboard = async (req, res) => {
  ensureStudent(req);
  const studentProfile = await getStudentProfile(req);
  const today = jakartaDate();

  const semester = await models.semester.findOne({
    where: { tanggal_mulai: { [Op.lte]: today }, tanggal_selesai: { [Op.gte]: today } },
    order: [['tanggal_mulai', 'DESC']],
  });

  let stats = { hadir: 0, telat: 0, izin: 0, alfa: 0 };
  let todayPresensi = null;
  let weeklyGrid = [];

  if (semester) {
    const rows = await models.presensi.findAll({
      where: { id_siswa: req.user.id },
      include: [
        {
          model: models.sesi,
          as: 'sesi_presensi_sekolah',
          required: true,
          where: { id_semester: semester.id },
        },
      ],
    });

    for (const r of rows) {
      const st = r.status_kehadiran;
      if (st === 'HADIR') stats.hadir++;
      else if (st === 'TERLAMBAT') stats.telat++;
      else if (st === 'IZIN' || st === 'SAKIT') stats.izin++;
      else stats.alfa++;
    }

    const todaySesi = await models.sesi.findOne({ where: { tanggal: today } });
    if (todaySesi) {
      todayPresensi = await models.presensi.findOne({
        where: { id_siswa: req.user.id, id_sesi_presensi_sekolah: todaySesi.id },
      });
    }

    const [ty, tm, td] = today.split('-').map(Number);
    const nowJkt = new Date(Date.UTC(ty, tm - 1, td));
    const dayOfWeek = nowJkt.getUTCDay();
    const mondayOffset = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
    for (let i = 0; i < 5; i++) {
      const d = new Date(Date.UTC(ty, tm - 1, td + mondayOffset + i));
      const dStr = jakartaDate(d);
      const s = await models.sesi.findOne({ where: { tanggal: dStr } });
      let status = null;
      if (s) {
        const p = await models.presensi.findOne({
          where: { id_siswa: req.user.id, id_sesi_presensi_sekolah: s.id },
        });
        status = p?.status_kehadiran ?? null;
      }
      weeklyGrid.push({ day: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum'][i], status, date: dStr });
    }
  }

  const allP = await models.presensi.findAll({
    where: { id_siswa: req.user.id, status_kehadiran: { [Op.in]: ['HADIR', 'TERLAMBAT'] } },
    order: [['id', 'DESC']],
    limit: 60,
  });
  const streakDays = allP.length;

  const participations = await models.peserta.findAll({ where: { id_siswa: req.user.id } });
  const portIds = participations.map((p) => p.id_portofolio);
  let totalPoints = 0;
  if (portIds.length > 0) {
    const ports = await models.portofolio.findAll({ where: { id: { [Op.in]: portIds } } });
    for (const p of ports) {
      if (p.jenis === 'PRESTASI') {
        const h = p.hasil_prestasi;
        if (h?.includes('1') || h?.toLowerCase().includes('juara 1') || h?.toLowerCase().includes('emas')) totalPoints += 45;
        else if (h?.includes('2') || h?.toLowerCase().includes('juara 2') || h?.toLowerCase().includes('perak')) totalPoints += 40;
        else if (h?.includes('3') || h?.toLowerCase().includes('juara 3') || h?.toLowerCase().includes('perunggu')) totalPoints += 35;
        else totalPoints += 30;
      }
    }
  }

  const activeCases = await models.laporan.findAll({
    where: { id_siswa: req.user.id, status_tindak_lanjut: { [Op.notIn]: ['SELESAI', 'DIBATALKAN'] } },
  });

  const unreadNotifs = await models.penerima.count({
    where: { id_siswa: req.user.id, waktu_dibaca: null },
  });

  const recentPorts = await models.peserta.findAll({
    where: { id_siswa: req.user.id },
    order: [['id', 'DESC']],
    limit: 2,
    include: [{ model: models.portofolio, as: 'portofolio', required: true }],
  });

  const recentActivities = recentPorts.map((pp, i) => {
    const port = pp.portofolio;
    return {
      id: i + 1,
      type: 'achievement',
      category: 'VERIFIKASI PRESTASI',
      category_color: '#0D9488',
      accent_color: '#34D399',
      title: port.judul,
      time_ago: fmtDate(port.tanggal),
      subtitle_prefix: port.tingkat_prestasi ?? '',
      highlight_text: '+Poin',
      highlight_color: '#059669',
      icon: 'military_tech',
    };
  });

  res.set('Cache-Control', 'no-store').json({
    data: {
      student: studentProfile,
      attendance_summary: {
        on_time_days: streakDays,
        today: todayPresensi
          ? {
              status: todayPresensi.status_kehadiran,
              time: fmtTime(todayPresensi.waktu_presensi),
              is_on_time: todayPresensi.status_kehadiran === 'HADIR',
              session: 'Pagi',
              tolerance_limit: '07:00 WIB',
            }
          : null,
        weekly_grid: weeklyGrid,
      },
      metrics: {
        appreciation_points: totalPoints,
        points_predicate: totalPoints >= 100 ? 'Sangat Baik' : totalPoints >= 50 ? 'Baik' : 'Cukup',
        violation_cases: activeCases.length,
        discipline_status: activeCases.length === 0 ? 'Bersih' : `${activeCases.length} Kasus Aktif`,
      },
      recent_activities: recentActivities,
      unread_notifications: unreadNotifs,
    },
  });
};
