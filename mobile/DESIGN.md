# Panduan UI Mobile SIM Kesiswaan

Acuan visual adalah tampilan Guru. Panduan berlaku pada login, profil, beranda, daftar, detail, formulir, dialog, dan sheet seluruh peran aktif. Identitas bersama: **SIM Kesiswaan — SMAN 12 Padang**. Lihat juga [panduan bersama](../docs/design/DESIGN.md).

## Token dan komponen

`theme.dart` menjadi sumber warna, tipografi, dan tema kontrol. `SchoolDesign` menjadi sumber dimensi dan keluarga font. Halaman tidak mendefinisikan ulang token navy, teks sekunder, latar, atau garis.

| Elemen | Standar |
|---|---|
| Navy / permukaan / latar | #0E2A47 / #FFFFFF / #F4F6F9 |
| Teks sekunder / garis | #5A6A7C / #E3E8F0 |
| Font | Roboto, mengikuti pembesaran teks perangkat |
| Inset halaman / isi kartu | 16 dp |
| Jarak | 8, 12, 16, 24 dp |
| Kartu | Radius 16 dp; sapaan 20 dp |
| Input / tombol / pemilih tanggal | Radius 12 dp, target sentuh minimal 48 dp |
| Dialog / puncak sheet | Radius 20 dp |
| Judul halaman / bagian | 19–23 sp / 15–16 sp |
| Isi / bantuan | 13–14 sp / 11–12 sp |

Gunakan `SchoolCard`, `SchoolSectionTitle`, `SchoolGreeting`, `SchoolContextHeader`, dan `SchoolPageTitle` dari `widgets/school_ui.dart`. `AppPanel`, `SectionCard`, dan `HeroHeader` merupakan pembungkus kompatibilitas komponen tersebut; jangan membuat implementasi permukaan baru di dalamnya.

Gunakan `SchoolStatus` untuk label status; `AttendanceStatusBadge` dan `ColorPill` meneruskan label, warna semantik, dan ikon ke komponen yang sama. Label harus terbaca tanpa mengandalkan warna. Status di atas header navy diberi permukaan terang.

Menu pintas Siswa juga memakai `SchoolMenuGrid`, sedangkan kartu Orang Tua memakai `SchoolCard`. Gunakan `showSchoolSuccess` untuk dialog sukses bersama; penutupan formulir tetap dikendalikan pemanggil.

Gunakan tema input/tombol bersama, `SchoolDialog`, `SchoolEmpty`, `SchoolLoading`, dan `LoadErrorView`. Dialog singkat aplikasi yang membutuhkan animasi tetap memakai `showAppDialog` dengan permukaan dan ukuran yang sama. Tidak memakai gradien dekoratif atau emoji. Radius ikon, avatar, chip, kalender, dan grafik boleh mengikuti kebutuhan bentuknya.

## Workspace dan fitur Guru bersama

Satu akun langsung masuk ke satu workspace; tidak ada pemilih peran. Guru BK menggunakan fitur dasar Guru, sedangkan Wali Kelas dan Pembina merupakan penugasan tambahan.

- `app/account_capabilities.dart` memetakan profil autentikasi ke kemampuan tampilan dan enum `TeacherFeature`. Backend tetap memeriksa izin pada setiap permintaan.
- `screens/teacher/teacher_workspace.dart` mengelola empat tab tetap: **Beranda, Presensi, Laporan Saya, Profil**. Masing-masing tab mempertahankan stack navigasi dan state.
- `TeacherHome` memuat data dan mengoordinasikan refresh. `teacher_home_sections.dart` menyediakan menu dasar, sesi hari ini, rekap mingguan, serta menu kemampuan tambahan.
- Guru, BK, Wali, dan Pembina memakai implementasi halaman presensi, input manual, rekap, laporan pelanggaran, Laporan Saya, dan profil yang sama. Jangan menyalin halaman ke folder peran lain.
- Menu Penanganan Siswa dan Rencana Konseling muncul untuk BK; Kelas Binaan untuk Wali; Ekskul Binaan untuk Pembina. Fitur tambahan dibuka dari Beranda. Tidak menambah tab Ekskul atau mengganti Laporan Saya dengan kasus BK.
- Menu fitur mengirim enum/callback, bukan string label untuk menentukan rute. Mengubah teks tombol tidak boleh mengubah tujuan navigasi.

## Halaman khusus tiap aktor

Keseragaman berlaku pada gaya dan perilaku komponen, bukan menyamakan isi halaman.

Siswa mempertahankan presensi sekolah, riwayat, notifikasi, prestasi, konseling, ekskul, dan badge. Orang Tua mempertahankan konteks anak dan detail yang diizinkan. Pembina mempertahankan pertemuan, anggota, pendaftaran, prestasi, dan presensi manual. BK/Wali mempertahankan pemisahan akses serta catatan konseling privat.

Formulir khusus tetap berada dekat fiturnya. Komponen input, tanggal, judul, kartu, dan tombol digunakan bersama; jangan menyatukan formulir yang mempunyai aturan bisnis berbeda hanya untuk mengurangi jumlah file.

## Responsif dan keadaan

Formulir panjang memakai halaman dan dapat digulir saat keyboard terbuka. Pilihan/status/metadata menggunakan Wrap atau teks fleksibel jika tidak cukup untuk satu baris. Jangan mengecilkan atau membatasi pembesaran teks untuk menghilangkan overflow.

Loading, data kosong, hasil filter kosong, dan gagal merupakan keadaan berbeda. Kegagalan menyediakan Coba Lagi. Pada beranda Guru, sesi dan rekap dimuat secara independen: kegagalan satu bagian tidak menghilangkan bagian yang berhasil dan tidak ditampilkan sebagai angka nol.

Isian gagal tetap tersedia, tombol simpan menolak pengiriman ganda, dan tindakan berisiko meminta konfirmasi. Latar gelap scanner serta kontrol kamera dipertahankan; jangan dipaksa mengikuti warna kartu putih.

## Verifikasi

Jalankan `flutter analyze` dan `flutter test --no-pub`. Uji empat tab yang sama pada kombinasi Guru/BK dengan/tanpa Wali/Pembina, state tiap tab, navigasi kembali, profil, dan logout.

`mobile_ui_consistency_test.dart` memeriksa 37 halaman pada 360/390 dp dan skala teks 1.0/1.3, keyboard, bagian bawah halaman, serta dialog panjang. Fixture Siswa/Orang Tua berasal dari akun fiktif database QA; bukan data pengguna nyata atau kredensial. Font pengujian dimuat dari SDK Flutter agar tidak bergantung Windows atau font Ahem.

Untuk menyimpan gambar tinjauan, isi variabel lingkungan `PPSI_UI_CAPTURE_DIR` sebelum menjalankan widget test. Build APK dan pemeriksaan Android fisik/emulator dilakukan terpisah oleh pemilik proyek; widget test tidak membuktikan kamera atau seluruh alur perangkat bekerja.
