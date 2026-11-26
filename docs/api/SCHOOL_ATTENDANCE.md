# Presensi sekolah dan jadwal QR

Semua waktu dalam request adalah ISO 8601 dengan zona waktu (`+07:00` atau `Z`). UI menampilkan WIB. Server menentukan waktu scan yang sah.

- `POST /guru/presensi/sesi`: `jenis_sesi` PAGI/ZUHUR, `qr_aktif_mulai`, `qr_aktif_sampai`.
- `POST /guru/presensi/sesi/:id/qr/berlaku`: kedua waktu di atas, pada tanggal sesi hari ini; boleh mengatur QR terjadwal, aktif, atau kedaluwarsa jika sesi belum ditutup. Token tidak berubah.
- `GET /guru/presensi/sesi/:id/qr`: `kode`, `berlaku_mulai`, `berlaku_sampai`, `waktu_server`, `status` TERJADWAL/AKTIF/BERAKHIR dan `aktif`.
- `POST /guru/presensi/sesi/:id/qr/tutup`: menghentikan QR yang sedang aktif. Sesi tetap AKTIF untuk input manual. QR terjadwal dapat diubah jadwalnya; penutupan sesi juga membatalkan scan.
- `POST /guru/presensi/sesi/:id/tutup`: menutup sesi secara eksplisit; tidak dapat dibuka kembali.
- `POST /student/attendance/scan`: `qr_code` dari Guru. Server menerima tepat jika `mulai <= sekarang < tutup`, sesi terbuka, siswa berhak dan belum tercatat. Hasil HADIR.

Pembuatan dan pengubahan QR hanya bagi Guru/Guru BK melalui mobile; bukan Admin/Kesiswaan/Kepala Sekolah. Tanggal dan jenis sesi tidak dapat diubah melalui edit jadwal. Perubahan tercatat di audit dan tidak mengubah catatan presensi sebelumnya.

Kompatibilitas: klien lama yang hanya mengirim `berlaku_menit` (5/10/15/30/60, default 15) dipetakan ke mulai sekarang hingga durasi atau akhir hari WIB. Jangan mencampurnya dengan satu field waktu eksplisit saja. `batas_tepat_waktu` adalah data legacy, tidak menghasilkan keterlambatan.

Manual/koreksi: HADIR, IZIN, SAKIT, ALFA, PENGECUALIAN_SAH (Zuhur). TERLAMBAT lama tetap ada pada rekap dan filter, tetapi ditolak untuk penulisan baru. Belum Diisi bukan Alfa otomatis. Presensi ekskul tetap manual melalui route Pembina, tanpa QR.

Migrasi `20261126000100-school-qr-window.js` menambah `qr_aktif_mulai`, mengisi data lama dari `waktu_buka` ketika QR ada, dan mempertahankan presensi serta batas legacy. Jalankan `npm run db:migrate`; tidak perlu DROP.
