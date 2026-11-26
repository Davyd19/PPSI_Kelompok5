# SIM Kesiswaan — SMAN 12 Padang

React web, Express API, Flutter mobile dan MySQL. Jalankan tiap aplikasi pada terminal terpisah.

## Persiapan

Node.js >=22.12, Flutter sesuai `mobile/pubspec.yaml`, dan MySQL 8.4 (misalnya Laragon). Buat database kosong `db_ppsi` melalui phpMyAdmin.

```powershell
cd backend
npm ci
Copy-Item .env.example .env
node -e "console.log(require('node:crypto').randomBytes(48).toString('hex'))"
```

Salin contoh `.env` hanya jika belum ada. Atur DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD dan isi AUTH_SECRET dengan hasil generator di atas.

```powershell
npm run db:migrate
npm run db:seed:development
npm run dev
```

Untuk database yang sudah berisi data, cukup jalankan migrasi tambahan. Jangan DROP/reset. Seed development hanya untuk data fiktif dan tidak menimpa akun lama. [Daftar akun contoh](docs/development/EXAMPLE_ACCOUNTS.md).

## Web

```powershell
cd frontend_web
npm ci
Copy-Item .env.example .env
npm run dev
```

Buka http://localhost:5173. Web untuk Admin, Kesiswaan dan Kepala Sekolah. Variabel VITE_API_BASE_URL harus mengarah ke backend, bukan server Vite proyek lain.

## Mobile

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

`10.0.2.2` untuk Android emulator. HP fisik memakai IP LAN komputer, iOS simulator memakai localhost. MySQL dan backend harus aktif. Build Android dilakukan oleh pengembang di Android Studio; iOS memerlukan macOS/Xcode.

## Pemeriksaan dan panduan

Backend: `npm test`; koneksi: `npm run db:check`. Web: `npm run lint` dan `npm run build`. Mobile: `flutter analyze` dan `flutter test`. Pengujian integrasi wajib memakai database QA terpisah.

- [Aturan sistem](docs/SYSTEM_RULES.md) dan [panduan AI](AGENTS.md)
- [Kontrak API](docs/api/README.md), [API Admin](docs/api/ADMIN.md)
- [Desain bersama](docs/design/DESIGN.md), [web](frontend_web/DESIGN.md), [mobile](mobile/DESIGN.md)
- [Kerja tim dan masalah umum](docs/development/README.md)

Saat memakai AI lain, minta: **“Baca AGENTS.md, docs/SYSTEM_RULES.md dan panduan desain platform terkait sebelum mengubah kode.”** AGENTS.md tidak otomatis dibaca oleh setiap produk AI.
