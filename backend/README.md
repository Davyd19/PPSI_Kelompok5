# Backend Express

Dari folder ini:

```powershell
npm ci
Copy-Item .env.example .env
```

Jangan menimpa `.env` yang sudah ada. Buat database kosong sesuai DB_NAME melalui phpMyAdmin, isi koneksi MySQL dan AUTH_SECRET minimal 32 karakter. Generator: `node -e "console.log(require('node:crypto').randomBytes(48).toString('hex'))"`.

```powershell
npm run db:migrate
npm run db:seed:development
npm run dev
```

Seed wajib saja: `npm run db:seed:required`. Akun contoh hanya untuk development/test; seed ulang tidak mengganti sandi/status akun lama. [Akun contoh](../docs/development/EXAMPLE_ACCOUNTS.md).

API: http://localhost:3000/api/v1. `npm run db:check` memeriksa MySQL; `/health` hanya kesehatan aplikasi. Migrasi tidak berjalan otomatis saat server mulai. Database lama cukup dimigrasi tanpa DROP.

Pemeriksaan: `npm test`. Integrasi: set DB_NAME ke database terpisah berakhiran `_qa`, migrasi, seed, lalu `npm run test:integration`. Jangan arahkan uji integrasi ke database utama. Perhitungan ulang badge: `npm run badge:recalculate`.

[Aturan sistem](../docs/SYSTEM_RULES.md) · [Kontrak API](../docs/api/README.md)
