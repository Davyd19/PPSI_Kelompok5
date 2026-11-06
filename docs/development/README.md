> Pembaruan 5 November 2026: Web Admin menggunakan database/login nyata. Akun Admin contoh lama tidak berlaku. Lihat `docs/development/ADMIN_SETUP.md` pada root repository. Keterangan fondasi/prototipe di bawah merupakan tahap sebelumnya.

# Pengembangan dan kerja tim

## Alur harian

1. Ambil perubahan terbaru dari main; buat branch `feature/nama-fitur` atau `fix/nama-masalah`.
2. Kerjakan modul dengan nama file konsisten: backend `attendance.controller.js`, React `AttendancePage.jsx`, Dart `attendance_screen.dart`.
3. Jalankan pemeriksaan bagian yang diubah dan periksa UI terkait.
4. Buat pull request ke main, jelaskan perubahan, cara menguji, dan batasnya; minta anggota lain meninjau.
5. Koordinasikan perubahan router utama, app, konfigurasi, tema, kontrak API, dan migrasi sebelum mengubahnya.

Repository Git lokal sudah diinisialisasi pada branch main, tanpa commit atau remote. Untuk GitHub yang sudah memiliki riwayat, gunakan clone repository tersebut sebagai basis dan salin perubahan fondasi ke dalamnya; jangan force-push riwayat baru. Tidak ada commit/push atau perubahan GitHub yang dilakukan otomatis.

## Pemilik pekerjaan

| Pemilik | Area |
|---|---|
| Davyd | Fondasi, Admin/master data, Kesiswaan, badge otomatis |
| Ikhwan | Siswa, Orang Tua, integrasi mobile terkait |
| Nala | Guru dan presensi sekolah |
| Raihanah | Guru BK dan Wali Kelas |
| Vannesa | Ekstrakurikuler dan Kepala Sekolah |

Pembagian ini berlaku lintas platform: misalnya Vannesa mengerjakan mobile Pembina dan web Kepala Sekolah. ERD tetap dikoordinasikan Davyd/Ikhwan. Pemilik modul berkoordinasi bila memerlukan perubahan tabel bersama.

## Menjalankan dan mengonfigurasi

- Gunakan `npm ci` setelah clone, `npm install` hanya untuk perubahan dependency yang disengaja; commit package-lock.json dan pubspec.lock.
- Backend: `.env` di backend; web: `.env` di frontend_web. VITE_* masuk ke bundle publik, jangan isi rahasia. Restart dev server setelah perubahan env.
- Backend berjalan di 0.0.0.0:3000 agar perangkat lokal dapat terhubung. CORS default hanya localhost/127.0.0.1:5173. Untuk web di host lain tambahkan origin secara eksplisit.
- Database: isi DB_HOST/PORT/NAME/USER/PASSWORD menggunakan database pengembangan yang disiapkan tim; jalankan `npm run db:check`. Jangan memakai database sekolah/production untuk percobaan.
- Tidak ada sync otomatis. Setelah ERD disepakati, buat migration melalui Sequelize CLI, review, lalu jalankan `npm run db:migrate`. Undo adalah tindakan perubahan database dan hanya dilakukan secara sengaja.

## Alamat API Flutter

```powershell
# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
# Perangkat fisik: ganti dengan IP LAN komputer sendiri
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/v1
# iOS simulator, pada macOS
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

Perangkat dan komputer harus satu jaringan; izinkan port backend melalui firewall lokal jika diperlukan. Tidak perlu mematikan seluruh firewall. Pastikan `/api/v1/health` dapat dibuka dari perangkat. Konfigurasi alamat API bukan rahasia.

Android mengizinkan HTTP hanya pada manifest debug. iOS Debug memakai Info-Debug.plist dengan izin jaringan lokal; Release/Profile memakai Info.plist tanpa pengecualian ATS. Untuk iOS gunakan localhost/nama host lokal yang didukung ATS; validasi macOS/Xcode diperlukan, gunakan HTTPS bila alamat pengembangan ditolak. Rilis nantinya harus memakai HTTPS.

## Pemeriksaan sebelum pull request

```powershell
cd backend
npm test
cd ../frontend_web
npm run lint
npm run build
cd ../mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

CI menjalankan pemeriksaan yang sama. Testing fondasi tidak menggantikan black-box Use Case Testing dan pengujian nonfungsional pada tahap pengujian proyek.

## Troubleshooting

- API gagal dihubungi: cek proses backend, port, API_BASE_URL/VITE_API_BASE_URL, jaringan, dan firewall. Data tidak diganti otomatis menjadi demo offline.
- CORS ditolak: cek origin browser termasuk port; jangan menggunakan wildcard untuk menghindari konfigurasi.
- Port terpakai: hentikan hanya proses milik sendiri atau pilih port lain, lalu sesuaikan URL klien.
- MySQL gagal: cek layanan dan konfigurasi `.env`; demo tetap berjalan, health tidak menyatakan database sehat.
- Demo tidak ditemukan: pastikan NODE_ENV=development; production sengaja tidak menyediakan profil demo.
- Setelah refresh web, profil perlu dipilih lagi karena sesi hanya di memori. Logout mobile mereset simulasi presensi siswa.
- Hosting SPA kelak perlu fallback ke index.html untuk URL React; deployment belum bagian tahap ini.
