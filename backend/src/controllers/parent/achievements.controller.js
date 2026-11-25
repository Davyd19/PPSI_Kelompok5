'use strict';
const { Op } = require('sequelize');
const { models } = require('../../models');
const { requireParent, fmtDate, pointsFromHasil, resolveChildContext } = require('./helpers');

exports.achievements = async (req, res) => {
  requireParent(req);
  const { children, child } = await resolveChildContext(req);
  if (!child) {
    return res.set('Cache-Control', 'no-store').json({
      data: {
        children: [],
        child: null,
        summary: { total: 0, provinsi: 0, nasional: 0, total_points: 0 },
        items: [],
      },
    });
  }

  const participations = await models.peserta.findAll({
    where: { id_siswa: child.id },
    include: [
      {
        model: models.portofolio,
        as: 'portofolio',
        required: true,
        where: { jenis: 'PRESTASI' },
        include: [
          { model: models.guru, as: 'guru_pencatat', required: false },
          {
            model: models.periode_ekskul,
            as: 'periode_ekstrakurikuler',
            required: false,
            include: [{ model: models.ekskul, as: 'ekstrakurikuler', required: false }],
          },
        ],
      },
    ],
    order: [[{ model: models.portofolio, as: 'portofolio' }, 'tanggal', 'DESC']],
  });

  const portIds = participations.map((p) => p.portofolio.id);
  const lampiranRows = portIds.length > 0
    ? await models.lampiran.findAll({ where: { id_portofolio: { [Op.in]: portIds } }, raw: true })
    : [];
  const attachmentsByPort = new Map();
  for (const l of lampiranRows) {
    if (!attachmentsByPort.has(l.id_portofolio)) attachmentsByPort.set(l.id_portofolio, []);
    attachmentsByPort.get(l.id_portofolio).push({
      id: l.id,
      nama_berkas: l.nama_berkas,
      jenis_berkas: l.jenis_berkas,
      lokasi_berkas: l.lokasi_berkas,
      tersedia: Boolean(l.lokasi_berkas && !l.lokasi_berkas.startsWith('seed://')),
    });
  }

  let provinsi = 0;
  let nasional = 0;
  let totalPoints = 0;

  const items = participations.map((pp) => {
    const port = pp.portofolio;
    const tingkat = (port.tingkat_prestasi ?? 'SEKOLAH').toUpperCase();
    if (tingkat.includes('PROVINSI')) provinsi++;
    if (tingkat.includes('NASIONAL') || tingkat.includes('INTERNASIONAL')) nasional++;
    const pts = pointsFromHasil(port.hasil_prestasi);
    totalPoints += pts;

    return {
      id: port.id,
      title: port.judul,
      activity_name: port.periode_ekstrakurikuler?.ekstrakurikuler?.nama ?? null,
      tingkat: port.tingkat_prestasi ?? 'Sekolah',
      hasil: port.hasil_prestasi ?? null,
      nama_tim: port.nama_tim ?? null,
      deskripsi: port.deskripsi ?? null,
      date: fmtDate(port.tanggal),
      reward_points: `+${pts} Poin`,
      verified_by: port.guru_pencatat?.nama ?? 'Tim Kesiswaan SMAN 12 Padang',
      verified: true,
      attachments: attachmentsByPort.get(port.id) ?? [],
    };
  });

  res.set('Cache-Control', 'no-store').json({
    data: {
      children,
      child,
      summary: { total: items.length, provinsi, nasional, total_points: totalPoints },
      items,
    },
  });
};
