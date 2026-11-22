# API SIM Kesiswaan

Express + Sequelize/MySQL. Panduan lengkap: [ADMIN_SETUP.md](../docs/development/ADMIN_SETUP.md) · [akun contoh](../docs/development/EXAMPLE_ACCOUNTS.md) · [kontrak API](../docs/api/README.md).

## Menjalankan pertama kali

Dari folder `backend`, dengan MySQL (Laragon/XAMPP) sudah menyala dan database kosong `db_ppsi` sudah dibuat:

```bash
npm ci
cp .env.example .env          # PowerShell: Copy-Item .env.example .env
node -e "console.log(require('node:crypto').randomBytes(48).toString('hex'))"
```

Tempel hasil perintah terakhir ke `AUTH_SECRET` di `.env`, sesuaikan `DB_USER`/`DB_PASSWORD`, lalu:

```bash
npm run db:migrate
npm run db:seed:development   # sudah termasuk seed wajib; berisi akun dan data fiktif
npm run dev                   # API di http://localhost:3000/api/v1
```

Sudah pernah setup sebelumnya? Cukup jalankan `npm run db:migrate` dan `npm run db:seed:development` lagi setelah pull. Seed tidak menimpa akun atau kata sandi yang sudah ada.

## Akun contoh (kata sandi `Contoh123!`)

| Akun | Masuk ke |
|---|---|
| `contoh.admin` | Web Admin |
| `contoh.guru` | Web Kesiswaan (otomatis untuk semua guru) dan aplikasi mobile guru |
| `contoh.kepsek` | Web Kepala Sekolah |
| `contoh.siswa`, `contoh.ortu` | Aplikasi mobile |

## Aplikasi mobile di emulator

Backend harus berjalan (`npm run dev`, `HOST=0.0.0.0`). Dari folder `mobile`:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

`10.0.2.2` adalah alamat komputer dari dalam emulator Android. Untuk HP fisik, ganti dengan IP LAN komputer.

## Pengujian

- `npm test`: unit test, tanpa database.
- `npm run test:integration`: butuh database terpisah yang namanya berakhiran `_qa` (misalnya `db_ppsi_qa`), masih kosong, sudah di-migrate dan diberi `db:seed:development`. Jalankan dengan `DB_NAME=db_ppsi_qa` dan `AUTH_SECRET` terisi. Tes membuat data tetap, jadi buat ulang database QA sebelum menjalankannya lagi.

Migration tidak berjalan otomatis saat server menyala dan tidak memakai `sync/alter`.
