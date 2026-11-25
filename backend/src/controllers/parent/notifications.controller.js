'use strict';
const { models } = require('../../models');
const fail = require('../../utils/api-error');
const {
  requireParent,
  jakartaDate,
  fmtDate,
  fmtDateLong,
  fmtTime,
  resolveChildContext,
} = require('./helpers');

exports.notifications = async (req, res) => {
  requireParent(req);
  const { child } = await resolveChildContext(req);

  const penerimas = await models.penerima.findAll({
    where: { id_orang_tua: req.user.id },
    include: [{ model: models.notifikasi, as: 'notifikasi', required: true }],
    order: [[{ model: models.notifikasi, as: 'notifikasi' }, 'waktu_dibuat', 'DESC']],
  });

  if (penerimas.length === 0) {
    return res.set('Cache-Control', 'no-store').json({
      data: {
        child_name: child?.name ?? null,
        unread_count: 0,
        filter_tabs: [],
        groups: [],
      },
    });
  }

  const unreadCount = penerimas.filter((p) => !p.waktu_dibaca).length;
  const todayStr = jakartaDate();
  const [ty, tm, td] = todayStr.split('-').map(Number);
  const ystStr = jakartaDate(new Date(Date.UTC(ty, tm - 1, td - 1)));

  const groupsMap = {};
  const typeCounts = {};

  for (const pn of penerimas) {
    const notif = pn.notifikasi;
    const created = new Date(notif.waktu_dibuat);
    const dateStr = jakartaDate(created);
    const [cy, cm, cd] = dateStr.split('-').map(Number);
    const diffDays = Math.round((Date.UTC(ty, tm - 1, td) - Date.UTC(cy, cm - 1, cd)) / 86400000);

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
      child_name: child?.name ?? null,
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
    ...Object.entries(typeCounts).map(([k, v]) => ({
      key: k,
      label: k.charAt(0).toUpperCase() + k.slice(1).toLowerCase(),
      count: v,
    })),
  ];

  res.set('Cache-Control', 'no-store').json({
    data: {
      child_name: child?.name ?? null,
      unread_count: unreadCount,
      filter_tabs: filterTabs,
      groups,
    },
  });
};

exports.notificationDetail = async (req, res) => {
  requireParent(req);
  const { child } = await resolveChildContext(req);
  const pnId = parseInt(req.params.id, 10);

  const pn = await models.penerima.findOne({
    where: { id: pnId, id_orang_tua: req.user.id },
    include: [{ model: models.notifikasi, as: 'notifikasi', required: true }],
  });
  if (!pn) throw fail(404, 'NOT_FOUND', 'Informasi tidak tersedia atau tidak dapat diakses.');

  if (!pn.waktu_dibaca) await pn.update({ waktu_dibaca: new Date() });

  const notif = pn.notifikasi;
  res.set('Cache-Control', 'no-store').json({
    data: {
      id: pn.id,
      notif_id: notif.id,
      jenis: notif.jenis,
      title: notif.judul,
      isi: notif.isi,
      child_name: child?.name ?? null,
      date_time: fmtDateLong(notif.waktu_dibuat),
      time: fmtTime(notif.waktu_dibuat),
      unread: false,
    },
  });
};

exports.markNotificationsRead = async (req, res) => {
  requireParent(req);
  const { id } = req.body ?? {};
  if (id) {
    await models.penerima.update(
      { waktu_dibaca: new Date() },
      { where: { id: parseInt(id, 10), id_orang_tua: req.user.id, waktu_dibaca: null } },
    );
  } else {
    await models.penerima.update(
      { waktu_dibaca: new Date() },
      { where: { id_orang_tua: req.user.id, waktu_dibaca: null } },
    );
  }
  res.set('Cache-Control', 'no-store').json({
    data: { status: 'success', message: 'Notifikasi berhasil ditandai dibaca.' },
  });
};
