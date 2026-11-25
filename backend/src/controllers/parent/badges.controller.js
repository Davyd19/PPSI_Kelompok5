'use strict';
const { models } = require('../../models');
const { requireParent, fmtDate, resolveChildContext } = require('./helpers');

exports.badges = async (req, res) => {
  requireParent(req);
  const { children, child } = await resolveChildContext(req);
  if (!child) {
    return res.set('Cache-Control', 'no-store').json({
      data: { children: [], child: null, summary: { earned: 0, total: 0 }, items: [] },
    });
  }

  const levels = await models.level.findAll({
    include: [
      {
        model: models.versi_badge,
        as: 'versi_aturan_badge',
        required: true,
        include: [{ model: models.badge, as: 'badge', required: true }],
      },
    ],
    order: [['id_versi_aturan_badge', 'ASC'], ['urutan', 'ASC'], ['id', 'ASC']],
  });

  const achieved = await models.pencapaian.findAll({
    where: { id_siswa: child.id, aktif: true },
    raw: true,
  });
  const achievedMap = new Map();
  for (const a of achieved) achievedMap.set(a.id_level_badge, a);

  const levelsByVersi = new Map();
  for (const lv of levels) {
    if (!levelsByVersi.has(lv.id_versi_aturan_badge)) {
      levelsByVersi.set(lv.id_versi_aturan_badge, []);
    }
    levelsByVersi.get(lv.id_versi_aturan_badge).push(lv);
  }

  const items = levels.map((lv) => {
    const versi = lv.versi_aturan_badge;
    const badge = versi?.badge;
    const rec = achievedMap.get(lv.id);
    const earned = Boolean(rec);
    const siblingLevels = levelsByVersi.get(lv.id_versi_aturan_badge) ?? [lv];
    const idx = siblingLevels.findIndex((x) => x.id === lv.id);
    const nextLv = idx >= 0 && idx + 1 < siblingLevels.length ? siblingLevels[idx + 1] : null;

    const syarat = `Capai ${lv.target} ${lv.status_kehadiran_yang_dihitung ?? 'catatan'} pada ${lv.sumber_data ?? 'kegiatan sekolah'}`;

    return {
      id: lv.id,
      badge: badge?.nama ?? 'Badge',
      nama: lv.nama,
      urutan: lv.urutan,
      kategori: lv.sumber_data,
      deskripsi: badge?.deskripsi ?? null,
      syarat,
      target: lv.target,
      progress: earned ? lv.target : 0,
      diperoleh: earned,
      waktu_diperoleh: rec ? fmtDate(rec.waktu_diperoleh) : null,
      is_max_level: nextLv === null,
      next_level: nextLv
        ? {
            nama: nextLv.nama,
            target: nextLv.target,
            syarat: `Capai ${nextLv.target} ${nextLv.status_kehadiran_yang_dihitung ?? 'catatan'}`,
          }
        : null,
    };
  });

  const earnedCount = items.filter((i) => i.diperoleh).length;

  res.set('Cache-Control', 'no-store').json({
    data: {
      children,
      child,
      summary: { earned: earnedCount, total: items.length },
      items,
    },
  });
};
