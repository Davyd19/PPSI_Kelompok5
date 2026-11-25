# Integrasi main terbaru dan cadangan lokal

Dasar: main f6c7789. Cadangan tidak di-pop dan tidak dihapus. Tidak membuat branch/commit/push.

## Diambil dari cadangan

Komponen ManagementUi, useConfirm, util formulir, peningkatan interaksi Admin/Kesiswaan, serta komponen mobile school_ui. Admin diadaptasi kembali ke PortalShell Kesiswaan; CSS portal lama tidak ditimpa.

## Tidak dikembalikan

Controller Guru monolitik, controller/halaman Siswa gabungan, ParentHome placeholder, pengaturan database lokal, migrasi yang mewajibkan tabel Guru kosong, dan konfigurasi Android lama. Halaman serta controller terpisah milik teman tetap menjadi dasar.

## Perubahan proses yang disetujui

- Satu peran utama; Guru BK memperoleh fitur dasar Guru, Wali/Pembina mengikuti penugasan.
- Guru biasa tidak memperoleh portal Kesiswaan otomatis.
- Presensi ekskul manual, tidak mengisi Alfa otomatis saat sesi ditutup; endpoint QR ekskul tidak lagi dirutekan.
- Scanner sekolah menggunakan validator QR Guru yang sama melalui adapter respons halaman Siswa.
- Endpoint bukti laporan memakai model/storage lampiran_laporan yang sudah ada dan pemeriksaan izin Kesiswaan web secara eksplisit.

## Menjalankan pada database lokal

Jangan DROP database. Hentikan backend lama, lalu dari backend jalankan:

```powershell
npm run db:migrate
npm run db:seed:required
npm run db:seed:development
npm run dev
```

Migrasi baru memetakan satu peran aktif khusus menjadi peran utama; tanpa peran khusus menjadi Guru. Konflik beberapa peran khusus menghentikan migrasi sebelum perubahan skema dan menampilkan identitas akun untuk ditentukan. Riwayat guru_peran tetap tersimpan tetapi bukan sumber izin baru. Peran utama diubah melalui Data Master/Peran Guru pada Admin. Penugasan hanya untuk akun Guru/Guru BK.

Seed ulang mempertahankan akun yang sudah ada. Akun contoh.guru lama yang sudah berperan BK tetap BK setelah migrasi; Admin dapat mengubahnya secara eksplisit jika ingin menjadi Guru biasa. Seed tidak diam-diam menurunkan peran akun lama.

Akun baru: contoh.admin, contoh.kesiswaan, contoh.kepsek, contoh.guru, contoh.bk, contoh.siswa, contoh.ortu. Kata sandi hanya untuk akun contoh yang baru dibuat: Contoh123!. Akun lama mempertahankan kata sandinya. contoh.guru menerima tugas Wali Kelas/Pembina pada data contoh; akun BK terpisah.

Kolom QR ekskul dan catatan presensi lama tetap dipertahankan. Alfa otomatis yang sudah ada tidak dikoreksi massal. Migrasi baru harus dijalankan sebelum menjalankan backend dengan model baru.

## Kontrak API yang berubah

Profil login dan /auth/me menambahkan primary_role dan duties. roles/available_roles tetap tersedia sebagai atribut kompatibilitas berisi kemampuan pada platform tersebut, bukan daftar portal untuk dipilih. Guru BK menyertakan GURU sebagai kemampuan dasar. Guru wajib mempunyai id_peran_utama pada formulir Admin. Perubahan peran utama mencabut sesi akun.

Riwayat guru_peran lama tetap disimpan tetapi tidak dapat diubah melalui endpoint Admin generik. Gunakan atribut peran utama Guru untuk izin portal; Wali Kelas/Pembina tetap dikelola melalui penugasan.

Endpoint QR ekskul tidak lagi dirutekan. Rekap Pembina menambahkan total_sesi dan belum_diisi per anggota, berdasarkan pertemuan tertutup dalam masa keanggotaan yang berlaku. Kolom historis tetap dipertahankan.

Scanner sekolah Siswa menerima QR Guru melalui adapter respons halaman lama. Validasi sesi, tanggal, masa token, keanggotaan siswa, dan duplikasi menggunakan handler Guru yang sama. Hash QR dibaca hanya secara internal dan tidak dikirim ke klien.

GET /api/v1/kesiswaan/reports/:id/bukti dan GET /api/v1/kesiswaan/bukti/:id memakai tabel/storage lampiran_laporan milik implementasi Guru. Handler dan router memeriksa izin Kesiswaan web; tidak membuat tabel bukti duplikat.

## Pemeriksaan selesai

- 34 tes unit/route backend lulus.
- 34 tes integrasi MySQL lulus pada database QA baru, termasuk halaman asli Siswa/Orang Tua, profil Guru, QR sekolah, pencabutan sesi saat ganti peran, serta akses bukti.
- Migrasi database kosong lulus. Migrasi berisi data lama mempertahankan akun, hash sandi, dan riwayat penugasan; konflik peran terdeteksi sebelum perubahan skema.
- Seed ulang mempertahankan jumlah data, hash sandi, status akun, dan peran utama yang sudah ada.
- Lint/build web lulus. Dua tes web lama untuk akun simulasi juga lulus; keduanya bukan pengujian autentikasi produksi.
- Portal Admin/Kesiswaan ditinjau di browser pada 1280 dan 390 px, termasuk formulir, dialog, dan drawer. Konflik CSS sidebar pada layar sempit sudah diperbaiki.
- Flutter analyze dan 16 widget test lulus; meliputi 360/390 dp, teks diperbesar, profil/navigasi Guru, halaman Orang Tua, sesi/logout, dan formulir Pembina yang gagal lalu dicoba lagi.
- Build APK sebelumnya gagal karena ruang drive C habis saat Gradle mengekstrak dependensi. Hanya artefak perantara build gagal dibersihkan. Build mobile selanjutnya diserahkan kepada pengguna; APK/runtime terbaru belum diverifikasi. Tidak mengubah versi toolchain Android dari main.

Database QA terpisah yang dibuat: sim_integrasi_20261125a_qa, sim_integrasi_20261125b_qa, sim_integrasi_20261125c_qa, sim_integrasi_20261125d_qa. Database aplikasi lokal, .env, serta seluruh stash dipertahankan. Tidak ada commit/push atau branch baru.

Pratinjau widget untuk pemeriksaan visual berada di D:/Kuliah/Semester 7/PPSI/output/verifikasi-integrasi-20261125/mobile. Pratinjau memakai fixture pengujian dan font sistem untuk rendering, bukan hasil runtime Android.

## Perbaikan kompatibilitas db_ppsi lama

Diagnosis baca-saja menunjukkan error ER_NO_SUCH_TABLE untuk lampiran_laporan_pelanggaran, sedangkan database lama memakai bukti_laporan. Peran utama dan akun Kesiswaan sudah benar. Migrasi 20261122000100 sekarang mengenali kolom tempat_kejadian yang sudah ada, mempertahankan bukti melalui rename tabel, serta menjaga kolom ukuran lama tanpa mewajibkannya untuk unggahan baru. Dua tabel bukti yang sama-sama berisi data ditolak untuk rekonsiliasi, bukan digabung/dihapus secara diam-diam. Rollback otomatis migrasi bukti dinonaktifkan untuk menjaga data lama.

Pengujian pada sim_legacy_evidence_20261125_qa meniru riwayat migrasi lama (termasuk primary-role dan teacher-reports); migrasi, seed, query dashboard, ID/metadata/ukuran bukti lama, hash sandi lama, unggahan dengan struktur baru, serta pengulangan migrasi lulus. Database aplikasi db_ppsi belum dimigrasikan oleh agen; jalankan command migrasi dan seed sesuai panduan. Seeder kini juga membuat contoh.wali dan contoh.pembina sebagai Guru dengan tugas aktif masing-masing.
