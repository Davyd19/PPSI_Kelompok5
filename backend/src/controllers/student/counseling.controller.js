'use strict';
const { Op } = require('sequelize');
const { models } = require('../../models');
const { ensureStudent, fmtDate, fmtDateLong, fmtTime } = require('./helpers');

exports.counseling = async (req, res) => {
  ensureStudent(req);

  const penangananList = await models.penanganan.findAll({
    where: { id_siswa: req.user.id },
    order: [['tanggal_dibuka', 'DESC']],
    include: [{ model: models.guru, as: 'guru_bk_penanggung_jawab', required: false }],
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
    const counselor = p.guru_bk_penanggung_jawab;
    const riwayats = await models.riwayat.findAll({
      where: { id_penanganan_siswa: p.id },
      order: [['waktu', 'ASC']],
    });
    const rencana = await models.rencana.findOne({
      where: { id_penanganan_siswa: p.id, status: { [Op.notIn]: ['SELESAI', 'DIBATALKAN'] } },
      order: [['jadwal', 'ASC']],
    });
    const steps = riwayats.map((r) => ({
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
      upcoming_session: rencana
        ? {
            type: rencana.bentuk_kegiatan,
            date_formatted: fmtDateLong(rencana.jadwal),
            time: fmtTime(rencana.jadwal),
            location: null,
          }
        : null,
      completed_date: p.status === 'SELESAI' ? fmtDate(p.tanggal_dibuka) : null,
    };
  }

  const activeCases = penangananList.filter((p) => p.status !== 'SELESAI');
  const resolvedCases = penangananList.filter((p) => p.status === 'SELESAI');

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
