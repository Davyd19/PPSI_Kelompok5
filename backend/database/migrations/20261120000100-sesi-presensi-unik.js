// Satu sesi presensi sekolah per tanggal per jenis (PAGI/ZUHUR): QR hanya bisa
// dibuat sekali sehari per sesi, oleh guru yang pertama membukanya.
module.exports = {
  async up(q) {
    await q.addIndex('sesi_presensi_sekolah', ['tanggal', 'jenis_sesi'], {
      unique: true,
      name: 'uq_sesi_tanggal_jenis'
    });
  },
  async down(q) {
    await q.removeIndex('sesi_presensi_sekolah', 'uq_sesi_tanggal_jenis');
  }
};
