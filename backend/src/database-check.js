const database = require('./config/database');
(async () => {
  try { await database.authenticate(); console.log('Koneksi MySQL berhasil. Tidak ada tabel yang diubah.'); }
  catch { console.error('Koneksi MySQL gagal. Periksa layanan, host, port, nama database, dan kredensial pada .env.'); process.exitCode = 1; }
  finally { await database.close(); }
})();
