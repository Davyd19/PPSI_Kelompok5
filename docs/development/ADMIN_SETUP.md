# Database dan Manajemen Data Admin

Implementasi ini memakai React, Express, Sequelize 6, dan MySQL 8.4 Laragon. Database bisnis mengikuti ERD revisi: **38 tabel bisnis**. Migrasi lanjutan menambah tabel sesi, token refresh, dan status aktif pencapaian badge.

## 1. Buat database kosong

Nyalakan MySQL di Laragon. Pada phpMyAdmin pilih **New / Baru**, lalu buat database `sim_kesiswaan_dev` dengan collation `utf8mb4_unicode_ci`. Jangan mengimpor ERD XML ke phpMyAdmin; XML digunakan Enterprise Architect.

Tidak ada SQL dump alternatif. Struktur dibuat melalui migration agar semua anggota tim menerima skema yang sama. Jangan mengubah tabel bersama langsung di phpMyAdmin tanpa menuliskannya sebagai migration baru.

## 2. Konfigurasi backend

Di terminal PowerShell:

```powershell
cd C:\Davyd\ProjectPPSI\backend
npm ci
Copy-Item .env.example .env # hanya bila .env belum ada
node -e "console.log(require('node:crypto').randomBytes(48).toString('hex'))"
```

Salin hasil acak perintah terakhir ke `AUTH_SECRET` pada `.env`. Jangan membagikannya atau memasukkannya ke Git. Isi:

```dotenv
NODE_ENV=development
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=sim_kesiswaan_dev
DB_USER=root
DB_PASSWORD=
AUTH_SECRET=isi_dengan_hasil_acak_minimal_32_karakter
CORS_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
```

`root` dan kata sandi kosong hanya contoh konfigurasi lokal Laragon; sesuaikan dengan akun MySQL Anda. Jangan memakai akun root untuk deployment.

```powershell
npm run db:check
npm run db:migrate
npm run db:seed:required
npm run db:seed:development # opsional; hanya data fiktif development
npm run dev
```

Migration tidak berjalan otomatis saat server menyala dan tidak menggunakan `sync/alter`. Jalankan pada database kosong untuk instalasi pertama. MySQL melakukan implicit commit untuk DDL; bila instalasi pertama terhenti di tengah, jangan menghapus tabel database berisi data untuk mencoba lagi. Periksa error dan gunakan database kosong lain untuk percobaan. `db:migrate:undo` bersifat destruktif dan tidak diperlukan untuk pemakaian normal.

Seed wajib menambahkan empat peran tambahan dan akun contoh.admin. Seed pengembangan menjalankan fondasi tersebut serta membuat akun dan data skenario fiktif. Seed ulang mempertahankan kata sandi dan status akun lama. Lihat [akun pengembangan](EXAMPLE_ACCOUNTS.md).

## 3. Jalankan web

```powershell
cd C:\Davyd\ProjectPPSI\frontend_web
npm ci
npm run dev
```

Buka alamat Vite dan masuk dengan akun Admin database. Untuk pengembangan, gunakan akun contoh.admin. Akun contoh.guru dapat memilih Kesiswaan.

## Urutan mengisi data

1. **Data Master:** buat Guru, Siswa, Orang Tua beserta identitas login dan kata sandi awal. NISN 10 digit; nomor telepon/NISN/NIS disimpan sebagai teks.
2. **Akademik:** tahun ajaran → semester → kelas → riwayat kelas siswa. Rentang tanggal akhir inklusif; satu siswa tidak memiliki dua kelas pada rentang sama.
3. **Hubungan Orang Tua–Anak:** satu orang tua boleh memiliki beberapa anak dan satu anak beberapa orang tua/wali.
4. **Peran Guru:** pilih Guru dan salah satu peran tetap. Guru dasar tidak memerlukan baris peran. Peran Wali/Pembina berasal dari penugasan.
5. **Penugasan:** buat identitas ekskul, periode tahunannya, lalu pembina; wali kelas langsung merujuk kelas.
6. **Badge:** identitas badge → versi pada semester mendatang → level dan satu syarat per level. Pencapaian dihitung dari presensi oleh backend.

Gunakan **Pindah kelas / Ganti guru** untuk menutup rentang lama sehari sebelum rentang baru dan membuat riwayat pengganti secara atomik. Gunakan **Akhiri** untuk pengakhiran tanpa pengganti. Jangan menimpa identitas relasi yang sudah berlaku. Data yang dirujuk tidak dapat dihapus permanen. Data master dinonaktifkan melalui **Ubah**; penghapusan dan perubahan status membutuhkan konfirmasi.

Untuk mengganti aturan badge yang telah berlaku, akhiri cakupan versi lama pada semester yang sah, lalu buat versi selanjutnya pada semester mendatang. Level versi yang sudah berlaku tidak bisa diubah. Jalankan perintah npm run badge:recalculate di backend untuk menghitung ulang data lama. Server menghitung ulang setiap lima menit.

## Sesi dan batas tahap

Token akses berlaku 15 menit. Browser menyimpan sesi dalam memori dan meminta login ulang ketika halaman dimuat ulang. Flutter menyimpan token refresh dalam penyimpanan aman dengan masa sesi maksimal 30 hari. Keluar mencabut sesi perangkat. Reset kata sandi dan penonaktifan mencabut semua sesi akun.

Portal Kesiswaan menggunakan data MySQL. Halaman Kepala Sekolah dan fitur mobile milik modul lain menampilkan kerangka sesuai peran. Bukti prestasi disimpan pada backend/storage/prestasi atau lokasi privat yang diatur dengan PRESTASI_UPLOAD_DIR.

## Kerja tim dan pengujian

Davyd: identitas/akun/peran, akademik, penugasan, konfigurasi badge, fondasi audit. Ikhwan: siswa/orang tua. Nala: presensi sekolah. Raihanah: pendampingan/BK/wali kelas. Vannesa: ekskul/Kepala Sekolah. Koordinasikan perubahan tabel bersama sebelum menambah migration. Model dan asosiasi seluruh tabel diekspor dari `backend/src/models/index.js`; katalog nama/kolom berada pada `schema.json`. Controller tetap menangani proses, tanpa lapisan service/repository tambahan.

```powershell
# Backend: pengujian tanpa DB
npm test
# Integrasi: hanya database terpisah dengan nama berakhiran _qa,
# telah dimigrasi dan diberi seed development.
npm run test:integration
# Web
npm run lint
npm run build
```

Jangan mengarahkan tes integrasi ke database pengembangan bersama atau database sekolah. Tes membuat/mengubah data fiktif dan hanya menerima nama database `*_qa`.

Jika `AUTH_NOT_CONFIGURED`, isi `AUTH_SECRET` lalu restart backend. Jika database belum tersedia, periksa Laragon, port, kredensial dan hasil `db:check`. Jika login Admin ditolak setelah setup, pastikan seed wajib sudah dijalankan pada database `.env` yang sama. Error tidak membocorkan password/koneksi. Bila data tersimpan tetapi belum tampak, periksa filter/pencarian dan gunakan Muat ulang.

Skema migration pertama memakai snapshot JSON tersendiri di folder migrations. Jangan mengedit migration atau snapshot yang telah dijalankan anggota tim; buat migration baru untuk setiap perubahan database berikutnya. `src/models/schema.json` mewakili model aplikasi saat ini.
