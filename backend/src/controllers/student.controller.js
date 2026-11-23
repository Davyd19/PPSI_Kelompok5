'use strict';
const { Op } = require('sequelize');
const { models, sequelize } = require('../models');
const fail = require('../utils/api-error');

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------
function ensureStudent(req) {
  if (req.user.kind !== 'siswa') {
    throw fail(403, 'FORBIDDEN', 'Fitur ini hanya dapat diakses oleh Siswa.');
  }
}

/** Return student row + current classroom name */
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

/** Format a JS Date to 'HH:MM WIB' */
function fmtTime(d) {
  if (!d) return null;
  const dt = new Date(d);
  return `${String(dt.getHours()).padStart(2, '0')}:${String(dt.getMinutes()).padStart(2, '0')} WIB`;
}

/** Format a JS Date to 'D Mon YYYY' – Indonesian abbreviated month */
const ID_MONTHS = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
const ID_DAYS   = ['Minggu','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'];
function fmtDate(d) {
  if (!d) return null;
  const dt = new Date(d);
  return `${dt.getDate()} ${ID_MONTHS[dt.getMonth()]} ${dt.getFullYear()}`;
}
function fmtDateLong(d) {
  if (!d) return null;
  const dt = new Date(d);
  return `${ID_DAYS[dt.getDay()]}, ${dt.getDate()} ${ID_MONTHS[dt.getMonth()]} ${dt.getFullYear()}`;
}

// ---------------------------------------------------------------------------
// 1. DASHBOARD
// ---------------------------------------------------------------------------
exports.dashboard = async (req, res) => {
  ensureStudent(req);
  const studentProfile = await getStudentProfile(req);

  // Active semester
  const semester = await models.semester.findOne({
    where: { tanggal_mulai: { [Op.lte]: new Date() }, tanggal_selesai: { [Op.gte]: new Date() } },
    order: [['tanggal_mulai', 'DESC']],
  });

  // Attendance summary this semester
  let stats = { hadir: 0, telat: 0, izin: 0, alfa: 0 };
  let todayPresensi = null;
  let weeklyGrid = [];

  if (semester) {
    const rows = await models.presensi.findAll({
      where: { id_siswa: req.user.id },
      include: [{ model: models.sesi, as: 'sesi_presensi_sekolah_id_sesi_presensi_sekolah', required: true,
        where: { id_semester: semester.id } }],
    });

    for (const r of rows) {
      const st = r.status_kehadiran;
      if (st === 'HADIR') stats.hadir++;
      else if (st === 'TERLAMBAT') stats.telat++;
      else if (st === 'IZIN' || st === 'SAKIT') stats.izin++;
      else stats.alfa++;
    }

    // Today
    const today = new Date().toISOString().slice(0, 10);
    const todaySesi = await models.sesi.findOne({ where: { tanggal: today } });
    if (todaySesi) {
      todayPresensi = await models.presensi.findOne({
        where: { id_siswa: req.user.id, id_sesi_presensi_sekolah: todaySesi.id },
      });
    }

    // Weekly (Mon–Fri of current week)
    const now = new Date();
    const dayOfWeek = now.getDay(); // 0=Sun
    const monday = new Date(now);
    monday.setDate(now.getDate() - (dayOfWeek === 0 ? 6 : dayOfWeek - 1));
    for (let i = 0; i < 5; i++) {
      const d = new Date(monday);
      d.setDate(monday.getDate() + i);
      const dStr = d.toISOString().slice(0, 10);
      const s = await models.sesi.findOne({ where: { tanggal: dStr } });
      let status = null;
      if (s) {
        const p = await models.presensi.findOne({ where: { id_siswa: req.user.id, id_sesi_presensi_sekolah: s.id } });
        status = p?.status_kehadiran ?? null;
      }
      weeklyGrid.push({ day: ['Sen','Sel','Rab','Kam','Jum'][i], status, date: dStr });
    }
  }

  // Streak (count consecutive HADIR/today backwards)
  const allP = await models.presensi.findAll({
    where: { id_siswa: req.user.id, status_kehadiran: { [Op.in]: ['HADIR', 'TERLAMBAT'] } },
    order: [['id', 'DESC']],
    limit: 60,
  });
  const streakDays = allP.length;

  // Appreciation points from portofolio (peserta)
  const participations = await models.peserta.findAll({ where: { id_siswa: req.user.id } });
  const portIds = participations.map(p => p.id_portofolio);
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

  // Violation cases (laporan_pelanggaran active)
  const activeCases = await models.laporan.findAll({
    where: { id_siswa: req.user.id, status_tindak_lanjut: { [Op.notIn]: ['SELESAI', 'DIBATALKAN'] } },
  });

  // Unread notifications
  const unreadNotifs = await models.penerima.count({
    where: { id_siswa: req.user.id, waktu_dibaca: null },
  });

  // Recent activities: last 3 portofolio or notifikasi
  const recentPorts = await models.peserta.findAll({
    where: { id_siswa: req.user.id },
    order: [['id', 'DESC']],
    limit: 2,
    include: [{ model: models.portofolio, as: 'portofolio_id_portofolio', required: true }],
  });

  const recentActivities = recentPorts.map((pp, i) => {
    const port = pp['portofolio_id_portofolio'];
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
        today: todayPresensi ? {
          status: todayPresensi.status_kehadiran,
          time: fmtTime(todayPresensi.waktu_presensi),
          is_on_time: todayPresensi.status_kehadiran === 'HADIR',
          session: 'Pagi',
          tolerance_limit: '07:00 WIB',
        } : null,
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

// ---------------------------------------------------------------------------
// 2. SCAN ATTENDANCE  (POST)
// ---------------------------------------------------------------------------
exports.scanAttendance = async (req, res) => {
  ensureStudent(req);
  const student = await getStudentProfile(req);
  const { qr_code, manual_code } = req.body ?? {};

  // Find open session today
  const today = new Date().toISOString().slice(0, 10);
  const sesi = await models.sesi.findOne({
    where: {
      tanggal: today,
      status: { [Op.in]: ['BUKA', 'AKTIF'] },
    },
    order: [['waktu_buka', 'DESC']],
  });

  if (!sesi) {
    throw fail(422, 'NO_SESSION', 'Tidak ada sesi presensi yang aktif hari ini. Hubungi Guru Piket.');
  }

  // Validate QR token if present
  if (qr_code && sesi.hash_token_qr) {
    if (sesi.token_kedaluwarsa && new Date() > new Date(sesi.token_kedaluwarsa)) {
      throw fail(422, 'TOKEN_EXPIRED', 'QR Code sudah kedaluwarsa. Minta token baru dari Guru Piket.');
    }
    if (sesi.hash_token_qr !== qr_code) {
      throw fail(422, 'INVALID_QR', 'QR Code tidak valid atau tidak cocok dengan sesi aktif hari ini.');
    }
  }

  // Check if already recorded
  const existing = await models.presensi.findOne({
    where: { id_siswa: req.user.id, id_sesi_presensi_sekolah: sesi.id },
  });
  if (existing) {
    throw fail(409, 'ALREADY_RECORDED',
      `Presensi Anda hari ini sudah tercatat: ${existing.status_kehadiran} pukul ${fmtTime(existing.waktu_presensi)}.`);
  }

  const now = new Date();
  const batas = sesi.batas_tepat_waktu ? new Date(sesi.batas_tepat_waktu) : null;
  const status = (batas && now > batas) ? 'TERLAMBAT' : 'HADIR';

  const created = await models.presensi.create({
    id_sesi_presensi_sekolah: sesi.id,
    id_siswa: req.user.id,
    status_kehadiran: status,
    waktu_presensi: now,
    metode: manual_code ? 'MANUAL_PIN' : 'QR_SCAN',
    keterangan: manual_code ? `PIN: ${manual_code}` : null,
  });

  // Count streak
  const allP = await models.presensi.count({
    where: { id_siswa: req.user.id, status_kehadiran: { [Op.in]: ['HADIR', 'TERLAMBAT'] } },
  });

  res.set('Cache-Control', 'no-store').json({
    data: {
      status: 'success',
      message: status === 'HADIR' ? 'Presensi Berhasil' : 'Tercatat Terlambat',
      description: 'Data kehadiran Anda telah tercatat ke server SIKAP SMAN 12 Padang.',
      presensi_id: created.id,
      check_in_time: fmtTime(now),
      status_kehadiran: status === 'HADIR' ? 'Tepat Waktu' : 'Terlambat',
      tolerance_limit: batas ? fmtTime(batas) : '07:00 WIB',
      date_formatted: fmtDateLong(now),
      streak_days: allP,
      student_name: student.name,
      student_classroom: student.classroom,
      student_nisn: student.nisn,
    },
  });
};

// ---------------------------------------------------------------------------
// 3. ATTENDANCE HISTORY  (GET)
// ---------------------------------------------------------------------------
exports.attendanceHistory = async (req, res) => {
  ensureStudent(req);
  const student = await getStudentProfile(req);

  // Parse ?year=&month= (1-based); default = current month
  const now = new Date();
  const year  = parseInt(req.query.year  ?? now.getFullYear(), 10);
  const month = parseInt(req.query.month ?? now.getMonth() + 1, 10);

  const startDate = new Date(year, month - 1, 1).toISOString().slice(0, 10);
  const endDate   = new Date(year, month, 0).toISOString().slice(0, 10);

  // Find all sessions in this month
  const sessions = await models.sesi.findAll({
    where: { tanggal: { [Op.between]: [startDate, endDate] } },
    order: [['tanggal', 'ASC']],
  });

  const sessionIds = sessions.map(s => s.id);
  const presensiRows = sessionIds.length > 0
    ? await models.presensi.findAll({
        where: { id_siswa: req.user.id, id_sesi_presensi_sekolah: { [Op.in]: sessionIds } },
      })
    : [];

  const bySession = {};
  for (const p of presensiRows) bySession[p.id_sesi_presensi_sekolah] = p;

  // Build calendar records & stats
  let stats = { hadir: 0, telat: 0, izin: 0, alfa: 0 };
  const calendar_records = [];

  for (const s of sessions) {
    const p = bySession[s.id];
    const dayNum = new Date(s.tanggal).getDate();
    if (p) {
      const st = p.status_kehadiran;
      if (st === 'HADIR') stats.hadir++;
      else if (st === 'TERLAMBAT') stats.telat++;
      else if (st === 'IZIN' || st === 'SAKIT') stats.izin++;
      else stats.alfa++;
      calendar_records.push({ day: dayNum, status: st, presensi_id: p.id });
    } else {
      stats.alfa++;
      calendar_records.push({ day: dayNum, status: 'ALFA' });
    }
  }

  const totalSessions = sessions.length;
  const ratePercentage = totalSessions > 0
    ? Math.round(((stats.hadir + stats.telat) / totalSessions) * 1000) / 10
    : 0;

  // Detail for selected day (from ?day= or last session with presensi)
  const selectedDay = parseInt(req.query.day ?? 0, 10);
  let selectedDetail = null;
  if (selectedDay > 0) {
    const selDate = new Date(year, month - 1, selectedDay).toISOString().slice(0, 10);
    const selSesi = sessions.find(s => s.tanggal === selDate);
    if (selSesi) {
      const p = bySession[selSesi.id];
      if (p) {
        selectedDetail = {
          date_formatted: fmtDateLong(selSesi.tanggal),
          status_label: p.status_kehadiran === 'HADIR' ? 'Hadir Tepat Waktu'
            : p.status_kehadiran === 'TERLAMBAT' ? 'Terlambat'
            : p.status_kehadiran,
          status_color: p.status_kehadiran === 'HADIR' ? '#10B981'
            : p.status_kehadiran === 'TERLAMBAT' ? '#F59E0B'
            : p.status_kehadiran === 'ALFA' ? '#EF4444' : '#94A3B8',
          check_in_time: fmtTime(p.waktu_presensi),
          check_out_time: null,
          verification_method: p.metode === 'QR_SCAN' ? 'Terverifikasi via QR Gerbang'
            : p.metode === 'MANUAL_PIN' ? 'Input Manual PIN Guru Piket' : p.metode ?? '-',
          keterangan: p.keterangan ?? null,
        };
      }
    }
  }

  const monthName = `${ID_MONTHS[month - 1]} ${year}`;

  // Current semester name
  const semester = await models.semester.findOne({
    where: { tanggal_mulai: { [Op.lte]: `${year}-${String(month).padStart(2,'0')}-01` } },
    include: [{ model: models.tahun, as: 'tahun_ajaran_id_tahun_ajaran', required: false }],
    order: [['tanggal_mulai', 'DESC']],
  });
  const semesterName = semester ? `${semester.nama} T.A. ${semester['tahun_ajaran_id_tahun_ajaran']?.nama ?? ''}` : '';

  res.set('Cache-Control', 'no-store').json({
    data: {
      student,
      academic_year: semesterName,
      month_name: monthName,
      current_year: year,
      current_month: month,
      stats: { hadir: stats.hadir, telat: stats.telat, izin: stats.izin, alfa: stats.alfa, rate_percentage: ratePercentage },
      legend: [
        { label: 'Hadir', color: '#10B981' },
        { label: 'Terlambat', color: '#F59E0B' },
        { label: 'Izin/Sakit', color: '#334155' },
        { label: 'Alfa', color: '#EF4444' },
      ],
      calendar_records,
      selected_detail: selectedDetail,
    },
  });
};

// ---------------------------------------------------------------------------
// 4. COUNSELING STATUS  (GET)
// ---------------------------------------------------------------------------
exports.counseling = async (req, res) => {
  ensureStudent(req);

  const penangananList = await models.penanganan.findAll({
    where: { id_siswa: req.user.id },
    order: [['tanggal_dibuka', 'DESC']],
    include: [{ model: models.guru, as: 'guru_id_guru_bk_penanggung_jawab', required: false }],
  });

  if (penangananList.length === 0) {
    return res.set('Cache-Control', 'no-store').json({
      data: {
        active_cases_count: 0,
        resolved_cases_count: 0,
        privacy_banner: 'Privasi Terjamin: Catatan sesi bersifat tertutup & dilindungi kode etik BK.',
        active_case: null,
        resolved_case: null,
      },
    });
  }

  async function buildCase(p) {
    const counselor = p['guru_id_guru_bk_penanggung_jawab'];
    const riwayats = await models.riwayat.findAll({
      where: { id_penanganan_siswa: p.id },
      order: [['waktu', 'ASC']],
    });
    const rencana = await models.rencana.findOne({
      where: { id_penanganan_siswa: p.id, status: { [Op.notIn]: ['SELESAI', 'DIBATALKAN'] } },
      order: [['jadwal', 'ASC']],
    });
    const steps = riwayats.map((r, i) => ({
      label: `${r.jenis}: ${fmtDate(r.waktu)}`,
      done: true,
    }));
    if (p.status !== 'SELESAI') {
      steps.push({ label: 'Evaluasi Akhir', done: false });
    }
    return {
      id: p.id,
      code: `Berkas #BK-${p.id}`,
      status: p.status,
      counselor: counselor ? { name: counselor.nama, role: 'Guru BK' } : null,
      alasan: p.alasan_pembukaan ?? null,
      progress_notes: p.ringkasan_diizinkan ?? null,
      progress_phase: {
        title: `Tahap ${Math.min(riwayats.length, steps.length)}: ${p.status}`,
        step: Math.min(riwayats.length, steps.length),
        total_steps: steps.length,
        steps,
      },
      upcoming_session: rencana ? {
        type: rencana.bentuk_kegiatan,
        date_formatted: fmtDateLong(rencana.jadwal),
        time: fmtTime(rencana.jadwal),
        location: null,
      } : null,
      completed_date: p.status === 'SELESAI' ? fmtDate(p.tanggal_dibuka) : null,
    };
  }

  const activeCases   = penangananList.filter(p => p.status !== 'SELESAI');
  const resolvedCases = penangananList.filter(p => p.status === 'SELESAI');

  res.set('Cache-Control', 'no-store').json({
    data: {
      active_cases_count: activeCases.length,
      resolved_cases_count: resolvedCases.length,
      privacy_banner: 'Privasi Terjamin: Catatan sesi bersifat tertutup & dilindungi kode etik BK.',
      active_case: activeCases.length > 0 ? await buildCase(activeCases[0]) : null,
      resolved_case: resolvedCases.length > 0 ? await buildCase(resolvedCases[0]) : null,
    },
  });
};

// ---------------------------------------------------------------------------
// 5. BADGES  (GET)
// ---------------------------------------------------------------------------
exports.badges = async (req, res) => {
  ensureStudent(req);

  // All levels with their badge name
  const levels = await models.level.findAll({
    include: [{ model: models.versi_badge, as: 'versi_aturan_badge_id_versi_aturan_badge', required: true,
      include: [{ model: models.badge, as: 'badge_id_badge', required: true }] }],
    order: [['id', 'ASC']],
  });

  // Achieved by this student
  const achieved = await models.pencapaian.findAll({ where: { id_siswa: req.user.id, aktif: true } });
  const achievedLevelIds = new Set(achieved.map(a => a.id_level_badge));
  const achievedMap = {};
  for (const a of achieved) achievedMap[a.id_level_badge] = a;

  if (levels.length === 0) {
    return res.set('Cache-Control', 'no-store').json({ data: [] });
  }

  const result = levels.map(lv => {
    const versi = lv['versi_aturan_badge_id_versi_aturan_badge'];
    const badge = versi?.['badge_id_badge'];
    const isAchieved = achievedLevelIds.has(lv.id);
    const achievementRecord = achievedMap[lv.id];

    // Compute rough progress: for attendance-based, count presensi; for others approximate
    let progress = isAchieved ? lv.target : 0;

    return {
      id: lv.id,
      badge: badge?.nama ?? 'Badge',
      nama: `${badge?.nama ?? 'Badge'} – ${lv.nama}`,
      kategori: lv.sumber_data,
      category: lv.sumber_data,
      deskripsi: badge?.deskripsi ?? null,
      description: badge?.deskripsi ?? null,
      target: lv.target,
      progress,
      sementara: !isAchieved,
      diperoleh: isAchieved,
      waktu_diperoleh: achievementRecord ? achievementRecord.waktu_diperoleh : null,
      verification_tag: isAchieved ? 'Terverifikasi Otomatis' : 'Belum Diperoleh',
    };
  });

  res.set('Cache-Control', 'no-store').json({ data: result });
};

// ---------------------------------------------------------------------------
// 6. EXTRACURRICULARS  (GET)
// ---------------------------------------------------------------------------
exports.extracurriculars = async (req, res) => {
  ensureStudent(req);

  // All active periods
  const periods = await models.periode_ekskul.findAll({
    where: { status_kegiatan: { [Op.in]: ['AKTIF', 'BERJALAN'] } },
    include: [{ model: models.ekskul, as: 'ekstrakurikuler_id_ekstrakurikuler', required: true }],
    order: [['id', 'ASC']],
  });

  if (periods.length === 0) {
    return res.set('Cache-Control', 'no-store').json({
      data: { summary: { enrolled_count: 0, academic_year: '-' }, categories: [], items: [] },
    });
  }

  // Memberships of this student
  const memberships = await models.anggota.findAll({ where: { id_siswa: req.user.id } });
  const memberPeriodIds = new Set(memberships.map(m => m.id_periode_ekstrakurikuler));

  // Pending registrations
  const pendingRegs = await models.pendaftaran.findAll({
    where: { id_siswa: req.user.id, status_keputusan: 'MENUNGGU' },
  });
  const pendingPeriodIds = new Set(pendingRegs.map(r => r.id_periode_ekstrakurikuler));

  // Coaches per period
  const coaches = await models.pembina.findAll({
    where: { id_periode_ekstrakurikuler: { [Op.in]: periods.map(p => p.id) }, tanggal_selesai: null },
    include: [{ model: models.guru, as: 'guru_id_guru', required: false }],
  });
  const coachByPeriod = {};
  for (const c of coaches) {
    if (!coachByPeriod[c.id_periode_ekstrakurikuler]) {
      coachByPeriod[c.id_periode_ekstrakurikuler] = c['guru_id_guru']?.nama ?? null;
    }
  }

  // Active year
  const tahun = await models.tahun.findOne({ where: { aktif: true } });

  const categoryColors = {
    'Kepemimpinan': '#0D9488', 'Olahraga': '#F97316', 'Sains & TI': '#0284C7',
    'Seni & Budaya': '#8B5CF6', 'Kemanusiaan': '#EF4444', 'Kepanduan': '#10B981',
  };

  const items = periods.map(p => {
    const ekskul = p['ekstrakurikuler_id_ekstrakurikuler'];
    const isEnrolled = memberPeriodIds.has(p.id);
    const isPending  = pendingPeriodIds.has(p.id);

    // Compute remaining seats
    const enrolled = memberships.filter(m => m.id_periode_ekstrakurikuler === p.id).length;
    const remaining = p.kapasitas != null ? Math.max(0, p.kapasitas - enrolled) : null;

    const tag = isEnrolled ? 'Terdaftar'
      : isPending ? 'Menunggu Persetujuan'
      : remaining === 0 ? 'Penuh'
      : remaining != null ? `Sisa ${remaining} Kursi`
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

  const categories = ['Semua', 'Diikuti', ...new Set(items.map(i => i.category).filter(Boolean))];

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

// ---------------------------------------------------------------------------
// 7. EXTRACURRICULAR DETAIL  (GET /:id)
// ---------------------------------------------------------------------------
exports.extracurricularDetail = async (req, res) => {
  ensureStudent(req);
  const periodeId = parseInt(req.params.id, 10);

  const period = await models.periode_ekskul.findByPk(periodeId, {
    include: [{ model: models.ekskul, as: 'ekstrakurikuler_id_ekstrakurikuler', required: true }],
  });
  if (!period) throw fail(404, 'NOT_FOUND', 'Ekstrakurikuler tidak ditemukan.');

  const ekskul = period['ekstrakurikuler_id_ekstrakurikuler'];
  const memberships = await models.anggota.count({ where: { id_periode_ekstrakurikuler: periodeId } });
  const myMembership = await models.anggota.findOne({ where: { id_siswa: req.user.id, id_periode_ekstrakurikuler: periodeId } });
  const myPending = await models.pendaftaran.findOne({ where: { id_siswa: req.user.id, id_periode_ekstrakurikuler: periodeId, status_keputusan: 'MENUNGGU' } });

  const coach = await models.pembina.findOne({
    where: { id_periode_ekstrakurikuler: periodeId, tanggal_selesai: null },
    include: [{ model: models.guru, as: 'guru_id_guru', required: false }],
  });

  const remaining = period.kapasitas != null ? Math.max(0, period.kapasitas - memberships) : null;
  const regStatus = myMembership ? 'Sudah Terdaftar'
    : myPending ? 'Menunggu Persetujuan'
    : period.status_pendaftaran === 'BUKA' ? 'Pendaftaran Terbuka'
    : 'Pendaftaran Tutup';

  res.set('Cache-Control', 'no-store').json({
    data: {
      id: periodeId,
      ekskul_id: ekskul.id,
      title: ekskul.nama,
      subtitle: ekskul.nama,
      school: 'SMAN 12 Padang',
      category: ekskul.status ?? 'Umum',
      coach: coach?.['guru_id_guru']?.nama ? `${coach['guru_id_guru'].nama} • Pembina Ekskul` : null,
      stats: {
        active_students: period.kapasitas ? `${memberships} / ${period.kapasitas} Siswa Aktif` : `${memberships} Siswa`,
        track: 'Peminatan',
        accreditation: null,
      },
      description: ekskul.deskripsi ?? null,
      schedule_place: {
        days_time: null,
        location: null,
      },
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

// ---------------------------------------------------------------------------
// 8. REGISTER EXTRACURRICULAR  (POST /:id/register)
// ---------------------------------------------------------------------------
exports.registerExtracurricular = async (req, res) => {
  ensureStudent(req);
  const periodeId = parseInt(req.params.id, 10);

  const period = await models.periode_ekskul.findByPk(periodeId);
  if (!period) throw fail(404, 'NOT_FOUND', 'Ekstrakurikuler tidak ditemukan.');

  if (period.status_pendaftaran !== 'BUKA') {
    throw fail(422, 'REG_CLOSED', 'Pendaftaran ekstrakurikuler ini saat ini tidak dibuka.');
  }

  const existing = await models.anggota.findOne({ where: { id_siswa: req.user.id, id_periode_ekstrakurikuler: periodeId } });
  if (existing) throw fail(409, 'ALREADY_ENROLLED', 'Anda sudah terdaftar di ekstrakurikuler ini.');

  const pending = await models.pendaftaran.findOne({ where: { id_siswa: req.user.id, id_periode_ekstrakurikuler: periodeId, status_keputusan: 'MENUNGGU' } });
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

// ---------------------------------------------------------------------------
// 9. ACHIEVEMENTS  (GET)
// ---------------------------------------------------------------------------
exports.achievements = async (req, res) => {
  ensureStudent(req);

  const participations = await models.peserta.findAll({
    where: { id_siswa: req.user.id },
    include: [{
      model: models.portofolio,
      as: 'portofolio_id_portofolio',
      required: true,
      where: { jenis: 'PRESTASI' },
      include: [{ model: models.guru, as: 'guru_id_guru_pencatat', required: false }],
    }],
    order: [[{ model: models.portofolio, as: 'portofolio_id_portofolio' }, 'tanggal', 'DESC']],
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
    const port = pp['portofolio_id_portofolio'];
    const pts = pointsFromHasil(port.hasil_prestasi);
    totalPoints += pts;

    const portDate = port.tanggal ? new Date(port.tanggal) : new Date();
    // Determine academic year (Aug-Jul cycle)
    const portYear = portDate.getFullYear();
    const portMonth = portDate.getMonth() + 1; // 1-12
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

// ---------------------------------------------------------------------------
// 10. SUBMIT ACHIEVEMENT  (POST)
// ---------------------------------------------------------------------------
exports.submitAchievement = async (req, res) => {
  ensureStudent(req);
  const { judul, deskripsi, tingkat_prestasi, hasil_prestasi, tanggal } = req.body ?? {};
  if (!judul) throw fail(422, 'VALIDATION_ERROR', 'Judul prestasi wajib diisi.');

  // Need a guru_pencatat: use first guru_bk or any active guru
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

// ---------------------------------------------------------------------------
// 11. NOTIFICATIONS  (GET)
// ---------------------------------------------------------------------------
exports.notifications = async (req, res) => {
  ensureStudent(req);

  const penerimas = await models.penerima.findAll({
    where: { id_siswa: req.user.id },
    include: [{ model: models.notifikasi, as: 'notifikasi_id_notifikasi', required: true }],
    order: [[{ model: models.notifikasi, as: 'notifikasi_id_notifikasi' }, 'waktu_dibuat', 'DESC']],
  });

  if (penerimas.length === 0) {
    return res.set('Cache-Control', 'no-store').json({
      data: { unread_count: 0, filter_tabs: [], groups: [] },
    });
  }

  const unreadCount = penerimas.filter(p => !p.waktu_dibaca).length;

  // Group by relative day
  const now = new Date();
  const todayStr = now.toISOString().slice(0, 10);
  const ystStr = new Date(now - 86400000).toISOString().slice(0, 10);

  const groupsMap = {};
  const typeCounts = {};

  for (const pn of penerimas) {
    const notif = pn['notifikasi_id_notifikasi'];
    const created = new Date(notif.waktu_dibuat);
    const dateStr = created.toISOString().slice(0, 10);
    const diffDays = Math.floor((now - created) / 86400000);

    let groupName;
    if (dateStr === todayStr) groupName = 'Hari Ini';
    else if (dateStr === ystStr) groupName = 'Kemarin';
    else if (diffDays < 7) groupName = 'Minggu Ini';
    else groupName = fmtDate(created);

    if (!groupsMap[groupName]) groupsMap[groupName] = { date_label: fmtDate(created), items: [] };

    const type = notif.jenis ?? 'general';
    typeCounts[type] = (typeCounts[type] ?? 0) + 1;

    groupsMap[groupName].items.push({
      id: pn.id,
      notif_id: notif.id,
      category: (notif.jenis ?? 'INFO').toUpperCase(),
      title: notif.judul,
      description: notif.isi,
      time_ago: diffDays === 0 ? fmtTime(created) : diffDays === 1 ? 'Kemarin' : `${diffDays} hari lalu`,
      unread: !pn.waktu_dibaca,
      type,
    });
  }

  const groups = Object.entries(groupsMap).map(([group_name, v]) => ({
    group_name,
    date_label: v.date_label,
    items: v.items,
  }));

  const filterTabs = [
    { key: 'all', label: 'Semua', count: penerimas.length },
    ...Object.entries(typeCounts).map(([k, v]) => ({ key: k, label: k.charAt(0).toUpperCase() + k.slice(1), count: v })),
  ];

  res.set('Cache-Control', 'no-store').json({
    data: { unread_count: unreadCount, filter_tabs: filterTabs, groups },
  });
};

// ---------------------------------------------------------------------------
// 12. NOTIFICATION DETAIL  (GET /:id)
// ---------------------------------------------------------------------------
exports.notificationDetail = async (req, res) => {
  ensureStudent(req);
  const pnId = parseInt(req.params.id, 10);

  const pn = await models.penerima.findOne({
    where: { id: pnId, id_siswa: req.user.id },
    include: [{ model: models.notifikasi, as: 'notifikasi_id_notifikasi', required: true }],
  });
  if (!pn) throw fail(404, 'NOT_FOUND', 'Notifikasi tidak ditemukan.');

  // Mark as read
  if (!pn.waktu_dibaca) await pn.update({ waktu_dibaca: new Date() });

  const notif = pn['notifikasi_id_notifikasi'];

  res.set('Cache-Control', 'no-store').json({
    data: {
      id: pn.id,
      notif_id: notif.id,
      jenis: notif.jenis,
      title: notif.judul,
      isi: notif.isi,
      date_time: fmtDateLong(notif.waktu_dibuat),
      time: fmtTime(notif.waktu_dibuat),
      unread: false,
    },
  });
};

// ---------------------------------------------------------------------------
// 13. MARK NOTIFICATIONS READ  (POST)
// ---------------------------------------------------------------------------
exports.markNotificationsRead = async (req, res) => {
  ensureStudent(req);
  const { id } = req.body ?? {};

  if (id) {
    await models.penerima.update(
      { waktu_dibaca: new Date() },
      { where: { id: parseInt(id, 10), id_siswa: req.user.id, waktu_dibaca: null } },
    );
  } else {
    await models.penerima.update(
      { waktu_dibaca: new Date() },
      { where: { id_siswa: req.user.id, waktu_dibaca: null } },
    );
  }

  res.set('Cache-Control', 'no-store').json({
    data: { status: 'success', message: 'Notifikasi berhasil ditandai dibaca.' },
  });
};
