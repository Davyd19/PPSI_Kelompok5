# Verifikasi fondasi — 29 Oktober 2026

## Hasil

- Backend: 6 pengujian lulus, mencakup health tanpa klaim koneksi DB, 9 profil/dashboard, role tidak valid/hilang/berulang, error JSON/404/CORS, kegagalan koneksi DB yang tidak membocorkan password, serta konfigurasi MySQL dan default UUID Sequelize.
- Web: ESLint dan build Vite lulus. Runtime browser memverifikasi tiga profil web, keluar/reload mereset sesi, respons menu Belum tersedia, desktop dan viewport sempit tanpa overflow halaman, backend tidak tersedia, dan pemulihan Coba Lagi.
- Flutter: 12 widget test lulus. Cakupan: validasi NISN/password lokal, tampil/sembunyi password, 6 profil mobile, keluar, presensi ganda/reset, agenda/badge otomatis/notifikasi, API gagal/profil kosong, dashboard gagal lalu pulih, serta layar 320x700 dengan teks 1,5x dan keyboard pada login.
- Android: debug APK berhasil dibangun dan dipasang pada emulator Medium_Phone_API_36.0 (Android 16). Login demo dan beranda siswa berhasil memuat API melalui 10.0.2.2; tampilan ditinjau langsung.
- Dependency npm backend dan web: tidak ada vulnerability yang dilaporkan saat pemeriksaan dependency lokal. Lockfile disertakan.
- .env, node_modules, dist, build, dan .dart_tool terabaikan oleh Git.

## Batas pemeriksaan

- Koneksi MySQL yang berhasil belum diuji menggunakan kredensial proyek nyata. Pemeriksaan gagal dan konfigurasi Sequelize sudah diuji; tidak ada database/tabel yang dibuat atau diubah.
- Runtime iOS belum diuji karena memerlukan macOS/Xcode. Debug memakai plist jaringan lokal terpisah dari Release/Profile.
- Workflow CI dibuat sebagai file lokal, belum dijalankan di GitHub. Tidak ada remote, commit, atau push.
- Pemeriksaan ini bukan pengujian keamanan/kinerja lengkap atau UAT. Autentikasi dan data bisnis belum tersedia.

## Referensi tampilan

Gaya visual dikembangkan dari referensi UI pengguna, dengan aturan bisnis terbaru. Presensi ekskul tetap manual; badge otomatis tanpa verifikasi manual; tidak ada poin/RFID/leaderboard.
