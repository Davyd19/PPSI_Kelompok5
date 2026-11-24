'use strict';
const { models } = require('../../models');
const { ensureStudent } = require('./helpers');

exports.badges = async (req, res) => {
  ensureStudent(req);

  const levels = await models.level.findAll({
    include: [
      {
        model: models.versi_badge,
        as: 'versi_aturan_badge',
        required: true,
        include: [{ model: models.badge, as: 'badge', required: true }],
      },
    ],
    order: [['id', 'ASC']],
  });

  const achieved = await models.pencapaian.findAll({ where: { id_siswa: req.user.id, aktif: true } });
  const achievedLevelIds = new Set(achieved.map((a) => a.id_level_badge));
  const achievedMap = {};
  for (const a of achieved) achievedMap[a.id_level_badge] = a;

  if (levels.length === 0) {
    return res.set('Cache-Control', 'no-store').json({ data: [] });
  }

  const result = levels.map((lv) => {
    const versi = lv.versi_aturan_badge;
    const badge = versi?.badge;
    const isAchieved = achievedLevelIds.has(lv.id);
    const achievementRecord = achievedMap[lv.id];

    return {
      id: lv.id,
      badge: badge?.nama ?? 'Badge',
      nama: lv.nama,
      kategori: lv.sumber_data,
      category: lv.sumber_data,
      deskripsi: badge?.deskripsi ?? null,
      description: badge?.deskripsi ?? null,
      target: lv.target,
      progress: isAchieved ? lv.target : 0,
      sementara: !isAchieved,
      diperoleh: isAchieved,
      waktu_diperoleh: achievementRecord ? achievementRecord.waktu_diperoleh : null,
      verification_tag: isAchieved ? 'Terverifikasi Otomatis' : 'Belum Diperoleh',
    };
  });

  res.set('Cache-Control', 'no-store').json({ data: result });
};
