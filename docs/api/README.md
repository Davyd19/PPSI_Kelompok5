# Kontrak API

Base URL: `/api/v1`. Keberhasilan memakai `data`; kegagalan memakai `error.code` dan `error.message`. Route terlindungi memerlukan `Authorization: Bearer <access_token>`. Pemeriksaan hak dilakukan di backend.

| Area | Route utama | Pengguna |
|---|---|---|
| Autentikasi | POST /auth/login, POST /auth/refresh, POST /auth/logout, GET /auth/me | Akun sesuai platform |
| Admin | /admin/... | Admin web |
| Kesiswaan | /kesiswaan/... | Kesiswaan web |
| Kepala Sekolah | /kepala-sekolah/... | Kepala Sekolah web |
| Guru | /guru/... | Guru/Guru BK mobile |
| Pendampingan | /guru-bk/... dan /wali-kelas/... | BK/Wali sesuai kewenangan |
| Pembina | /pembina/... | Penugasan Pembina aktif |
| Siswa/Orang Tua | /student/..., /parent/... | Akun dan hubungan yang sah |
| Kesehatan | GET /health | Status aplikasi; bukan pemeriksaan MySQL |

Nama route rinci mengikuti berkas `backend/src/routes`. Jangan menganggap semua operasi tersedia hanya dari namespace ini. Endpoint demo hanya untuk pengembangan dan bukan sumber data operasional.

[API Admin](ADMIN.md) · [Workspace Kesiswaan](KESISWAAN_WORKSPACE.md) · [API BK/Wali](../development/BK_WALI.md) · [QR sekolah](SCHOOL_ATTENDANCE.md) · [Aturan sistem](../SYSTEM_RULES.md)

### Perpanjangan sesi web

`POST /api/v1/auth/keep-alive` memakai Bearer token sesi web yang masih berlaku. Respons `data.access_token` dan `data.expires_in` (1800 detik). Endpoint menolak sesi mobile (403) dan sesi kedaluwarsa/dicabut (401); tidak menerbitkan refresh token untuk web. Panggil hanya jika ada interaksi pengguna. Aktivitas web memperbarui sesi maksimal sekali per menit; setelah 30 menit diam web keluar. Token mobile tetap 900 detik.
