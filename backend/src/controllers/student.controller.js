const { models } = require('../models');
const badgesService = require('../services/badges');
const fail = require('../utils/api-error');

// In-memory runtime state for interactive operations during a session
const state = {
  attendanceRecordedToday: false,
  todayAttendanceTime: '06:42 WIB',
  streakDays: 24,
  readNotificationIds: new Set(),
  enrolledEkskulIds: new Set([1, 2]),
  registeredPendingEkskulIds: new Set(),
  customAchievements: []
};

function ensureStudent(req) {
  if (req.user.kind !== 'siswa' && !req.user.available_roles.includes('SISWA')) {
    throw fail(403, 'FORBIDDEN', 'Fitur ini hanya dapat diakses oleh Siswa.');
  }
}

async function getStudentProfile(req) {
  const student = await models.siswa.findByPk(req.user.id);
  const rk = await models.riwayat_kelas.findOne({
    where: { id_siswa: req.user.id },
    order: [['id', 'DESC']]
  });
  const kelas = rk ? await models.kelas.findByPk(rk.id_kelas) : null;
  return {
    id: req.user.id,
    name: student?.nama || req.user.name || 'Muhammad Raihan Al-Farisi',
    nisn: student?.nisn || '0071298451',
    nis: student?.nis || '21084',
    classroom: kelas?.nama || 'XI MIPA 1',
    photo_url: null
  };
}

exports.dashboard = async (req, res) => {
  ensureStudent(req);
  const studentProfile = await getStudentProfile(req);

  res.set('Cache-Control', 'no-store').json({
    data: {
      student: studentProfile,
      attendance_summary: {
        on_time_days: state.streakDays,
        today: {
          status: state.attendanceRecordedToday ? 'HADIR' : 'HADIR',
          time: state.todayAttendanceTime,
          is_on_time: true,
          session: 'Pagi',
          tolerance_limit: '07:00 WIB'
        },
        weekly_grid: [
          { day: 'Sen', status: 'HADIR', on_time: true },
          { day: 'Sel', status: 'HADIR', on_time: true },
          { day: 'Rab', status: 'HADIR', on_time: true },
          { day: 'Kam', status: 'HADIR', on_time: true },
          { day: 'Jum', status: 'HADIR', on_time: true }
        ]
      },
      metrics: {
        appreciation_points: 85,
        points_predicate: 'Baik',
        violation_cases: 0,
        discipline_status: 'Bersih'
      },
      recent_activities: [
        {
          id: 1,
          type: 'achievement',
          category: 'VERIFIKASI PRESTASI',
          category_color: '#0D9488',
          accent_color: '#34D399',
          title: 'Juara 1 OSN Kimia 2025',
          time_ago: '2 jam lalu',
          subtitle_prefix: 'Disetujui Pembina • ',
          highlight_text: '+35 Poin',
          highlight_color: '#059669',
          icon: 'military_tech'
        },
        {
          id: 2,
          type: 'badge',
          category: 'BADGE DIRAIH',
          category_color: '#0284C7',
          accent_color: '#38BDF8',
          title: 'Badge Disiplin Perak',
          time_ago: 'Kemarin',
          subtitle_prefix: 'Pencapaian kehadiran 100% konsisten •..',
          highlight_text: '',
          icon: 'workspace_premium'
        },
        {
          id: 3,
          type: 'attendance',
          category: 'PRESENSI SEKOLAH',
          category_color: '#7C3AED',
          accent_color: '#A78BFA',
          title: 'Presensi Pagi Tepat Waktu',
          time_ago: 'Hari ini',
          subtitle_prefix: 'Tercatat pukul 06.42 WIB • ',
          highlight_text: 'Hadir',
          highlight_color: '#059669',
          icon: 'event_available'
        }
      ],
      unread_notifications: Math.max(0, 2 - state.readNotificationIds.size)
    }
  });
};

exports.scanAttendance = async (req, res) => {
  ensureStudent(req);
  const student = await getStudentProfile(req);

  const now = new Date();
  const timeFormatted = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')} WIB`;

  state.attendanceRecordedToday = true;
  state.todayAttendanceTime = timeFormatted;
  state.streakDays = 25;

  res.set('Cache-Control', 'no-store').json({
    data: {
      status: 'success',
      message: 'Presensi Berhasil',
      description: 'Data kehadiran Anda telah tercatat ke server SIKAP SMAN 12 Padang.',
      check_in_time: '06:43 WIB',
      status_kehadiran: 'Tepat Waktu',
      tolerance_limit: '07:15 WIB',
      date_formatted: 'Senin, 24 Feb 2025',
      streak_days: 25,
      student_name: student.name,
      student_classroom: student.classroom,
      student_nisn: student.nisn
    }
  });
};

exports.attendanceHistory = async (req, res) => {
  ensureStudent(req);
  const student = await getStudentProfile(req);

  res.set('Cache-Control', 'no-store').json({
    data: {
      student,
      academic_year: 'Semester Genap T.A. 2023/2024',
      month_name: 'Februari 2025',
      stats: {
        hadir: 20,
        telat: 1,
        izin: 1,
        alfa: 0,
        rate_percentage: 95.5
      },
      legend: [
        { label: 'Hadir', color: '#10B981' },
        { label: 'Terlambat', color: '#38BDF8' },
        { label: 'Izin/Sakit', color: '#334155' },
        { label: 'Alfa', color: '#EF4444' }
      ],
      calendar_records: [
        { day: 3, status: 'HADIR' },
        { day: 4, status: 'HADIR' },
        { day: 5, status: 'HADIR' },
        { day: 6, status: 'HADIR' },
        { day: 7, status: 'HADIR' },
        { day: 10, status: 'HADIR' },
        { day: 11, status: 'HADIR' },
        { day: 12, status: 'TERLAMBAT' },
        { day: 13, status: 'HADIR' },
        { day: 14, status: 'HADIR' },
        { day: 17, status: 'HADIR' },
        { day: 18, status: 'IZIN' },
        { day: 19, status: 'HADIR' },
        { day: 20, status: 'HADIR' },
        { day: 21, status: 'HADIR' },
        { day: 24, status: 'HADIR', active: true },
        { day: 25, status: 'HADIR' },
        { day: 26, status: 'HADIR' },
        { day: 27, status: 'HADIR' },
        { day: 28, status: 'HADIR' }
      ],
      selected_detail: {
        date_formatted: 'Senin, 24 Feb 2025',
        status_label: 'Hadir Tepat Waktu',
        status_color: '#10B981',
        check_in_time: '06:43 WIB',
        check_out_time: '15:30 WIB',
        verification_method: 'Terverifikasi via QR Gerbang'
      }
    }
  });
};

exports.counseling = async (req, res) => {
  ensureStudent(req);

  res.set('Cache-Control', 'no-store').json({
    data: {
      active_cases_count: 1,
      resolved_cases_count: 1,
      privacy_banner: 'Privasi Terjamin: Catatan sesi bersifat tertutup & dilindungi kode etik BK.',
      active_case: {
        id: 1,
        code: 'Berkas #BK-2025',
        status: 'Pemantauan',
        counselor: {
          name: 'Dra. Hj. Ratna Juwita, M.Pd',
          role: 'Koordinator BK'
        },
        progress_notes: 'Siswa menunjukkan komitmen adaptasi belajar yang sangat positif. Program pendampingan berkala berjalan terarah.',
        progress_phase: {
          title: 'Tahap 2: Pendampingan & Observasi',
          step: 2,
          total_steps: 3,
          steps: [
            { label: 'Konsultasi Awal (24 Feb)', done: true },
            { label: 'Berjalan', done: true },
            { label: 'Evaluasi Akhir', done: false }
          ]
        },
        upcoming_session: {
          type: 'Tatap Muka',
          date_formatted: 'Kamis, 06 Maret 2025',
          time: '09:30 WIB',
          location: 'Ruang BK 02 (Gedung A)'
        }
      },
      resolved_case: {
        id: 2,
        code: 'Berkas #BK-2024',
        status: 'Selesai',
        counselor: {
          name: 'Dra. Hj. Ratna Juwita, M.Pd',
          role: 'Koordinator BK'
        },
        progress_notes: 'Konsultasi minat bakat dan pemilihan konsentrasi mata pelajaran telah rampung.',
        completed_date: '15 Des 2024'
      }
    }
  });
};

exports.badges = async (req, res) => {
  ensureStudent(req);
  let dbBadges = [];
  try {
    dbBadges = await badgesService.collection(req.user.id);
  } catch (_) {}

  const enriched = [
    ...dbBadges,
    {
      id: 101,
      badge: 'Disiplin Emas (30 Hari)',
      nama: 'Disiplin Emas (30 Hari)',
      kategori: 'Kehadiran',
      category: 'Kehadiran',
      deskripsi: 'Hadir tepat waktu < 07:00 WIB selama 30 hari berturut-turut tanpa pelanggaran tertib sekolah.',
      description: 'Hadir tepat waktu < 07:00 WIB selama 30 hari berturut-turut tanpa pelanggaran tertib sekolah.',
      target: 30,
      progress: 30,
      diperoleh: true,
      waktu_diperoleh: '2025-02-10T08:00:00Z',
      verification_tag: 'Terverifikasi Otomatis',
      color: '#F59E0B'
    },
    {
      id: 102,
      badge: 'Juara 1 OSN Sains',
      nama: 'Juara 1 OSN Sains',
      kategori: 'Prestasi',
      category: 'Prestasi',
      deskripsi: 'Meraih juara 1 pada kompetisi sains tingkat kota/provinsi resmi.',
      description: 'Meraih juara 1 pada kompetisi sains tingkat kota/provinsi resmi.',
      target: 1,
      progress: 1,
      diperoleh: true,
      waktu_diperoleh: '2025-01-24T10:00:00Z',
      verification_tag: 'Terverifikasi Pembina',
      color: '#3B82F6'
    },
    {
      id: 103,
      badge: 'Kehadiran 100% Bulan Maret',
      nama: 'Kehadiran 100% Bulan Maret',
      kategori: 'Kehadiran',
      category: 'Kehadiran',
      deskripsi: 'Pencapaian kehadiran 100% konsisten selama satu bulan penuh tanpa terlambat.',
      description: 'Pencapaian kehadiran 100% konsisten selama satu bulan penuh tanpa terlambat.',
      target: 20,
      progress: 20,
      diperoleh: true,
      waktu_diperoleh: '2024-12-15T08:00:00Z',
      verification_tag: 'Terverifikasi Otomatis',
      color: '#10B981'
    },
    {
      id: 104,
      badge: 'Bintang Prestasi Nasional',
      nama: 'Bintang Prestasi Nasional',
      kategori: 'Prestasi',
      category: 'Prestasi',
      deskripsi: 'Meraih kejuaraan atau medali pada kompetisi tingkat nasional.',
      description: 'Meraih kejuaraan atau medali pada kompetisi tingkat nasional.',
      target: 1,
      progress: 0,
      diperoleh: false,
      waktu_diperoleh: null,
      verification_tag: 'Belum Terbuka',
      color: '#94A3B8'
    }
  ];

  res.set('Cache-Control', 'no-store').json({ data: enriched });
};

exports.extracurriculars = async (req, res) => {
  ensureStudent(req);

  const items = [
    {
      id: 1,
      name: 'Paskibraka SMAN 12',
      category: 'Kepemimpinan',
      description: 'Korps Pengibar Bendera Pusaka Sekolah',
      schedule: 'Selasa & Kamis • 15:30 - 17:30',
      coach: 'Bpk. Hendra Wijaya, S.Pd',
      status: state.enrolledEkskulIds.has(1) ? 'Terdaftar' : 'Terbuka',
      is_enrolled: state.enrolledEkskulIds.has(1),
      tag: state.enrolledEkskulIds.has(1) ? 'Terdaftar' : 'Terbuka',
      category_color: '#0D9488'
    },
    {
      id: 2,
      name: 'PMR Wira Unit 12',
      category: 'Kemanusiaan',
      description: 'Palang Merah Remaja & Pelayanan Kesehatan',
      schedule: 'Rabu • 15:45 - 17:15',
      coach: 'Ibu Dra. Nurhayati',
      status: state.enrolledEkskulIds.has(2) ? 'Terdaftar' : 'Terbuka',
      is_enrolled: state.enrolledEkskulIds.has(2),
      tag: state.enrolledEkskulIds.has(2) ? 'Terdaftar' : 'Terbuka',
      category_color: '#EF4444'
    },
    {
      id: 3,
      name: 'Robotika & Coding',
      category: 'Sains & TI',
      description: 'IoT, Robotik & Pemrograman Web',
      schedule: 'Jumat • 14:00 - 16:30',
      coach: 'Bpk. Arif Fadillah, M.Kom',
      status: state.registeredPendingEkskulIds.has(3) ? 'Menunggu Persetujuan' : 'Sisa 6 Kursi',
      is_enrolled: state.enrolledEkskulIds.has(3),
      is_pending: state.registeredPendingEkskulIds.has(3),
      tag: state.registeredPendingEkskulIds.has(3) ? 'Menunggu Persetujuan' : 'Sisa 6 Kursi',
      category_color: '#0284C7',
      remaining_seats: 6
    },
    {
      id: 4,
      name: 'Tari Pasambahan',
      category: 'Seni & Budaya',
      description: 'Seni Tradisi & Tari Kreasi Minang',
      schedule: 'Sabtu • 08:30 - 11:00',
      coach: 'Ibu Rahmi Putri, S.Sn',
      status: state.registeredPendingEkskulIds.has(4) ? 'Menunggu Persetujuan' : 'Terbuka',
      is_enrolled: state.enrolledEkskulIds.has(4),
      is_pending: state.registeredPendingEkskulIds.has(4),
      tag: state.registeredPendingEkskulIds.has(4) ? 'Menunggu Persetujuan' : 'Terbuka',
      category_color: '#8B5CF6'
    },
    {
      id: 5,
      name: 'Basket Smantubel',
      category: 'Olahraga',
      description: 'Tim Putra & Tim Putri Smantubel',
      schedule: 'Senin & Kamis • 16:00 - 18:00',
      coach: 'Bpk. Roni Kurniawan, S.Pd',
      status: state.registeredPendingEkskulIds.has(5) ? 'Menunggu Persetujuan' : 'Seleksi Fisik',
      is_enrolled: state.enrolledEkskulIds.has(5),
      is_pending: state.registeredPendingEkskulIds.has(5),
      tag: state.registeredPendingEkskulIds.has(5) ? 'Menunggu Persetujuan' : 'Seleksi Fisik',
      category_color: '#F97316'
    },
    {
      id: 6,
      name: 'Pramuka Gudep 12',
      category: 'Kepanduan',
      description: 'Penegak Bantara & Laksana',
      schedule: 'Jumat • 15:30 - 17:30',
      coach: 'Bpk. Syafril, S.Pd',
      status: state.registeredPendingEkskulIds.has(6) ? 'Menunggu Persetujuan' : 'Wajib / Pilihan',
      is_enrolled: state.enrolledEkskulIds.has(6),
      is_pending: state.registeredPendingEkskulIds.has(6),
      tag: state.registeredPendingEkskulIds.has(6) ? 'Menunggu Persetujuan' : 'Wajib / Pilihan',
      category_color: '#10B981'
    }
  ];

  res.set('Cache-Control', 'no-store').json({
    data: {
      summary: {
        enrolled_count: state.enrolledEkskulIds.size,
        academic_year: 'T.A 2024/2025'
      },
      categories: ['Semua', 'Diikuti', 'Kepemimpinan', 'Olahraga', 'Sains & TI', 'Seni & Budaya'],
      items
    }
  });
};

exports.extracurricularDetail = async (req, res) => {
  ensureStudent(req);
  const id = parseInt(req.params.id, 10);

  const isEnrolled = state.enrolledEkskulIds.has(id);
  const isPending = state.registeredPendingEkskulIds.has(id);

  res.set('Cache-Control', 'no-store').json({
    data: {
      id: id || 3,
      title: 'Robotika & Rekayasa Perangkat Lunak',
      subtitle: 'Smantubel Robotics & Code Lab',
      school: 'SMAN 12 Padang',
      category: 'TEKNOLOGI & SAINS',
      coach: 'Bpk. Arif Fadillah, M.Kom • Pembina Ekskul',
      stats: {
        active_students: '38 / 45 Siswa Aktif',
        track: 'Prestasi Peminatan',
        accreditation: 'Grade A Akreditasi'
      },
      description: 'Wadah eksplorasi teknologi terapan dan robotika bagi siswa SMAN 12 Padang yang berfokus pada logika pemrograman, mikrokontroler, dan perancangan sensor cerdas (IoT). Program ini dirancang untuk mempersiapkan siswa dalam ajang kompetisi ilmiah serta rekayasa inovasi sekolah.',
      schedule_place: {
        days_time: 'Rabu & Sabtu • 15:30 – 17:30 WIB',
        location: 'Lab Komputer 2 & Ruang STEM\nGedung B Lantai 2'
      },
      requirements: [
        'Siswa/i aktif kelas X atau XI SMAN 12 Padang.',
        'Komitmen presensi minimal 80% per semester.',
        'Membawa laptop pribadi (opsional / lab tersedia).'
      ],
      remaining_quota: 7,
      registration_status: isPending ? 'Menunggu Persetujuan' : (isEnrolled ? 'Sudah Terdaftar' : 'Pendaftaran Terbuka'),
      is_registered: isEnrolled,
      is_pending: isPending
    }
  });
};

exports.registerExtracurricular = async (req, res) => {
  ensureStudent(req);
  const id = parseInt(req.params.id, 10) || 3;

  state.registeredPendingEkskulIds.add(id);

  res.set('Cache-Control', 'no-store').json({
    data: {
      status: 'success',
      message: 'Pendaftaran Berhasil Diajukan',
      description: 'Pengajuan pendaftaran ekstrakurikuler Anda telah diterima dengan status Menunggu Persetujuan Pembina.',
      ekskul_id: id,
      status_keputusan: 'MENUNGGU_PERSETUJUAN'
    }
  });
};

exports.achievements = async (req, res) => {
  ensureStudent(req);

  const baseItems2024 = [
    {
      id: 1,
      title: 'Juara 1 Olimpiade Sains Nasional (OSN) Tingkat Kota Padang – Bidang Astronomi',
      category: 'Akademik • Kota Padang',
      reward_points: '+45 Poin',
      date: '14 Okt 2024',
      verified: true,
      attachment_name: 'Sertifikat_OSN.pdf'
    },
    {
      id: 2,
      title: 'Medali Perak Kejuaraan Karate Terbuka Pelajar Piala Gubernur Sumbar',
      category: 'Olahraga • Provinsi Sumbar',
      reward_points: '+40 Poin',
      date: '18 Agu 2024',
      verified: true,
      attachment_name: 'Piagam_Karate.jpg'
    },
    {
      id: 3,
      title: 'Juara 2 Lomba Karya Tulis Ilmiah Remaja (LKTI) Universitas Andalas',
      category: 'Riset & STEM • Universitas',
      reward_points: '+35 Poin',
      date: '12 Mei 2024',
      verified: true,
      attachment_name: 'Sertifikat_LKTI.pdf'
    },
    ...state.customAchievements
  ];

  const baseItems2023 = [
    {
      id: 4,
      title: 'Best Speaker Lomba Debat Bahasa Indonesia Tingkat SMA se–Sumatera Barat',
      category: 'Akademik • Se-Sumbar',
      reward_points: '+35 Poin',
      date: '22 Feb 2024',
      verified: true,
      attachment_name: 'Piagam_Debat.pdf'
    },
    {
      id: 5,
      title: 'Juara 1 Lomba Seni Lukis Poster Lingkungan Hidup DLH Kota Padang',
      category: 'Seni & Budaya • Kota Padang',
      reward_points: '+30 Poin',
      date: '10 Nov 2023',
      verified: true,
      attachment_name: 'Piagam_Poster.jpg'
    }
  ];

  const totalCount = baseItems2024.length + baseItems2023.length;
  const totalPoints = 185 + (state.customAchievements.length * 30);

  res.set('Cache-Control', 'no-store').json({
    data: {
      summary: {
        total_achievements: totalCount,
        total_points: totalPoints
      },
      categories: ['Semua', 'Akademik', 'Seni & Budaya', 'Olahraga', 'Riset & STEM'],
      groups: [
        {
          academic_year: '2024 / 2025',
          items: baseItems2024
        },
        {
          academic_year: '2023 / 2024',
          items: baseItems2023
        }
      ]
    }
  });
};

exports.submitAchievement = async (req, res) => {
  ensureStudent(req);
  const title = req.body?.title || req.body?.judul || 'Prestasi Baru Diajukan';
  const category = req.body?.category || 'Akademik • Sekolah';

  const newAchievement = {
    id: Date.now(),
    title,
    category,
    reward_points: '+30 Poin',
    date: 'Hari ini',
    verified: false,
    attachment_name: req.body?.attachment_name || 'Berkas_Prestasi.pdf'
  };

  state.customAchievements.unshift(newAchievement);

  res.set('Cache-Control', 'no-store').json({
    data: {
      status: 'success',
      message: 'Berkas Prestasi Berhasil Diajukan',
      description: 'Berkas prestasi telah diterima dan sedang dalam antrean verifikasi Kesiswaan / Pembina.',
      achievement: newAchievement
    }
  });
};

exports.notifications = async (req, res) => {
  ensureStudent(req);

  const notifications = [
    {
      group_name: 'Hari Ini',
      date_label: '21 April 2025',
      badge_label: '2 Baru',
      items: [
        {
          id: 1,
          category: 'PRESENSI GERBANG',
          title: 'Presensi Pagi Berhasil...',
          description: 'NIS 21084 (Ahmad Fadhil) tercatat hadir di Gerbang Utama pukul 06.45 WIB melalui pemindaian kartu RFID.',
          time_ago: '10 mnt lalu',
          unread: !state.readNotificationIds.has(1),
          tags: ['Tepat Waktu', 'Pos Satpam A'],
          icon: 'check_circle',
          type: 'attendance'
        },
        {
          id: 2,
          category: 'KETERTIBAN SISWA',
          title: 'Catatan Disiplin: Keterlambatan',
          description: 'Poin kedisiplinan bertambah +5 poin karena keterlambatan apel Senin pagi tanggal 21 April 2025.',
          time_ago: '2 jam lalu',
          unread: !state.readNotificationIds.has(2),
          tags: ['+5 Demerit', 'Guru Piket: Bpk. Hendra, S.Pd'],
          icon: 'warning',
          type: 'violation'
        }
      ]
    },
    {
      group_name: 'Kemarin',
      date_label: '20 April 2025',
      items: [
        {
          id: 3,
          category: 'APRESIASI SISWA',
          title: 'Lencana Disiplin Unggul Diterbitkan',
          description: 'Selamat! Anda memperoleh badge "Kehadiran 100% Bulan Maret" dengan rekor tanpa alpa atau izin.',
          time_ago: 'Kemarin, 14.20',
          unread: !state.readNotificationIds.has(3),
          badge_info: {
            title: 'Bintang Disiplin Maret',
            subtitle: 'Koleksi Profil Bertambah'
          },
          icon: 'workspace_premium',
          type: 'badge'
        },
        {
          id: 4,
          category: 'WARTA SEKOLAH',
          title: 'Jadwal Latihan Gabungan Paskibra',
          description: 'Pemberitahuan gladi resik upacara Hari Pendidikan Nasional di Lapangan Utama SMAN 12 Padang. Seluruh anggota wajib membawa seragam PDL lengkap.',
          time_ago: 'Kemarin, 09.00',
          unread: !state.readNotificationIds.has(4),
          tags: ['Lapangan Utama', '2 Mei 2025'],
          icon: 'campaign',
          type: 'announcement'
        }
      ]
    },
    {
      group_name: 'Minggu Ini',
      date_label: 'Pekan ke-3 April',
      items: [
        {
          id: 5,
          category: 'PERIZINAN',
          title: 'Persetujuan Izin Sakit Diterima',
          description: 'Surat keterangan dokter untuk izin tanggal 17 April 2025 telah diverifikasi oleh Wali Kelas XI MIPA 3 (Ibu Dra. Rosmaini).',
          time_ago: '3 hari lalu',
          unread: !state.readNotificationIds.has(5),
          tags: ['Status: Sah / Berizin'],
          icon: 'verified',
          type: 'permission'
        }
      ]
    }
  ];

  let unreadCount = 0;
  for (const g of notifications) {
    for (const item of g.items) {
      if (item.unread) unreadCount++;
    }
  }

  res.set('Cache-Control', 'no-store').json({
    data: {
      unread_count: unreadCount,
      filter_tabs: [
        { key: 'all', label: 'Semua', count: 5 },
        { key: 'attendance', label: 'Presensi', count: 2 },
        { key: 'violation', label: 'Pelanggaran', count: 1 }
      ],
      groups: notifications
    }
  });
};

exports.notificationDetail = async (req, res) => {
  ensureStudent(req);
  const id = parseInt(req.params.id, 10);
  state.readNotificationIds.add(id);

  res.set('Cache-Control', 'no-store').json({
    data: {
      id: id || 2,
      sikap_id: '#NOTIF-89214',
      tags: ['Ketertiban & Kedisiplinan', '! Perlu Perhatian'],
      title: 'Catatan Disiplin: Keterlambatan Apel Pagi',
      date_time: 'Senin, 21 April 2025 • 07:15 WIB (2 jam lalu)',
      student: {
        name: 'Ahmad Fadhil',
        classroom_nis: 'Kelas XI MIPA 3 • NIS 21084'
      },
      reporter: {
        name: 'Bpk. Hendra, S.Pd',
        role: 'Guru Piket Kesiswaan'
      },
      chronology: 'Siswa tercatat melewati pos gerbang barat pada pukul 07.12 WIB ketika apel bendera resmi telah dimulai.',
      rule_reference: 'Tata Tertib Bab IV Pasal 8 (2): Keterlambatan apel resmi dikenakan sanksi akumulatif demerit perilaku.',
      parameters: {
        demerit_points: '+5 Demerit',
        category: 'Kedisiplinan',
        checkpoint: 'Gerbang Barat',
        objection_deadline: '23 Apr 2025',
        rfid_verified: true
      },
      cctv_evidence: {
        title: 'Bukti CCTV Kamera Pos #02',
        timestamp: '21/04/2025 • 07:12:44 WIB'
      }
    }
  });
};

exports.markNotificationsRead = async (req, res) => {
  ensureStudent(req);
  const id = req.body?.id;
  if (id) {
    state.readNotificationIds.add(parseInt(id, 10));
  } else {
    for (let i = 1; i <= 10; i++) state.readNotificationIds.add(i);
  }

  res.set('Cache-Control', 'no-store').json({
    data: {
      status: 'success',
      message: 'Notifikasi berhasil ditandai dibaca.'
    }
  });
};
