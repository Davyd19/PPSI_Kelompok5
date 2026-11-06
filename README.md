# SIM Kesiswaan â€” SMAN 12 Padang

Web Admin kini menggunakan login nyata dan database MySQL melalui Sequelize. Modul mobile serta dashboard Kesiswaan/Kepala Sekolah masih prototipe. Mulai dari [panduan database dan Admin](docs/development/ADMIN_SETUP.md) sebelum menjalankan web Admin.

## Mulai cepat

Prasyarat: Node.js 22.12 atau lebih baru (CI: 22), npm, Flutter stable dengan Dart >=3.11.5 (CI: Flutter 3.41.9), serta MySQL bila ingin menguji koneksi database.

Jalankan setiap aplikasi dalam terminal terpisah dari folder repository:

```powershell
cd backend
npm ci
Copy-Item .env.example .env
npm run dev
```

```powershell
cd frontend_web
npm ci
Copy-Item .env.example .env
npm run dev
```

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

Salin `.env.example` hanya saat `.env` belum ada. Jangan menimpa konfigurasi lokal teman. Web: http://localhost:5173. API: http://localhost:3000/api/v1/health.

Alamat `10.0.2.2` khusus Android emulator. Perangkat fisik memakai IP LAN komputer; iOS simulator memakai `localhost`. Lihat [panduan pengembangan](docs/development/README.md).

## Folder

| Folder | Tanggung jawab |
|---|---|
| backend | Route â†’ controller â†’ model, API dan koneksi Sequelize |
| frontend_web | Admin, Kesiswaan, Kepala Sekolah |
| mobile | Siswa, Orang Tua, Guru, Wali Kelas, Guru BK, Pembina Ekstrakurikuler |
| docs | Arsitektur, kontrak API, dan aturan kerja tim |

## Pemeriksaan

Backend: `npm test` di folder backend. Web: `npm run lint` dan `npm run build` di frontend_web. Mobile: `flutter analyze` dan `flutter test` di mobile.

Koneksi MySQL hanya diperiksa lewat `npm run db:check` di backend. API demo tidak memerlukan MySQL dan health mengembalikan `database: not_checked`. Tidak ada tabel bisnis, seed database, atau sinkronisasi otomatis.

## Batas tahap

Belum ada autentikasi nyata, hak akses backend nyata, database bisnis, kamera/QR nyata, unggahan, atau deployment. Endpoint demo dinonaktifkan saat NODE_ENV=production. Sesi demo hanya di memori dan hilang saat keluar/reload. Data simulasi tidak menunjukkan keadaan sekolah sebenarnya.

[Arsitektur](docs/architecture/README.md) Â· [Kontrak API](docs/api/README.md) Â· [Kerja tim dan troubleshooting](docs/development/README.md)

## Akun contoh UI

Web: `admin`, `kesiswaan`, `kepsek`. Mobile: `siswa`, `ortu`, `guru`, `wali`, `bk`, `pembina`. Kata sandi seluruhnya `Contoh123!`. Lihat [panduan akun contoh](docs/development/EXAMPLE_ACCOUNTS.md).
