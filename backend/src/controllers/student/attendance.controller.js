'use strict';
const { Op } = require('sequelize');
const { models } = require('../../models');
const fail = require('../../utils/api-error');
const {
  ID_MONTHS_FULL,
  ensureStudent,
  getStudentProfile,
  jakartaDate,
  fmtTime,
  fmtDateLong,
} = require('./helpers');

exports.scanAttendance = async (req,res) => {
  ensureStudent(req);
  const code=req.body?.qr_code;
  if(typeof code !== 'string' || code.startsWith('EKSKUL:')) throw fail(422,'QR_INVALID','Pindai QR presensi sekolah dari Guru. Presensi ekskul dicatat Pembina.');
  const student=await getStudentProfile(req);
  const original=req.body;
  req.body={kode:code};
  let result;
  try {
    await require('../presensi-sekolah.controller').scan(req,{status(){return this;},json(payload){result=payload.data;}});
  } finally {req.body=original;}
  res.status(201).json({data:{...result,status:'success',message:'Presensi Berhasil',
    description:'Kehadiran tercatat di SIM Kesiswaan.',presensi_id:result.id,
    check_in_time:fmtTime(result.waktu_presensi),date_formatted:fmtDateLong(result.waktu_presensi),
    student_name:student.name,student_classroom:student.classroom,student_nisn:student.nisn}});
};

exports.attendanceHistory = async (req, res) => {
  ensureStudent(req);
  const student = await getStudentProfile(req);

  const [curYear, curMonth] = jakartaDate().split('-').map(Number);
  let year = parseInt(req.query.year, 10);
  let month = parseInt(req.query.month, 10);
  if (!Number.isInteger(year) || year < 2000 || year > 2100) year = curYear;
  if (!Number.isInteger(month) || month < 1 || month > 12) month = curMonth;

  const pad = (n) => String(n).padStart(2, '0');
  const lastDay = new Date(year, month, 0).getDate();
  const startDate = `${year}-${pad(month)}-01`;
  const endDate = `${year}-${pad(month)}-${pad(lastDay)}`;

  const sessions = await models.sesi.findAll({
    where: { tanggal: { [Op.between]: [startDate, endDate] } },
    order: [['tanggal', 'ASC']],
  });

  const sessionIds = sessions.map((s) => s.id);
  const presensiRows = sessionIds.length > 0
    ? await models.presensi.findAll({
        where: { id_siswa: req.user.id, id_sesi_presensi_sekolah: { [Op.in]: sessionIds } },
      })
    : [];

  const bySession = {};
  for (const p of presensiRows) bySession[p.id_sesi_presensi_sekolah] = p;

  const STATUS_LABELS = {
    HADIR: 'Hadir Tepat Waktu',
    TERLAMBAT: 'Terlambat',
    IZIN: 'Izin',
    SAKIT: 'Sakit',
    ALFA: 'Tidak Hadir (Alfa)',
  };
  const METODE_LABELS = {
    QR_SCAN: 'Terverifikasi via QR Gerbang',
    MANUAL_PIN: 'Input Manual PIN Guru Piket',
    MANUAL: 'Dicatat manual oleh Guru Piket',
  };

  const todayStr = jakartaDate();
  let stats = { hadir: 0, telat: 0, izin: 0, alfa: 0 };
  const calendar_records = [];

  for (const s of sessions) {
    const p = bySession[s.id];
    const tanggalStr = typeof s.tanggal === 'string' ? s.tanggal.slice(0, 10) : jakartaDate(s.tanggal);
    const dayNum = parseInt(tanggalStr.slice(8, 10), 10);
    if (p) {
      const st = p.status_kehadiran;
      if (st === 'HADIR') stats.hadir++;
      else if (st === 'TERLAMBAT') stats.telat++;
      else if (st === 'IZIN' || st === 'SAKIT') stats.izin++;
      else stats.alfa++;

      calendar_records.push({
        day: dayNum,
        date: tanggalStr,
        status: st,
        date_formatted: fmtDateLong(tanggalStr),
        status_label: STATUS_LABELS[st] ?? st,
        check_in_time: fmtTime(p.waktu_presensi),
        check_out_time: null,
        verification_method: METODE_LABELS[p.metode] ?? (p.metode || '-'),
        keterangan: p.keterangan ?? null,
        presensi_id: p.id,
      });
    } else {
      if (tanggalStr === todayStr && s.status !== 'DITUTUP') {
        continue;
      }
      calendar_records.push({
        day: dayNum,
        date: tanggalStr,
        status: 'BELUM_DIISI',
        date_formatted: fmtDateLong(tanggalStr),
        status_label: 'Belum Diisi',
        check_in_time: null,
        check_out_time: null,
        verification_method: '-',
        keterangan: null,
        presensi_id: null,
      });
    }
  }

  const totalCounted = calendar_records.filter(r=>!['BELUM_DIISI','PENGECUALIAN_SAH','PENGECUALIAN_SAH_ZUHUR'].includes(r.status)).length;
  const ratePercentage = totalCounted > 0
    ? Math.round(((stats.hadir + stats.telat) / totalCounted) * 1000) / 10
    : 0;

  const selectedDay = parseInt(req.query.day ?? 0, 10);
  let selectedDetail = null;
  if (selectedDay > 0) {
    const rec = calendar_records.find((r) => r.day === selectedDay);
    if (rec) {
      selectedDetail = {
        date_formatted: rec.date_formatted,
        status_label: rec.status_label,
        status_color: rec.status === 'HADIR'
          ? '#10B981'
          : rec.status === 'TERLAMBAT'
            ? '#F59E0B'
            : rec.status === 'ALFA'
              ? '#EF4444'
              : '#94A3B8',
        check_in_time: rec.check_in_time,
        check_out_time: rec.check_out_time,
        verification_method: rec.verification_method,
        keterangan: rec.keterangan,
      };
    }
  }

  const monthName = `${ID_MONTHS_FULL[month - 1]} ${year}`;
  const semester = await models.semester.findOne({
    where: { tanggal_mulai: { [Op.lte]: endDate }, tanggal_selesai: { [Op.gte]: startDate } },
    include: [{ model: models.tahun, as: 'tahun_ajaran', required: false }],
    order: [['tanggal_mulai', 'DESC']],
  });
  const semesterName = semester ? `${semester.nama} T.A. ${semester.tahun_ajaran?.nama ?? ''}` : '';

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
