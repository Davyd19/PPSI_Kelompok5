// Existing business rows and historical role assignments are retained.
const SPECIAL = ['ADMIN','KESISWAAN','KEPALA_SEKOLAH','GURU_BK'];
module.exports = {
  async up(query, Sequelize) {
    const [conflicts] = await query.sequelize.query(`SELECT g.id,g.identitas_login,
      GROUP_CONCAT(DISTINCT p.kode ORDER BY p.kode) AS peran
      FROM guru g JOIN guru_peran gp ON gp.id_guru=g.id JOIN peran p ON p.id=gp.id_peran
      WHERE p.kode IN ('ADMIN','KESISWAAN','KEPALA_SEKOLAH','GURU_BK')
      AND gp.tanggal_mulai<=DATE(CONVERT_TZ(UTC_TIMESTAMP(),'+00:00','+07:00'))
      AND (gp.tanggal_selesai IS NULL OR gp.tanggal_selesai>=DATE(CONVERT_TZ(UTC_TIMESTAMP(),'+00:00','+07:00')))
      GROUP BY g.id,g.identitas_login HAVING COUNT(DISTINCT p.kode)>1`);
    if(conflicts.length) throw new Error('Tentukan satu peran utama sebelum migrasi: '+conflicts.map(r=>`${r.identitas_login} (${r.peran})`).join('; '));
    await query.sequelize.query("INSERT INTO peran(kode,nama) SELECT 'GURU','Guru' WHERE NOT EXISTS(SELECT 1 FROM peran WHERE kode='GURU')");
    const columns = await query.describeTable('guru');
    if (!columns.id_peran_utama) await query.addColumn('guru','id_peran_utama', {
      type: Sequelize.INTEGER.UNSIGNED, allowNull:true,
      references:{model:'peran',key:'id'}, onDelete:'RESTRICT',onUpdate:'RESTRICT'
    });
    // The preflight has established that each account has at most one candidate.
    await query.sequelize.query(`UPDATE guru g SET id_peran_utama=COALESCE(
      (SELECT MIN(p.id) FROM guru_peran gp JOIN peran p ON p.id=gp.id_peran
       WHERE gp.id_guru=g.id AND p.kode IN ('ADMIN','KESISWAAN','KEPALA_SEKOLAH','GURU_BK')
       AND gp.tanggal_mulai<=DATE(CONVERT_TZ(UTC_TIMESTAMP(),'+00:00','+07:00'))
       AND (gp.tanggal_selesai IS NULL OR gp.tanggal_selesai>=DATE(CONVERT_TZ(UTC_TIMESTAMP(),'+00:00','+07:00')))),
      (SELECT id FROM peran WHERE kode='GURU')) WHERE g.id_peran_utama IS NULL`);
    await query.changeColumn('guru','id_peran_utama',{type:Sequelize.INTEGER.UNSIGNED,allowNull:false});
  },
  async down(query) { await query.removeColumn('guru','id_peran_utama'); }
};
