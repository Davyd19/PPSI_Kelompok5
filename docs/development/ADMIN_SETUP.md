# Database dan Manajemen Data Admin

Implementasi ini memakai React, Express, Sequelize 6, dan MySQL 8.4 Laragon. Database bisnis mengikuti ERD revisi: **38 tabel, 258 kolom, 65 FK**. `SequelizeMeta` adalah satu tabel teknis tambahan untuk riwayat migrasi, bukan entitas bisnis.

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
SEED_ADMIN_LOGIN=admin
SEED_ADMIN_PASSWORD=isi_kata_sandi_pribadi_10_sampai_128_karakter
SEED_DEMO_PASSWORD=isi_kata_sandi_data_contoh_10_sampai_128_karakter
CORS_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
```

`root` dan kata sandi kosong hanya contoh konfigurasi lokal Laragon; sesuaikan dengan akun MySQL Anda. Jangan memakai akun root untuk deployment. Variabel `SEED_*` tidak dibaca oleh frontend dan kata sandi tidak masuk audit.

```powershell
npm run db:check
npm run db:migrate
npm run db:seed:required
npm run db:seed:development # opsional; hanya data fiktif development
npm run dev
```

Migration tidak berjalan otomatis saat server menyala dan tidak menggunakan `sync/alter`. Jalankan pada database kosong untuk instalasi pertama. MySQL melakukan implicit commit untuk DDL; bila instalasi pertama terhenti di tengah, jangan menghapus tabel database berisi data untuk mencoba lagi. Periksa error dan gunakan database kosong lain untuk percobaan. `db:migrate:undo` bersifat destruktif dan tidak diperlukan untuk pemakaian normal.

Seed wajib menambahkan empat peran tambahan serta Admin awal. Seed ulang tidak mengubah kata sandi akun yang telah ada. Perubahan `SEED_ADMIN_PASSWORD` setelah seed pertama **tidak mereset akun**. Gunakan menu Akun untuk reset. Seed contoh memakai identitas `contoh.guru`, `contoh.siswa`, dan `contoh.ortu` serta nama kegiatan/riwayat bertanda contoh. Tidak ada berkas lampiran nyata yang diunggah; `seed://` hanya penunjuk fiktif.

## 3. Jalankan web

```powershell
cd C:\Davyd\ProjectPPSI\frontend_web
npm ci
npm run dev
```

Buka alamat Vite. Masuk dengan identitas `SEED_ADMIN_LOGIN` dan kata sandi yang Anda isi sebelum seed pertama. Data Admin kini berasal dari MySQL. Tidak ada akun Admin demo atau kata sandi Admin yang ditanam dalam source.

Login Kesiswaan/Kepala Sekolah prototipe tetap tersedia **hanya pada mode Vite development** menggunakan akun contoh lama. API Admin selalu memeriksa token serta peran Admin database; prototipe tidak mendapat akses CRUD.

## Urutan mengisi data

1. **Data Master:** buat Guru, Siswa, Orang Tua beserta identitas login dan kata sandi awal. NISN 10 digit; nomor telepon/NISN/NIS disimpan sebagai teks.
2. **Akademik:** tahun ajaran → semester → kelas → riwayat kelas siswa. Rentang tanggal akhir inklusif; satu siswa tidak memiliki dua kelas pada rentang sama.
3. **Hubungan Orang Tua–Anak:** satu orang tua boleh memiliki beberapa anak dan satu anak beberapa orang tua/wali.
4. **Peran Guru:** pilih Guru dan salah satu peran tetap. Guru dasar tidak memerlukan baris peran. Peran Wali/Pembina berasal dari penugasan.
5. **Penugasan:** buat identitas ekskul, periode tahunannya, lalu pembina; wali kelas langsung merujuk kelas.
6. **Badge:** identitas badge → versi pada semester mendatang → level dan satu syarat per level. Tidak memberikan badge manual atau menjalankan kalkulator otomatis.

Gunakan **Pindah kelas / Ganti guru** untuk menutup rentang lama sehari sebelum rentang baru dan membuat riwayat pengganti secara atomik. Gunakan **Akhiri** untuk pengakhiran tanpa pengganti. Jangan menimpa identitas relasi yang sudah berlaku. Data yang dirujuk tidak dapat dihapus permanen. Data master dinonaktifkan melalui **Ubah**; penghapusan dan perubahan status membutuhkan konfirmasi.

Untuk mengganti aturan badge yang telah berlaku, akhiri cakupan versi lama pada semester yang sah, lalu buat versi selanjutnya pada semester mendatang. Level versi yang sudah berlaku tidak bisa diubah. Perhitungan pencapaian/progres menjadi pekerjaan modul badge berikutnya.

## Sesi dan batas tahap

Token akses bertanda tangan HMAC berlaku 15 menit, hanya di memori browser, tanpa refresh token. Refresh tab meminta login lagi. Keluar membersihkan token dari browser; pencabutan satu token secara individual belum tersedia. Reset kata sandi atau nonaktifkan akun membatalkan akses token sebelumnya pada pemeriksaan berikutnya. Peran dicek pada setiap permintaan. Pembatas percobaan login berada di memori satu proses backend; untuk deployment multi-instance perlu limiter bersama.

API login mengenali ketiga jenis akun, tetapi UI nyata tahap ini hanya web Admin. Mobile serta transaksi modul anggota lain tidak diubah. Tabel transaksi tersedia dan memiliki contoh pengembangan; masing-masing pemilik modul tetap harus menerapkan aturan bisnisnya, termasuk kapasitas, masa keanggotaan, pemilik catatan BK, dan cakupan versi badge.

## Kerja tim dan pengujian

Davyd: identitas/akun/peran, akademik, penugasan, konfigurasi badge, fondasi audit. Ikhwan: siswa/orang tua. Nala: presensi sekolah. Raihanah: pendampingan/BK/wali kelas. Vannesa: ekskul/Kepala Sekolah. Koordinasikan perubahan tabel bersama sebelum menambah migration. Model dan asosiasi seluruh tabel diekspor dari `backend/src/models/index.js`; katalog nama/kolom berada pada `schema.json`. Controller tetap menangani proses, tanpa lapisan service/repository tambahan.

```powershell
# Backend: pengujian tanpa DB
npm test
# Integrasi: hanya database terpisah dengan nama berakhiran _qa,
# telah dimigrasi, diberi seed wajib/development dan env SEED_* yang sesuai.
npm run test:integration
# Web
npm run lint
npm run build
```

Jangan mengarahkan tes integrasi ke database pengembangan bersama atau database sekolah. Tes membuat/mengubah data fiktif dan hanya menerima nama database `*_qa`.

Jika `AUTH_NOT_CONFIGURED`, isi `AUTH_SECRET` lalu restart backend. Jika database belum tersedia, periksa Laragon, port, kredensial dan hasil `db:check`. Jika login Admin ditolak setelah setup, pastikan seed wajib sudah dijalankan pada database `.env` yang sama. Error tidak membocorkan password/koneksi. Bila data tersimpan tetapi belum tampak, periksa filter/pencarian dan gunakan Muat ulang.

Skema migration pertama memakai snapshot JSON tersendiri di folder migrations. Jangan mengedit migration atau snapshot yang telah dijalankan anggota tim; buat migration baru untuk setiap perubahan database berikutnya. `src/models/schema.json` mewakili model aplikasi saat ini.
