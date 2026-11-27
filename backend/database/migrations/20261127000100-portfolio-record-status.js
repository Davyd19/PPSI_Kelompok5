module.exports = {
  async up(q, S) {
    const columns = await q.describeTable('portofolio');
    if (!columns.status_catatan) await q.addColumn('portofolio', 'status_catatan', {
      type: S.STRING(191),
      allowNull: false,
      defaultValue: 'AKTIF'
    });
    const [checks] = await q.sequelize.query("SELECT CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='portofolio' AND CONSTRAINT_NAME='portofolio_CK_status_catatan'");
    if (!checks.length) await q.sequelize.query("ALTER TABLE portofolio ADD CONSTRAINT portofolio_CK_status_catatan CHECK (status_catatan IN ('AKTIF','DIBATALKAN'))");
  },
  async down() {
    throw new Error('Status pembatalan menyimpan riwayat. Gunakan migrasi lanjutan.');
  }
};
