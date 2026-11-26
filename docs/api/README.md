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

[API Admin](ADMIN.md) · [API BK/Wali](../development/BK_WALI.md) · [QR sekolah](SCHOOL_ATTENDANCE.md) · [Aturan sistem](../SYSTEM_RULES.md)
