# Panduan UI Mobile

Acuan: tampilan Guru terbaru. Berlaku pada login, profil, dashboard, dan seluruh halaman aktif tiap peran. [Identitas bersama](../docs/design/DESIGN.md).

## Tema dan komponen

Gunakan theme.dart untuk warna/typography/ThemeData dan SchoolDesign untuk dimensi. SchoolGreeting adalah kartu sapaan navy dengan nama, tanggal, dan dua informasi ringkas; SchoolSectionTitle memberi aksen garis/ikon kecil; SchoolCard/AppPanel membungkus isi dengan permukaan putih dan garis halus.

| Elemen | Standar |
|---|---|
| Inset halaman | 16 dp |
| Jarak isi | 8/12/16/24 dp |
| Kartu | radius 16 dp, isi 16 dp; kartu sapaan 20 dp |
| Input/tombol | radius 12 dp, target minimum 48 dp |
| Dialog/sheet | radius 20 dp, isi dapat bergulir |
| Judul halaman | 19â€“23 sp |
| Judul bagian | 15â€“16 sp, semibold |
| Isi | 13â€“14 sp, tinggi baris sekitar 1.45 |
| Bantuan | 11â€“12 sp, tetap terbaca saat teks diperbesar |

Tidak memakai gradient dekoratif atau emoji sebagai ikon. Warna semantik memakai palet presensi: hadir hijau, terlambat amber, izin biru, sakit ungu, alfa merah, pengecualian/Belum Diisi abu-abu. Label wajib tetap ditampilkan.

## Navigasi dan konteks peran

- Satu akun langsung masuk ke berandanya. Guru BK mempunyai identitas Guru BK dan fitur dasar Guru. Wali Kelas/Pembina muncul dari tugas aktif.
- Pertahankan nested Navigator milik workspace Guru, halaman profil yang dapat diedit, dan state tab.
- Siswa tetap memakai halaman riwayat, scanner sekolah, notifikasi, prestasi, konseling, ekskul, dan badge yang sudah terhubung.
- Orang Tua tetap memakai konteks anak, seluruh halaman detail, dan pemeriksaan akses hubungan keluarga. Jangan mengganti fitur tersebut dengan placeholder.
- Pembina tetap mengelola kegiatan, pertemuan, anggota, prestasi, serta presensi manual. QR ekskul tidak menjadi menu.
- Fitur BK/Wali yang belum dibangun ditandai belum tersedia; jangan mengarahkan menu penanganan ke laporan Guru yang berbeda makna.

## Form, detail, dan keadaan

Form ringkas dapat berupa dialog. Detail ringkas memakai bottom sheet dengan drag handle; form panjang/bertingkat memakai halaman. Semua konten dapat bergulir saat keyboard terbuka. Isian gagal tidak dibuang dan tombol simpan mencegah permintaan ganda. Koreksi presensi meminta alasan.

Gunakan loading, empty state, LoadErrorView dengan Coba Lagi, serta konfirmasi tindakan berisiko. Scaffold dan dialog mengikuti ThemeData. Tema global tidak boleh menimpa kontras scanner kamera yang memerlukan latar gelap. Grafik/kalender boleh mempertahankan bentuk khususnya.

## Pemeriksaan

Periksa 360 dan 390 dp, skala teks 1.0 dan 1.3, keyboard, back navigation, dialog/sheet, tab aktif, detail, serta status kosong/gagal. Jalankan flutter analyze dan widget test terkait. Android build/runtime dicatat terpisah; build berhasil bukan bukti semua alur telah ditinjau di emulator.

Layar lama tanpa pemanggil aktif dan layar QR ekskul yang tidak lagi dirutekan bukan acuan untuk menambah fitur. Jangan menghapus file fitur teman hanya untuk mengurangi perbedaan visual.
