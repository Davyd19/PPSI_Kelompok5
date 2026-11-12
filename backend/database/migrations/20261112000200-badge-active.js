module.exports = {
  async up(q, S) {
    await q.addColumn('pencapaian_badge', 'aktif', { type: S.BOOLEAN, allowNull: false, defaultValue: true });
    await q.addColumn('pencapaian_badge', 'waktu_perubahan_status', { type: S.DATE(3), allowNull: true });
  },
  async down(q) {
    await q.removeColumn('pencapaian_badge', 'waktu_perubahan_status');
    await q.removeColumn('pencapaian_badge', 'aktif');
  }
};
