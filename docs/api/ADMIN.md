# API Admin v1

Base `/api/v1`. Kontrak data sukses `{data}`, daftar `{data,meta:{page,limit,total,totalPages}}`, gagal `{error:{code,message,details?}}`. Kata sandi/hash/token tidak pernah menjadi kolom data daftar/detail. Waktu kejadian API menggunakan ISO 8601 UTC; tanggal lokal `YYYY-MM-DD`.

## Autentikasi

- `POST /auth/login`: `{identitas_akun,kata_sandi}` → `{data:{access_token,expires_in:900,user}}`. User memuat `id,kind,name,identitas_login,roles,role,roleLabel`. Jenis akun `guru/siswa/orang_tua`. Token opaque bertanda tangan HMAC, bukan kontrak JWT untuk didekode klien.
- `GET /auth/me`: `Authorization: Bearer <access_token>` → user terkini. Semua `/admin` membutuhkan header ini dan peran `ADMIN` aktif.
- `401`: tidak memiliki sesi/sesi tidak sah; `403`: akun sah tetapi tidak berwenang; `409`: benturan data atau riwayat dilindungi; `422`: isian tidak valid; `429`: pembatas percobaan login; `503`: DB/konfigurasi belum tersedia.

## Resource manajemen

`guru`, `siswa`, `orang_tua`, `guru_peran`, `hubungan`, `tahun`, `semester`, `kelas`, `riwayat_kelas`, `wali`, `badge`, `versi_badge`, `level`, `ekskul`, `periode_ekskul`, `pembina`.

- `GET /admin/metadata`: label, kolom editable, tipe input, pilihan status, FK dan optionality. Bukan endpoint generik seluruh tabel bisnis. `peran` hanya baca.
- `GET /admin/summary`: hitungan master dan tahun ajaran aktif dari DB.
- `GET /admin/:resource?page=1&limit=10&q=...`: daftar, filter exact melalui nama kolom FK/status yang didukung metadata. Limit 1–100. Pencarian teks terhadap kolom identitas/nama; bukan ekspresi SQL.
- `GET /admin/:resource/:id`: detail publik.
- `POST /admin/:resource`: isi kolom yang tercantum pada metadata. Akun baru wajib `kata_sandi` (10–128 karakter); `hash_kata_sandi` ditolak sebagai input.
- `PATCH /admin/:resource/:id`: hanya kolom yang diubah; hash dan PK tidak editable. Perubahan relasi yang sudah berlaku harus melalui pengakhiran/pergantian.
- `DELETE /admin/:resource/:id`: hanya data belum dirujuk/belum berlaku. Tidak otomatis menonaktifkan jika ditolak.
- `GET /admin/lookups/:resource?page=1&limit=20&q=...`: `{data:[{id,label,...}],meta}`. Periode/versi memiliki label konteks.
- `GET /admin/accounts?page=1&limit=10&q=...&kind=guru`: daftar gabungan akun tiga jenis, tanpa kredensial.
- `POST /admin/accounts/:kind/:id/reset-password`: `{kata_sandi}`. Mencatat tindakan audit tanpa nilai kata sandi/hash.
- `POST /admin/riwayat_kelas/:id/replace`: `{id_kelas,tanggal_mulai}` untuk pindah kelas atomik.
- `POST /admin/wali/:id/replace` dan `/admin/pembina/:id/replace`: `{id_guru,tanggal_mulai}` untuk pergantian guru atomik.

Semua penulisan Admin memakai transaksi dengan penguncian baris Peran ADMIN sebagai titik koordinasi lintas proses. Pembuatan akun oleh modul lain nantinya wajib memakai pola koordinasi yang sama agar login lintas tabel tetap unik. Last Admin diperiksa sebelum commit. FK menggunakan RESTRICT; tidak ada penghapusan riwayat otomatis.

Aturan lintas tabel yang tidak dapat direpresentasikan hanya dengan FK tetap menjadi tanggung jawab controller modul pemiliknya. Belum ada endpoint pencatatan operasional presensi, BK, pendaftaran, unggah lampiran, atau pemberian badge otomatis dalam tahap Admin ini.

## Pengelolaan terintegrasi

Seluruh route berikut tetap dibatasi Admin web dan memakai format respons `data` / `error` yang sama.

| Route | Fungsi |
|---|---|
| GET `/admin/overview?id_tahun_ajaran=...` | KPI, persebaran siswa, akun, penugasan, kelengkapan dan aktivitas |
| GET `/admin/badge-options` | Katalog kode ikon, sumber, metode dan satuan badge |
| GET `/admin/:resource/:id/workspace` | Identitas dan relasi untuk siswa, guru, orang_tua, kelas, ekskul, periode_ekskul, badge, versi_badge |
| POST `/admin/workflows/student` | Membuat siswa, kelas opsional dan orang tua/hubungan opsional dalam satu transaksi |
| POST `/admin/workflows/parent-link` | Memilih akun orang tua lama atau membuat akun baru sekaligus hubungan |
| POST `/admin/workflows/badge` | Membuat badge beserta versi/level atau versi berikutnya pada badge yang sudah ada |

Detail kelas menerima `at=YYYY-MM-DD` untuk anggota/penugasan yang berlaku pada tanggal tersebut. Hilangkan parameter untuk riwayat lengkap. Pagination relasi memakai `group=<resource>&page=N`, 20 data per halaman.

Workflow siswa menerima `siswa` (atribut master dan kata_sandi), `kelas` opsional (`id_kelas`, `tanggal_mulai`), dan `orang_tua` opsional. Objek orang_tua memiliki tepat satu dari `id_orang_tua` atau `data` akun baru, beserta `jenis_hubungan` dan `tanggal_mulai`.

Workflow parent-link menerima `id_siswa` dan objek `orang_tua` yang sama. Pembuatan gagal tidak meninggalkan akun/hubungan setengah jadi. Identitas login tetap unik lintas jenis akun.

Workflow badge menerima `badge` untuk identitas baru atau `id_badge` yang ada, `versi` dan array `levels` (1–20). Urutan level ditentukan posisi array. Versi berikutnya harus mulai semester mendatang; rentang versi sebelumnya ditutup pada semester sebelum versi baru dalam transaksi yang sama. Versi yang sudah berlaku tidak diubah cara hitungnya.

Sumber: PRESENSI_SEKOLAH, PRESENSI_EKSKUL, PRESTASI, KEGIATAN, KEANGGOTAAN_EKSKUL, PELANGGARAN. Metode harus sesuai katalog. `id_ekstrakurikuler` opsional berlaku bagi sumber ekskul/portofolio/keanggotaan; status kehadiran hanya untuk sumber presensi. Persentase memakai cakupan SEMESTER dan target 1–100. Pelanggaran memakai HARI_TANPA_PELANGGARAN dengan target hari penuh.

Pencapaian tetap otomatis. Endpoint koleksi siswa dan orang tua menggunakan perhitungan bersama, termasuk ikon, progres sementara dan periode bukti. Tidak ada endpoint pemberian badge manual.

Jalankan `npm run db:migrate` untuk migrasi tambahan `20261126000200-integrated-admin-badges.js`. Tidak perlu DROP atau seed ulang. Uji workflow pada database QA: `npm run test:admin-workspace`.
