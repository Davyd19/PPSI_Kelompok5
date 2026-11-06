> Pembaruan 5 November 2026: Web Admin menggunakan database/login nyata. Akun Admin contoh lama tidak berlaku. Lihat `docs/development/ADMIN_SETUP.md` pada root repository. Keterangan fondasi/prototipe di bawah merupakan tahap sebelumnya.

# API SIM Kesiswaan

Express + Sequelize/MySQL. `npm ci`, salin `.env.example` ke `.env` bila belum ada, kemudian `npm run dev`. Pengujian: `npm test`. Pemeriksaan koneksi database opsional: `npm run db:check`.

Tidak ada tabel bisnis atau sync otomatis. Demo menggunakan fixture JSON. [Kontrak API](../docs/api/README.md) dan [panduan kerja tim](../docs/development/README.md).
