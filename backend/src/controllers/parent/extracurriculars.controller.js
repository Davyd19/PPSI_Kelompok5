'use strict';
const { Op } = require('sequelize');
const { models } = require('../../models');
const { requireParent, jakartaDate, fmtDateLong, resolveChildContext } = require('./helpers');

exports.extracurriculars = async (req, res) => {
  requireParent(req);
  const { children, child } = await resolveChildContext(req);
  const today = jakartaDate();
  const [activeYear, activeSemester] = await Promise.all([
    models.tahun.findOne({ where: { aktif: true } }),
    models.semester.findOne({
      where: { tanggal_mulai: { [Op.lte]: today }, tanggal_selesai: { [Op.gte]: today } },
      order: [['tanggal_mulai', 'DESC']],
    }),
  ]);

  if (!child) {
    return res.set('Cache-Control', 'no-store').json({
      data: {
        children: [],
        child: null,
        summary: {
          enrolled_count: 0,
          average_attendance_rate: 0,
          academic_year: activeYear?.nama ?? '-',
          semester_name: activeSemester?.nama ?? '',
        },
        items: [],
      },
    });
  }

  const memberships = await models.anggota.findAll({
    where: { id_siswa: child.id },
    include: [
      {
        model: models.periode_ekskul,
        as: 'periode_ekstrakurikuler',
        required: true,
        include: [{ model: models.ekskul, as: 'ekstrakurikuler', required: true }],
      },
    ],
    order: [['id', 'ASC']],
  });

  const items = [];
  let sumRates = 0;
  let rateCount = 0;

  for (const m of memberships) {
    const period = m.periode_ekstrakurikuler;
    const ekskul = period.ekstrakurikuler;

    const [masa, coachRow, meetings, attendanceRows] = await Promise.all([
      models.masa.findOne({
        where: { id_keanggotaan_ekstrakurikuler: m.id },
        order: [['id', 'DESC']],
      }),
      models.pembina.findOne({
        where: { id_periode_ekstrakurikuler: period.id, tanggal_selesai: null },
        include: [{ model: models.guru, as: 'guru', required: false }],
      }),
      models.pertemuan.findAll({
        where: { id_periode_ekstrakurikuler: period.id },
        order: [['tanggal', 'DESC'], ['jam_mulai', 'DESC']],
        raw: true,
      }),
      models.presensi_ekskul.findAll({
        where: { id_keanggotaan_ekstrakurikuler: m.id },
        raw: true,
      }),
    ]);

    const attByMeeting = new Map();
    for (const a of attendanceRows) attByMeeting.set(a.id_pertemuan_ekstrakurikuler, a);

    let attended = 0;
    const sessions = meetings.map((mt) => {
      const a = attByMeeting.get(mt.id);
      const st = a?.status_kehadiran ?? null;
      if (st === 'HADIR' || st === 'TERLAMBAT') attended++;
      return {
        id: mt.id,
        tanggal: typeof mt.tanggal === 'string' ? mt.tanggal.slice(0, 10) : jakartaDate(mt.tanggal),
        date_formatted: fmtDateLong(mt.tanggal),
        jam_mulai: mt.jam_mulai ? String(mt.jam_mulai).slice(0, 5) : null,
        jam_selesai: mt.jam_selesai ? String(mt.jam_selesai).slice(0, 5) : null,
        lokasi: mt.lokasi ?? null,
        agenda: mt.agenda ?? null,
        status_pertemuan: mt.status_pertemuan,
        status_kehadiran: st ?? 'BELUM_DIISI',
        recorded: Boolean(a),
        keterangan: a?.keterangan ?? null,
      };
    });

    const totalSessions = meetings.length;
    const rate = totalSessions > 0 ? Math.round((attended / totalSessions) * 100) : 0;
    if (totalSessions > 0) {
      sumRates += rate;
      rateCount++;
    }

    const latestMeeting = meetings[0] ?? null;
    const schedule = latestMeeting && latestMeeting.jam_mulai
      ? `${String(latestMeeting.jam_mulai).slice(0, 5)}${latestMeeting.jam_selesai ? ` – ${String(latestMeeting.jam_selesai).slice(0, 5)}` : ''} WIB`
      : null;

    items.push({
      id: period.id,
      membership_id: m.id,
      name: ekskul.nama,
      description: ekskul.deskripsi ?? null,
      status_keanggotaan: masa && masa.tanggal_selesai ? 'Nonaktif' : 'Aktif',
      coach: coachRow?.guru?.nama ?? null,
      schedule,
      location: latestMeeting?.lokasi ?? null,
      attended_count: attended,
      total_sessions: totalSessions,
      attendance_rate: rate,
      activity_label: totalSessions === 0
        ? 'Belum ada sesi'
        : rate >= 85
          ? 'Sangat Aktif'
          : rate >= 60
            ? 'Aktif'
            : 'Perlu Ditingkatkan',
      sessions,
    });
  }

  const avgRate = rateCount > 0 ? Math.round(sumRates / rateCount) : 0;

  res.set('Cache-Control', 'no-store').json({
    data: {
      children,
      child,
      summary: {
        enrolled_count: items.length,
        average_attendance_rate: avgRate,
        academic_year: activeYear?.nama ?? '-',
        semester_name: activeSemester?.nama ?? '',
      },
      items,
    },
  });
};
