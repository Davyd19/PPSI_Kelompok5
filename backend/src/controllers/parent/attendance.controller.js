'use strict';
const { Op } = require('sequelize');
const { models } = require('../../models');
const {
  ID_MONTHS_FULL,
  requireParent,
  jakartaDate,
  fmtTime,
  fmtDateLong,
  resolveChildContext,
} = require('./helpers');

exports.attendanceHistory = async (req, res) => {
  requireParent(req);
  const { children, child } = await resolveChildContext(req);
  const [curYear, curMonth] = jakartaDate().split('-').map(Number);

  let year = parseInt(req.query.year, 10);
  let month = parseInt(req.query.month, 10);
  if (!Number.isInteger(year) || year < 2000 || year > 2100) year = curYear;
  if (!Number.isInteger(month) || month < 1 || month > 12) month = curMonth;

  const jenisFilter = typeof req.query.jenis === 'string' && ['PAGI', 'ZUHUR'].includes(req.query.jenis.toUpperCase())
    ? req.query.jenis.toUpperCase()
    : 'ALL';

  const pad = (n) => String(n).padStart(2, '0');
  const lastDay = new Date(year, month, 0).getDate();
  const startDate = `${year}-${pad(month)}-01`;
  const endDate = `${year}-${pad(month)}-${pad(lastDay)}`;
  const monthName = `${ID_MONTHS_FULL[month - 1]} ${year}`;

  if (!child) {
    return res.set('Cache-Control', 'no-store').json({
      data: {
        children: [],
        child: null,
        month_name: monthName,
        current_year: year,
        current_month: month,
        jenis_filter: jenisFilter,
        stats: { hadir: 0, izin: 0, telat: 0, alfa: 0, rate_percentage: 0 },
        calendar_records: [],
      },
    });
  }

  const sessionWhere = { tanggal: { [Op.between]: [startDate, endDate] } };
  if (jenisFilter !== 'ALL') sessionWhere.jenis_sesi = jenisFilter;

  const sessions = await models.sesi.findAll({
    where: sessionWhere,
    order: [['tanggal', 'ASC'], ['id', 'ASC']],
    raw: true,
  });
  const sessionIds = sessions.map((s) => s.id);
  const presensiRows = sessionIds.length > 0
    ? await models.presensi.findAll({
        where: { id_siswa: child.id, id_sesi_presensi_sekolah: { [Op.in]: sessionIds } },
        raw: true,
      })
    : [];
  const bySession = new Map();
  for (const p of presensiRows) bySession.set(p.id_sesi_presensi_sekolah, p);

  const STATUS_LABELS = {
    HADIR: 'Hadir',
    TERLAMBAT: 'Terlambat',
    IZIN: 'Izin',
    SAKIT: 'Sakit',
    ALFA: 'Alfa',
    PENGECUALIAN_SAH: 'Pengecualian Sah',
  };
  const METODE_LABELS = {
    QR_SCAN: 'Terverifikasi via QR Gerbang',
    MANUAL_PIN: 'Input Manual PIN Guru Piket',
    MANUAL: 'Dicatat manual oleh Guru Piket',
  };

  const todayStr = jakartaDate();
  const stats = { hadir: 0, izin: 0, telat: 0, alfa: 0 };
  const calendar_records = [];

  for (const s of sessions) {
    const p = bySession.get(s.id);
    const tanggalStr = typeof s.tanggal === 'string' ? s.tanggal.slice(0, 10) : jakartaDate(s.tanggal);
    const dayNum = parseInt(tanggalStr.slice(8, 10), 10);
    if (p) {
      const st = p.status_kehadiran;
      if (st === 'HADIR') stats.hadir++;
      else if (st === 'TERLAMBAT') stats.telat++;
      else if (st === 'IZIN' || st === 'SAKIT') stats.izin++;
      else if (st === 'ALFA') stats.alfa++;

      calendar_records.push({
        day: dayNum,
        date: tanggalStr,
        jenis_sesi: s.jenis_sesi,
        jenis_label: s.jenis_sesi === 'ZUHUR' ? 'Salat Zuhur' : 'Presensi Pagi',
        status: st,
        date_formatted: fmtDateLong(tanggalStr),
        status_label: STATUS_LABELS[st] ?? st,
        check_in_time: fmtTime(p.waktu_presensi),
        check_out_time: null,
        verification_method: METODE_LABELS[p.metode] ?? (p.metode || '-'),
        keterangan: p.keterangan ?? null,
      });
    } else if (!(tanggalStr === todayStr && s.status !== 'DITUTUP')) {
      stats.alfa++;
      calendar_records.push({
        day: dayNum,
        date: tanggalStr,
        jenis_sesi: s.jenis_sesi,
        jenis_label: s.jenis_sesi === 'ZUHUR' ? 'Salat Zuhur' : 'Presensi Pagi',
        status: 'ALFA',
        date_formatted: fmtDateLong(tanggalStr),
        status_label: 'Alfa',
        check_in_time: null,
        check_out_time: null,
        verification_method: '-',
        keterangan: null,
      });
    }
  }

  const totalCounted = calendar_records.length;
  const ratePercentage = totalCounted > 0
    ? Math.round(((stats.hadir + stats.telat) / totalCounted) * 1000) / 10
    : 0;

  res.set('Cache-Control', 'no-store').json({
    data: {
      children,
      child,
      month_name: monthName,
      current_year: year,
      current_month: month,
      jenis_filter: jenisFilter,
      stats: { ...stats, rate_percentage: ratePercentage },
      calendar_records,
    },
  });
};
