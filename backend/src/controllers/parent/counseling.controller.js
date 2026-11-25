'use strict';
const { Op } = require('sequelize');
const { models } = require('../../models');
const fail = require('../../utils/api-error');
const {
  requireParent,
  jakartaDate,
  fmtDate,
  fmtDateLong,
  fmtTime,
  resolveChildContext,
  getHomeroomTeacher,
} = require('./helpers');

async function formatParentCounselingCase(p, semesterLabel) {
  const counselor = p.guru_bk_penanggung_jawab;
  const [riwayats, rencana] = await Promise.all([
    models.riwayat.findAll({
      where: { id_penanganan_siswa: p.id },
      order: [['waktu', 'DESC']],
      raw: true,
    }),
    models.rencana.findOne({
      where: { id_penanganan_siswa: p.id, status: { [Op.notIn]: ['SELESAI', 'DIBATALKAN'] } },
      order: [['jadwal', 'ASC']],
      raw: true,
    }),
  ]);

  // Privasi: JANGAN pernah menampilkan isi_internal, hanya ringkasan_diizinkan.
  const permittedSteps = riwayats.map((r) => ({
    id: r.id,
    jenis: r.jenis,
    date: fmtDate(r.waktu),
    summary: r.ringkasan_diizinkan ?? null,
    parent_involved: Boolean(r.orang_tua_dilibatkan),
    follow_up: r.arahan_tindak_lanjut ?? null,
  }));

  return {
    id: p.id,
    code: `ID: BK-${p.id}`,
    status: p.status,
    status_label: p.status === 'SELESAI' ? 'Selesai' : 'Dalam Pemantauan Positif',
    date_opened: fmtDate(p.tanggal_dibuka),
    title: p.alasan_pembukaan ?? 'Pendampingan Bimbingan Konseling',
    counselor: counselor
      ? { name: counselor.nama, role: 'Guru Pembimbing / Konselor BK', telepon: counselor.telepon ?? null }
      : null,
    summary: p.ringkasan_diizinkan ?? null,
    home_advice: rencana?.rencana_tindak_lanjut ?? null,
    upcoming_session: rencana
      ? {
          type: rencana.bentuk_kegiatan,
          goal: rencana.tujuan ?? null,
          date_formatted: fmtDateLong(rencana.jadwal),
          time: fmtTime(rencana.jadwal),
        }
      : null,
    history: permittedSteps,
    semester_label: semesterLabel,
  };
}

exports.counseling = async (req, res) => {
  requireParent(req);
  const { children, child } = await resolveChildContext(req);
  const today = jakartaDate();
  const activeSemester = await models.semester.findOne({
    where: { tanggal_mulai: { [Op.lte]: today }, tanggal_selesai: { [Op.gte]: today } },
    order: [['tanggal_mulai', 'DESC']],
  });
  const semesterLabel = activeSemester ? `Sem. ${activeSemester.nama}` : '';

  if (!child) {
    return res.set('Cache-Control', 'no-store').json({
      data: { children: [], child: null, items: [], homeroom_teacher: null },
    });
  }

  const [penangananList, homeroomTeacher] = await Promise.all([
    models.penanganan.findAll({
      where: { id_siswa: child.id },
      include: [{ model: models.guru, as: 'guru_bk_penanggung_jawab', required: false }],
      order: [['tanggal_dibuka', 'DESC'], ['id', 'DESC']],
    }),
    getHomeroomTeacher(child.classroom_id),
  ]);

  const items = [];
  for (const p of penangananList) {
    items.push(await formatParentCounselingCase(p, semesterLabel));
  }

  res.set('Cache-Control', 'no-store').json({
    data: { children, child, items, homeroom_teacher: homeroomTeacher },
  });
};

exports.counselingDetail = async (req, res) => {
  requireParent(req);
  const { child } = await resolveChildContext(req);
  const caseId = parseInt(req.params.id, 10);
  if (!child || !Number.isInteger(caseId)) {
    throw fail(404, 'NOT_FOUND', 'Informasi penanganan tidak dapat diakses.');
  }

  const p = await models.penanganan.findOne({
    where: { id: caseId, id_siswa: child.id },
    include: [{ model: models.guru, as: 'guru_bk_penanggung_jawab', required: false }],
  });
  if (!p) {
    throw fail(403, 'FORBIDDEN', 'Informasi penanganan tidak dapat diakses.');
  }

  const today = jakartaDate();
  const activeSemester = await models.semester.findOne({
    where: { tanggal_mulai: { [Op.lte]: today }, tanggal_selesai: { [Op.gte]: today } },
    order: [['tanggal_mulai', 'DESC']],
  });
  const semesterLabel = activeSemester ? `Sem. ${activeSemester.nama}` : '';

  res.set('Cache-Control', 'no-store').json({
    data: await formatParentCounselingCase(p, semesterLabel),
  });
};
