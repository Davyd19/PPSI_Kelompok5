// Use case Guru "Menginput Laporan Pelanggaran": tempat kejadian + bukti pendukung.
module.exports = {
  async up(q, S) {
    await q.addColumn('laporan_pelanggaran', 'tempat_kejadian', { type: S.STRING(191), allowNull: true });
    await q.createTable('lampiran_laporan_pelanggaran', {
      id: { type: S.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true, allowNull: false },
      id_laporan_pelanggaran: {
        type: S.INTEGER.UNSIGNED, allowNull: false,
        references: { model: 'laporan_pelanggaran', key: 'id' }, onDelete: 'RESTRICT', onUpdate: 'RESTRICT'
      },
      nama_berkas: { type: S.STRING(191), allowNull: false },
      lokasi_berkas: { type: S.STRING(191), allowNull: false },
      jenis_berkas: { type: S.STRING(191), allowNull: false },
      waktu_unggah: { type: S.DATE(3), allowNull: false }
    }, { engine: 'InnoDB', charset: 'utf8mb4', collate: 'utf8mb4_unicode_ci' });
    await q.addIndex('lampiran_laporan_pelanggaran', ['lokasi_berkas'], { unique: true, name: 'uq_lampiran_laporan_1' });
    await q.addIndex('lampiran_laporan_pelanggaran', ['id_laporan_pelanggaran'], { name: 'ix_lampiran_laporan_id_laporan' });
  },
  async down(q) {
    await q.dropTable('lampiran_laporan_pelanggaran');
    await q.removeColumn('laporan_pelanggaran', 'tempat_kejadian');
  }
};
