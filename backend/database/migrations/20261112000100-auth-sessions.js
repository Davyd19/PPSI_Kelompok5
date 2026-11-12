module.exports = {
  async up(q, S) {
    await q.createTable('sesi_autentikasi', {
      id: { type: S.STRING(36), primaryKey: true },
      jenis_akun: { type: S.STRING(20), allowNull: false },
      id_akun: { type: S.INTEGER.UNSIGNED, allowNull: false },
      platform: { type: S.STRING(10), allowNull: false },
      sidik_sandi: { type: S.STRING(64), allowNull: false },
      kedaluwarsa: { type: S.DATE(3), allowNull: false },
      dicabut: S.DATE(3)
    });
    await q.addIndex('sesi_autentikasi', ['jenis_akun', 'id_akun']);
    await q.addIndex('sesi_autentikasi', ['kedaluwarsa']);
    await q.createTable('token_refresh', {
      hash: { type: S.CHAR(64), primaryKey: true },
      id_sesi: { type: S.STRING(36), allowNull: false, references: { model: 'sesi_autentikasi', key: 'id' }, onDelete: 'CASCADE' },
      dipakai: S.DATE(3)
    });
  },
  async down(q) {
    await q.dropTable('token_refresh');
    await q.dropTable('sesi_autentikasi');
  }
};
