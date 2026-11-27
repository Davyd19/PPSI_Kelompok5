# Workspace Kesiswaan

Semua endpoint berada di `/api/v1/kesiswaan` dan memerlukan akun utama KESISWAAN aktif melalui web. API Admin tidak berubah.

## Navigasi dan baca data

- `GET /students?q=&kelas=&page=`: direktori nama/NISN, kelas aktif dan pagination 25 baris. Tidak mengirim identitas login, hash atau data akun.
- `GET /students/:id?mulai=&sampai=`: identitas siswa, kelas sekarang, laporan dan presensi berdasarkan kelas pada tanggal kejadian/sesi, pendampingan yang diizinkan, serta prestasi aktif. Periode awal 30 hari.
- `GET /reports/:id`: laporan lengkap, versi aturan historis, kelas saat kejadian dan sekarang, pelapor/pemeriksa, ringkasan penanganan dan riwayat yang diizinkan. Bukti memakai endpoint privat yang sudah ada.
- `GET /proposals/:id`: siswa, pengusul, laporan terkait, ringkasan yang dibagikan, serta respons dan revisi resmi. `isi_internal` tidak dipilih dari database untuk respons tersebut.
- `GET /proposal-queue?mulai=&sampai=&kelas=`: lima usulan menunggu serta jumlah keseluruhannya dalam konteks filter dashboard.
- `GET /categories/:id`: identitas, semua versi, penanda boleh diubah, dan maksimal 25 laporan terkait pada periode.
- `GET /achievements/:id`: peserta, bukti, status, izin edit dan audit perubahan. Prestasi ekskul baca saja.

Detail web memakai URL `/kesiswaan/{students|reports|proposals|categories|achievements}/:id`. Parameter `back` menyimpan halaman asal internal. Filter dan halaman daftar tersimpan di query URL. Klik nama/tombol detail adalah aksi utama; klik dua kali baris adalah pintasan.

## Kategori dan versi

`POST /categories` dari UI mengirim `nama`, `deskripsi?`, `status`, `ketentuan`, `berlaku_mulai`, `berlaku_sampai?`. Kategori dan aturan pertama disimpan dalam satu transaksi. Klien lama yang hanya membuat identitas kategori masih didukung.

`PUT|DELETE /categories/:id/versions/:versionId` hanya untuk versi mendatang yang belum dirujuk laporan. Rentang tidak boleh bertumpuk. Aturan yang sudah berlaku/digunakan terkunci. `POST /categories/:id/versions` menambah versi mendatang; akhir versi terbuka sebelumnya disesuaikan hanya jika tidak mengubah dasar laporan lama. `DELETE /categories/:id` ditolak jika memiliki aturan berlaku/riwayat laporan. Nonaktifkan merupakan tindakan terpisah.

## Bukti laporan

`POST /reports/:id/bukti` menerima body biner PDF/JPEG/PNG, `Content-Type` sesuai berkas dan `X-Filename` yang di-URL-encode; maksimum 5 MB, signature isi divalidasi. Hanya pelapor Kesiswaan dapat menambah bukti pada laporannya yang MENUNGGU. Berkas disimpan privat. Jika unggahan gagal setelah laporan dibuat, UI mengulang unggahan pada ID laporan yang sama.

## Prestasi

- `GET /achievements`: `q`, `mulai`, `sampai`, `kelas`, `siswa`, `status=AKTIF|DIBATALKAN|SEMUA`, `page`; awal 30 hari, status AKTIF. Kelas mengikuti tanggal prestasi.
- `PUT /achievements/:id`: `judul`, `tanggal`, `deskripsi?`, `tingkat_prestasi`, `hasil_prestasi`, `nama_tim?`, `peserta` (1–100 ID siswa berbeda). Nama tim wajib jika beberapa peserta.
- `POST /achievements/:id/cancel`: `alasan_tindakan` wajib. Hanya prestasi non-ekskul aktif dapat dibatalkan. Catatan, peserta dan bukti tetap tersimpan; alasan/pelaku/waktu tercatat di audit transaksi yang sama.
- Unggah bukti pada prestasi ekskul/dibatalkan ditolak. Unduhan historis tetap tersedia bagi Kesiswaan.

Setelah transaksi prestasi berhasil, hitung ulang badge untuk gabungan peserta sebelum/sesudah perubahan. Respons menambahkan `meta.badge_recalculation=complete|pending`. Pending tetap berarti prestasi tersimpan, bukan kegagalan penyimpanan. Proses berkala mengulang pembaruan. Catatan dibatalkan dikeluarkan dari sumber badge dan ringkasan aktif siswa/orang tua/Pembina/Kepala Sekolah.

## Rekap

Pratinjau dan CSV memakai endpoint/filter identik: `GET /attendance[.csv]` atau `/reports[.csv]`, `mulai`, `sampai`, `kelas`, `status`, `q`, `siswa`, serta kategori/versi khusus laporan. Presensi tidak tercatat tetap BELUM_DIISI; tidak dikonversi menjadi Alfa.

## Penerapan lokal

Dari folder backend jalankan `npm run db:migrate`, lalu restart backend dan Vite. Migrasi `20261127000100-portfolio-record-status.js` menambah status AKTIF pada semua portofolio lama. Tidak memerlukan DROP atau seed ulang.

## Hasil pemeriksaan

Pemeriksaan integrasi dilanjutkan pada 27 November 2026. Migrasi database kosong dan database QA berisi data telah diperiksa; data historis tetap tersimpan. Suite workspace mencakup direktori, kategori/versi, bukti laporan, CSV, privasi BK, keputusan bersamaan, koreksi/pembatalan prestasi, batas kewenangan Pembina dan perhitungan badge tertunda.

Browser diperiksa pada 1280 dan 390 px: pencarian/profil, preset siswa, pembatalan formulir, verifikasi, pencatatan/pembatalan prestasi, tab rekap dan drawer. Detail hasil dan batas pemeriksaan ada di [laporan integrasi](../development/VERIFIKASI_INTEGRASI_20261127.md).
