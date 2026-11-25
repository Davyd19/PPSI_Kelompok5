// Compatible with both a fresh database and the earlier teacher-reports migration.
module.exports = {
  async up(q, S) {
    const tables = (await q.showAllTables()).map(t => typeof t === 'string' ? t : Object.values(t)[0]);
    const canonical = 'lampiran_laporan_pelanggaran';
    const legacy = 'bukti_laporan';
    if (tables.includes(legacy) && tables.includes(canonical)) {
      const [[row]] = await q.sequelize.query('SELECT COUNT(*) AS total FROM `bukti_laporan`');
      if (Number(row.total)) throw new Error('Dua tabel bukti berisi/berpotensi berisi data. Rekonsiliasi bukti_laporan dan lampiran_laporan_pelanggaran diperlukan; tidak ada data yang dihapus.');
    }
    if (tables.includes(legacy) && !tables.includes(canonical)) {
      const fields = await q.describeTable(legacy);
      for (const name of ['id','id_laporan_pelanggaran','nama_berkas','lokasi_berkas','jenis_berkas','waktu_unggah']) {
        if (!fields[name]) throw new Error('Struktur bukti_laporan tidak dikenali: kolom '+name+' tidak ada.');
      }
      // Rename keeps existing IDs, metadata and references; no evidence rows are discarded.
      await q.renameTable(legacy,canonical);
    } else if (!tables.includes(canonical)) {
      await q.createTable(canonical, {
        id:{type:S.INTEGER.UNSIGNED,primaryKey:true,autoIncrement:true,allowNull:false},
        id_laporan_pelanggaran:{type:S.INTEGER.UNSIGNED,allowNull:false,references:{model:'laporan_pelanggaran',key:'id'},onDelete:'RESTRICT',onUpdate:'RESTRICT'},
        nama_berkas:{type:S.STRING(191),allowNull:false},
        lokasi_berkas:{type:S.STRING(191),allowNull:false},
        jenis_berkas:{type:S.STRING(191),allowNull:false},
        waktu_unggah:{type:S.DATE(3),allowNull:false}
      },{engine:'InnoDB',charset:'utf8mb4',collate:'utf8mb4_unicode_ci'});
    }
    const report = await q.describeTable('laporan_pelanggaran');
    if (!report.tempat_kejadian) await q.addColumn('laporan_pelanggaran','tempat_kejadian',{type:S.STRING(191),allowNull:true});
    const evidence = await q.describeTable(canonical);
    // Old rows retain their size, while the new uploader need not supply this legacy column.
    if (evidence.ukuran && !evidence.ukuran.allowNull) await q.changeColumn(canonical,'ukuran',{type:S.INTEGER.UNSIGNED,allowNull:true});
    const indices = await q.showIndex(canonical);
    if (!indices.some(i=>i.unique && i.fields.length===1 && i.fields[0].attribute==='lokasi_berkas')) {
      await q.addIndex(canonical,['lokasi_berkas'],{unique:true,name:'uq_lampiran_laporan_1'});
    }
    if (!indices.some(i=>i.fields[0]?.attribute==='id_laporan_pelanggaran')) {
      await q.addIndex(canonical,['id_laporan_pelanggaran'],{name:'ix_lampiran_laporan_id_laporan'});
    }
  },
  async down() {
    throw new Error('Rollback otomatis dinonaktifkan untuk menjaga bukti dan kolom laporan lama. Gunakan migrasi lanjutan yang ditinjau.');
  }
};
