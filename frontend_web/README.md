# Web React

```powershell
npm ci
Copy-Item .env.example .env
npm run dev
```

Salin contoh konfigurasi hanya jika `.env` belum ada. Atur VITE_API_BASE_URL ke API Express dan jalankan backend serta MySQL. Buka http://localhost:5173, login dengan akun web Admin/Kesiswaan/Kepala Sekolah. Tidak ada pemilih peran.

Pemeriksaan: `npm run lint` dan `npm run build`.

[Instalasi lengkap](../README.md) · [Akun contoh](../docs/development/EXAMPLE_ACCOUNTS.md) · [Desain web](DESIGN.md)
