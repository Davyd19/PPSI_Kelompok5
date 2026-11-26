// Additive migration: attendance values and legacy cutoffs are deliberately preserved.
module.exports = {
  async up(query, Sequelize) {
    const columns = await query.describeTable('sesi_presensi_sekolah');
    if (!columns.qr_aktif_mulai) await query.addColumn('sesi_presensi_sekolah', 'qr_aktif_mulai', {
      type: Sequelize.DATE(3), allowNull: true
    });
    await query.sequelize.query(`UPDATE sesi_presensi_sekolah SET qr_aktif_mulai=waktu_buka
      WHERE qr_aktif_mulai IS NULL AND token_kedaluwarsa IS NOT NULL`);
  },
  async down(query) { await query.removeColumn('sesi_presensi_sekolah', 'qr_aktif_mulai'); }
};
