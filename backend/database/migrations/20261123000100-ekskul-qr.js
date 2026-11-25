// Presensi ekskul mandiri: pembina menampilkan QR berputar, siswa anggota memindainya.
// Hanya hash token yang disimpan; token asli hanya ada di QR yang sedang tampil.
module.exports = {
  async up(q, S) {
    await q.addColumn('pertemuan_ekstrakurikuler', 'hash_token_qr', { type: S.STRING(64), allowNull: true });
    await q.addColumn('pertemuan_ekstrakurikuler', 'token_kedaluwarsa', { type: S.DATE(3), allowNull: true });
  },
  async down(q) {
    await q.removeColumn('pertemuan_ekstrakurikuler', 'token_kedaluwarsa');
    await q.removeColumn('pertemuan_ekstrakurikuler', 'hash_token_qr');
  }
};
