# Verifikasi Manajemen Data Admin — 5 November 2026

- Migrasi dijalankan pada database kosong terpisah menggunakan MySQL **8.4.3**, port QA 3308. Hasil: 38 tabel bisnis, 258 kolom bisnis, 65 FK; ditambah tabel teknis SequelizeMeta. Database proyek pengguna tidak dibuat, direset, atau diubah.
- Seed wajib dan seed contoh dijalankan dua kali. Seluruh 38 tabel memiliki contoh fiktif; identitas dan data manual tidak ditimpa. Data ini bukan data sekolah nyata.
- **16 pengujian integrasi lulus**, meliputi struktur/FK, login dan profil nyata, penolakan non-Admin, token kedaluwarsa/diubah, CRUD/pencarian/pagination, login unik lintas jenis akun dan race paralel, perlindungan Admin terakhir, riwayat dan FK yang menolak penghapusan, validasi, versi badge immutable, reset kata sandi yang mencabut token, seluruh resource/lookup, perpindahan kelas dengan rollback, konsistensi periode akademik, pergantian guru, serta aktivasi tahun ajaran yang diaudit.
- **7 pengujian fondasi backend lulus**. Web: ESLint dan build Vite lulus. Pengujian backend yang membutuhkan koneksi localhost dilakukan di lingkungan dengan izin jaringan lokal; pembatasan sandbox awal bukan kegagalan aplikasi.
- Browser: login Admin nyata, ringkasan database, tabel Data Master, formulir siswa, validasi kosong, pembatalan, navigasi akademik, dan keluar melalui panel profil ditinjau. Tampilan desktop ditinjau melalui screenshot. Pada viewport CSS 390 piksel, lebar dokumen tetap 390; judul tidak memiliki ruang kosong berlebih dan tabel memiliki gulir sendiri. Penangkapan screenshot pada viewport kecil mengalami timeout, sehingga pemeriksaan kecil juga memakai ukuran DOM/aksesibilitas.
- UI mempertahankan sidebar navy, latar terang, kartu, tombol dan komponen yang ada. Tidak memakai grafik simulasi pada dashboard Admin nyata.
- Workflow CI MySQL disertakan tetapi belum dijalankan pada GitHub. Mobile tidak diubah atau diuji ulang.

## Batas

Pemberian badge otomatis, transaksi presensi, pengajuan/penanganan BK, pendaftaran ekskul, unggah berkas, serta halaman operasional anggota tim belum diimplementasikan pada tahap Admin. Model/FK dan seed tersedia sebagai fondasi. Seed lampiran memakai penunjuk fiktif, bukan unggahan berkas nyata.

Sesi masih token 15 menit dalam memori tanpa refresh dan tanpa pencabutan sesi individual; logout lokal, reset sandi/nonaktif akun diperiksa backend. Limiter login masih per proses. Implementasi deployment dan data nyata memerlukan konfigurasi HTTPS, akun DB terbatas, serta peninjauan lintas modul. Setup database lokal pengguna mengikuti ADMIN_SETUP.md.
