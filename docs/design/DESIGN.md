# Desain SIM Kesiswaan â€” SMAN 12 Padang

Panduan bersama web dan mobile. Acuan web adalah portal Kesiswaan pada main terbaru; acuan mobile adalah beranda Guru. Struktur informasi boleh berbeda menurut tugas pengguna. Jangan mengganti fitur yang sudah berjalan dengan placeholder demi keseragaman visual.

## Identitas dan token

| Penggunaan | Nilai |
|---|---|
| Navy / judul / aksi utama | `#0E2A47` |
| Latar halaman | `#F4F6F9` |
| Permukaan | `#FFFFFF` |
| Teks sekunder | `#5A6A7C` |
| Garis | `#E3E8F0` |
| Radius kartu | 16 px/dp (kartu sapaan mobile 20 dp) |
| Radius kontrol | 12 px/dp |
| Radius dialog / puncak sheet | 20 px/dp |
| Jarak dasar | 4, 8, 12, 16, 24, 32 |

Satuan CSS px dan Flutter logical pixel mengikuti platform. Ikon menggunakan sistem ikon aplikasi, bukan emoji. Warna aksen membantu membedakan konteks/status; jangan memberikan makna hanya lewat warna. Permukaan solid, tanpa gradien dekoratif. Bayangan ringan hanya untuk permukaan yang perlu dibedakan.

## Prinsip interaksi

- Satu aksi utama per konteks, aksi tambahan lebih tenang. Hapus/nonaktif/reset/pengakhiran membutuhkan konfirmasi yang menyebut data dan akibat tindakan.
- Formulir memiliki label tetap, penanda wajib, validasi dekat isian, indikator penyimpanan, serta isian yang tetap tersedia setelah gagal.
- Loading, kosong, hasil pencarian kosong, dan gagal adalah keadaan berbeda. Kegagalan menyediakan Coba Lagi; jangan tampilkan statistik fiktif.
- Dialog pendek untuk keputusan/formulir ringkas. Formulir bertingkat memakai halaman; sheet untuk detail ringkas/pilihan. Fokus kembali ke pemicu setelah ditutup.
- Status ditulis dengan teks, misalnya Hadir, Ditolak, Belum Diisi; jangan memakai satu warna hijau untuk seluruh status.
- Web mendukung keyboard/fokus terlihat. Mobile mendukung teks diperbesar, keyboard, safe area, dan target sentuh minimum 48 dp.

## Batas produk

Tidak ada poin/sanksi otomatis atau pemberian badge manual. QR hanya untuk presensi sekolah; presensi ekskul dicatat Pembina. Data yang belum dicatat bukan Alfa. Peran utama menentukan portal; Wali Kelas dan Pembina adalah tugas tambahan, bukan pilihan portal setelah login.

## Sumber implementasi

- [Panduan web](../../frontend_web/DESIGN.md)
- [Panduan mobile](../../mobile/DESIGN.md)
- CSS portal Kesiswaan tetap menjadi kerangka; management.css mengatur komponen interaksi Admin/Kesiswaan.
- Flutter theme.dart mengatur tema; design_tokens.dart mengatur ukuran; school_ui.dart menyediakan sapaan/kartu/judul/menu bersama.

Perubahan token atau komponen harus memperbarui panduan platform dan diperiksa pada halaman yang memakai komponen tersebut. Keseragaman tidak berarti semua dashboard memiliki isi dan navigasi yang sama.


## Penerapan mobile terbaru

Workspace keluarga Guru menggunakan empat tab tetap dan menu fitur tambahan berdasarkan penugasan. Detail struktur, komponen bersama, dan aturan responsif ada pada panduan mobile. `Laporan Saya` selalu merupakan laporan milik Guru; bukan pengganti daftar penanganan BK atau kasus kelas binaan.

Perubahan UI tidak mengubah kontrak API, autentikasi, aturan akses, atau struktur database. Komponen kompatibilitas boleh meneruskan ke komponen bersama; jangan mempertahankan dua implementasi visual untuk fungsi yang sama.
