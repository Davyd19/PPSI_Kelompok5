# Kontrak API v1 — demo

Base URL lokal: `http://localhost:3000/api/v1`. Semua endpoint GET; tidak menerima kredensial. Demo hanya tersedia ketika NODE_ENV bukan production.

| Endpoint | Hasil |
|---|---|
| `/health` | `{data:{status:"ok",database:"not_checked",simulation:true}}` |
| `/demo/profiles` | `{data:[{id,role,roleLabel,name,platform,classroom}]}` |
| `/demo/dashboard?role=siswa` | `{data:{simulation,profile,period,dateLabel,student,attendanceSummary,agendas,badge,notifications,stats,menus}}` |

`role`: admin, kesiswaan, kepala_sekolah, siswa, orang_tua, guru, wali_kelas, guru_bk, pembina_ekstrakurikuler. `platform`: web atau mobile. Role hilang, tidak dikenal, atau berulang menghasilkan 400 INVALID_ROLE.

Dashboard: `stats` array `{label,value}`; `menus` array string; `student` berisi name/nisn/classroom; `attendanceSummary` berisi percentage, description, note, attended, total, breakdown; `agendas` berisi title/time/place/description; `badge` berisi name/description/detail; `notifications` berisi title/body. Nilai periode/tanggal merupakan snapshot demo Oktober 2026, bukan tanggal hari ini.

Keberhasilan menggunakan `{data: ...}`. Error menggunakan `{error:{code,message,details?}}`. Error: INVALID_ROLE (400), INVALID_JSON (400), PAYLOAD_TOO_LARGE (413), ORIGIN_NOT_ALLOWED (403), NOT_FOUND (404), INTERNAL_ERROR (500). Detail internal, stack trace, dan kredensial tidak dikirim ke klien.

CORS hanya mengizinkan origin yang tercantum pada CORS_ORIGINS. Native mobile biasanya tidak mengirim Origin. CORS bukan pengganti autentikasi. Klien memakai timeout 8 detik dan tombol Coba Lagi tanpa fallback diam-diam ke data lokal.

## Grafik referensi UI

Dashboard menerima query opsional `period=2026-10|2026-09` dan `grade=all|x|xi|xii`. Filter tidak valid menghasilkan 400 INVALID_PERIOD/INVALID_GRADE. Payload menambahkan academicPeriod, analytics, parent, teacher, counseling, coach, periodOptions, selectedPeriod, selectedGrade, trend, trendLabels, incidentSeries, reportsInPeriod. Filter periode/tingkat mengubah dataset grafik; ringkasan berjudul Hari Ini dan tabel tetap snapshot 22 Oktober. Kontrak data lama dipertahankan. Login lokal tidak mengirim identitas/password ke endpoint ini.
