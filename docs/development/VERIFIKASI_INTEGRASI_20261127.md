# Verifikasi integrasi main — 27 November 2026

## Versi dan cakupan

Dasar pemeriksaan: `071d3ca`, merge PR #141 (Admin/Kesiswaan), yang sudah mencakup PR #140 dari `bk&wali-kelas`. Working tree bersih ketika pemeriksaan dimulai. Tidak membuat branch, commit, push, atau mengubah database utama.

Commit teman terbaru `2661f1f` berjudul perubahan fungsi kalendar hanya mengubah `mobile/pubspec.lock`; tidak mengubah kode kalender, backend, atau skema database. Versi dependensi pada lockfile tersebut memerlukan Dart >=3.13, sedangkan SDK terpasang adalah Dart 3.11.5. Menjalankan Flutter pub get melalui SDK terpasang berhasil menghasilkan lockfile kompatibel. Fitur kalender yang sudah ada tetap dipertahankan; widget test pemilih tanggal rencana konseling ikut lolos.

## Hasil

| Pemeriksaan | Hasil |
|---|---|
| Unit backend | 46 tes lulus |
| Integrasi lintas modul lama dan workspace Admin | 47 tes lulus |
| Workspace Kesiswaan tambahan | 9 tes lulus |
| Integrasi batas waktu QR | 2 tes lulus di database khusus QR |
| Unit web | 2 tes lulus |
| ESLint dan build Vite | Lulus |
| Analisis Dart | No issues found |
| Flutter test | 211 tes lulus; tidak build APK |
| Migrasi dari database kosong | Seluruh 10 migrasi lulus |
| Migrasi database berisi data | Seluruh baris lama tetap sama; portofolio lama berstatus AKTIF |
| Seed ulang | Snapshot seluruh baris identik; akun/hash/status lama dipertahankan |

Suite gabungan pertama yang sudah diperbaiki mencakup 55 tes (47 regresi + 8 workspace). Suite workspace kemudian ditambah satu skenario worker badge sibuk dan dijalankan ulang: 9/9 lulus. Dua tes QR dijalankan pada database tersendiri sesuai pengaman suite, bukan dengan menonaktifkan pengamannya.

Database QA: `sim_admin_integrated_20261127_qa`, `sim_admin_regression_20261127_qa`, `sim_ks_upgrade_20261127_qa`, dan `sim_qr_window_20261127_integrated_qa`. Tidak ada DROP atau reset database utama.

## Skenario Kesiswaan

- Direktori siswa, filter nama/NISN/kelas, ID/halaman tidak valid, serta pembatasan Admin/Guru/anonim.
- Kategori dan aturan awal atomik, validasi gagal tanpa data parsial, versi berlaku terkunci, versi mendatang boleh diedit/dihapus tanpa bertumpuk, kategori historis tidak boleh dihapus.
- Laporan mengikuti versi historis, membedakan kelas kejadian/sekarang, mencatat tempat, dan dapat diverifikasi oleh pelapor Kesiswaan yang sama.
- Bukti PDF berizin, signature salah ditolak, ukuran lebih dari 5 MB ditolak, akses Guru ditolak, dan penambahan setelah verifikasi ditolak.
- Profil dan CSV mengikuti siswa/periode; tidak ada catatan presensi tetap BELUM_DIISI.
- Isi internal BK tidak muncul pada profil, daftar atau detail usulan. Setujui/Tolak/Minta Revisi masing-masing diuji dengan dua keputusan bersamaan: satu berhasil dan satu ditolak, status penanganan tetap terbuka.
- Prestasi dibuat untuk siswa A, dikoreksi ke siswa B, kemudian dibatalkan. Badge A dicabut, badge B diberikan kemudian dicabut, peserta/lampiran/audit tetap ada, dan pencapaian tidak ganda saat penghitungan ulang.
- Prestasi ekskul baca saja bagi Kesiswaan; Pembina yang ditugaskan tetap dapat mengunggah bukti melalui pengunggah bersama.
- Filter kelas, tanggal, status batal, pencarian dan metadata pagination prestasi.
- Saat lock worker badge sibuk, prestasi tetap tersimpan dengan meta pending. Setelah lock dilepas, penghitungan ulang menghasilkan badge tanpa mengulang penyimpanan prestasi.

## Browser

Pratinjau khusus memakai API QA port 3101 dan Vite port 5174, bukan server/database utama. Pemeriksaan memakai akun contoh Kesiswaan.

Pada 1280 dan 390 px: dashboard, direktori, pencarian, profil, tab, detail laporan, formulir preset siswa, pembatalan formulir dengan perubahan yang dipertahankan, konfirmasi verifikasi dan kembali ke tab asal, pencatatan/pembatalan prestasi serta audit, jenis rekap, detail kategori, dan navigasi drawer. Tidak ada pelebaran dokumen pada halaman sempit yang diperiksa; tabel tetap memiliki area gulir sendiri.

## Perbaikan lokal dari pemeriksaan

- Lockfile Flutter diselesaikan ulang untuk SDK lokal stabil.
- Fixture tes versi aturan memakai tanggal mendatang berbasis hari WIB, bukan tanggal November yang sudah berlalu.
- Tab profil di desktop dipaksa menjadi flex mendatar agar tidak diwarisi layout grid navigasi sidebar.
- Kontainer notifikasi kosong tidak lagi menghasilkan ruang kosong di atas detail.
- Perubahan tab memakai navigasi React Router agar kembali dari detail mempertahankan tab asal.
- Tombol Unduh CSV hanya muncul pada dashboard/laporan/rekap yang memiliki endpoint ekspor; bukan direktori siswa atau daftar prestasi.
- Suite workspace ditambahkan sebagai `npm run test:kesiswaan-workspace`; tetap wajib memakai database QA.

## Batas pemeriksaan

Tidak ada build APK atau pengujian runtime Android/iOS pada sesi ini. Flutter widget test tidak membuktikan koneksi, kamera, atau perilaku perangkat fisik. Pemeriksaan browser terfokus pada alur di atas, bukan UAT seluruh menu semua aktor. Gangguan jaringan saat unggahan dan percobaan ulang melalui dialog belum disimulasikan di browser; batas tipe/ukuran/akses file sudah diuji melalui HTTP.

Sebelum menjalankan aplikasi lokal setelah pull, jalankan `npm run db:migrate` dari backend lalu restart backend dan web. Tidak perlu DROP atau seed ulang. Perubahan hasil pemeriksaan belum di-commit/push.
