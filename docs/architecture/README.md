# Arsitektur dan keputusan fondasi

React (web) dan Flutter (mobile) → HTTP JSON → Express → model Sequelize → MySQL.

Demo memakai `backend/src/models/demo.fixture.json`, bukan database. Identitas, agenda, notifikasi, badge, dan ringkasan dibaca klien melalui API. Perubahan presensi siswa hanya simulasi lokal dan direset saat keluar; ringkasan periode historis tetap merupakan snapshot demo.

## Backend

- `routes`: endpoint dan middleware.
- `controllers`: input/output serta aturan bisnis, termasuk pemeriksaan kewenangan terhadap data saat autentikasi dibangun.
- `models`: definisi Sequelize dan akses database; `demo.model.js` secara eksplisit memakai fixture.
- `validators`: validasi input; `middleware`: pengolahan request/error; `config`: konfigurasi.
- `database/migrations` dan `seeders`: lokasi perubahan schema/data ketika ERD disepakati. Tidak memakai `sync`, `alter`, atau `force` saat startup.

Tidak ada service/repository pada tahap ini. Gunakan SQL berparameter atau API Sequelize; jangan menyusun query dengan interpolasi input.

## Klien

React menggunakan pages/components dan router terpusat. Flutter menggunakan screens/widgets serta satu klien API. Komponen spesifik halaman tetap dekat halaman; komponen yang benar-benar digunakan ulang dipindahkan ke components/widgets.

Web: Admin, Kesiswaan, Kepala Sekolah. Mobile: enam peran lain. Pemilihan profil demo dan penjagaan route UI bukan otorisasi backend. Login nyata nantinya harus menentukan identitas dari server, bukan mempercayai parameter role.

## Tampilan dan aturan bisnis

Tema navy, biru, latar terang, kartu membulat; ikon generik tanpa mengarang logo resmi. Nama SIM Kesiswaan. Referensi gambar hanya panduan tampilan. Tidak ada poin, leaderboard, RFID, sanksi otomatis, QR ekskul, atau pemberian badge manual. Presensi ekskul manual oleh pembina. Catatan internal BK tidak dimasukkan ke payload demo.

## Database

Sequelize 6 + MySQL2. Database masih dapat direvisi. `npm run db:check` hanya authenticate (SELECT), bukan membuat database/tabel. Migrasi kosong belum perlu dijalankan; Sequelize CLI akan membuat metadata migrasi jika migrasi kelak dijalankan. Konfigurasi CLI mengikuti NODE_ENV dan .env backend: pastikan sasaran database benar sebelum perintah migrasi/undo.

Override UUID 11.1.1+ di dependency Sequelize menghindari advisory UUID lama, tetap mendukung CommonJS. Pengujian memeriksa default UUID Sequelize tanpa menyimpan data. Tinjau kembali override saat memperbarui Sequelize.
