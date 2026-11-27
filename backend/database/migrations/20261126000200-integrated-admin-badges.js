module.exports = {
  async up(q, S) {
    const [checks] = await q.sequelize.query("SELECT CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='level_badge' AND CONSTRAINT_TYPE='CHECK' AND CONSTRAINT_NAME='level_CK_sumber_badge'");
    if (checks.length) await q.sequelize.query('ALTER TABLE level_badge DROP CHECK `level_CK_sumber_badge`');
    await q.changeColumn('level_badge', 'status_kehadiran_yang_dihitung', {
      type: S.STRING(191),
      allowNull: true
    });
    const level = await q.describeTable('level_badge');
    if (!level.id_ekstrakurikuler) await q.addColumn('level_badge', 'id_ekstrakurikuler', {
      type: S.INTEGER.UNSIGNED,
      allowNull: true,
      references: {
        model: 'ekstrakurikuler',
        key: 'id'
      },
      onDelete: 'RESTRICT',
      onUpdate: 'RESTRICT'
    });
    const earned = await q.describeTable('pencapaian_badge');
    for (const name of ['periode_bukti_mulai', 'periode_bukti_selesai']) if (!earned[name]) await q.addColumn('pencapaian_badge', name, {
      type: S.DATEONLY,
      allowNull: true
    });
    const [current] = await q.sequelize.query("SELECT CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='level_badge' AND CONSTRAINT_NAME='level_CK_source_context'");
    if (!current.length) await q.sequelize.query(`ALTER TABLE level_badge ADD CONSTRAINT level_CK_source_context CHECK (
    (sumber_data='PRESENSI_SEKOLAH' AND jenis_presensi IS NOT NULL AND status_kehadiran_yang_dihitung IS NOT NULL AND id_ekstrakurikuler IS NULL)
    OR (sumber_data='PRESENSI_EKSKUL' AND jenis_presensi IS NULL AND status_kehadiran_yang_dihitung IS NOT NULL)
    OR (sumber_data IN ('PRESTASI','KEGIATAN','KEANGGOTAAN_EKSKUL','PELANGGARAN') AND jenis_presensi IS NULL AND status_kehadiran_yang_dihitung IS NULL)
  )`);
  },
  async down() {
    throw new Error('Migrasi ini memuat konfigurasi badge baru. Gunakan migrasi lanjutan agar data tidak hilang.');
  }
};
