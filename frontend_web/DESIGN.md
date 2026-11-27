# Panduan UI Web

Acuan: portal Kesiswaan pada main terbaru. Berlaku untuk Admin dan Kesiswaan; halaman Kepala Sekolah mempertahankan susunannya. [Identitas bersama](../docs/design/DESIGN.md).

## Kerangka

Gunakan PortalShell: sidebar terang dengan identitas navy, header sekolah/profil, lalu judul/deskripsi halaman, aksi utama, indikator, filter, dan panel data. Admin memakai kerangka yang sama. Panel utama tidak mempunyai lebar tetap yang memotong layar.

- Judul halaman 24–30 px; judul panel 16–18 px; isi 14 px; teks bantuan minimum 12 px.
- Kartu radius 16 px; kontrol 12 px; jarak antarpanel 16–24 px. Hindari kartu berlapis untuk setiap label.
- Desktop memakai sidebar; <=860 px memakai drawer. Pada <=600 px filter/form turun satu kolom. Hanya tabel/grafik yang boleh bergulir horizontal.
- Footer dan panel profil tidak memuat klaim keamanan/koneksi yang tidak didukung.

## Data dan tindakan

ManagementUi menyediakan status, menu aksi baris, modal, notifikasi, skeleton, dan empty state. Gunakan useConfirm untuk konfirmasi; jangan gunakan window.confirm/alert/prompt. Susun tombol aksi utama dengan label; aksi baris tersedia melalui menu berlabel yang dapat diakses keyboard.

Tabel memiliki kepala biru muda, pemisah halus, kolom aksi konsisten, pencarian/filter, dan pagination. Status berbeda dibedakan label serta warna semantik. Penolakan/error merah; menunggu amber; aktif/berhasil hijau; informasi biru; Belum Diisi abu-abu.

Form panjang menggunakan halaman penuh; form pendek modal dengan judul, isi, dan footer Batal/Simpan. Tampilkan pesan server dan kesalahan kolom tanpa membuang isian. Tutup form yang berubah meminta konfirmasi. Tombol penyimpanan dinonaktifkan selama permintaan berjalan.

Bukti laporan diunduh melalui API Kesiswaan berizin, bukan URL berkas publik. CSV menggunakan filter yang sama dengan tabel. Tidak menampilkan berhasil sebelum respons penyimpanan diterima.

## Pemeriksaan

Tinjau lebar 1280 dan 390 px: sidebar/drawer, kartu, filter, tabel, menu aksi, modal, formulir panjang, fokus keyboard, keadaan gagal/kosong. Jalankan npm run lint dan npm run build setelah perubahan komponen. Jangan mengembalikan seluruh CSS lama dari stash karena dapat mengubah portal lain.

## Admin: halaman berpusat pada data utama

Dashboard menampilkan KPI, persebaran siswa, akun/penugasan, kelengkapan data dan aktivitas. Klik indikator membuka pengelolaan terkait. Semua statistik berasal dari API.

Data Master menjadi pusat siswa/guru/orang tua. Detail memuat identitas, akun dan relasi; nama relasi dapat diklik untuk membuka data terkait. Klik dua kali baris merupakan pintasan tambahan, bukan pengganti tombol detail atau pemicu perubahan.

Kelas & Akademik menampilkan kelas terlebih dahulu dengan pilihan tahun ajaran/semester. Anggota dan wali dikelola dari detail kelas dengan pilihan riwayat lengkap. Peran utama tetap tunggal; tugas Wali/Pembina dikelola melalui penugasan.

Badge menggunakan katalog kartu, pemilih 24 ikon, formulir bertahap, level dengan satu syarat, serta pratinjau. Versi berjalan/sudah digunakan ditampilkan terkunci; versi baru untuk semester mendatang dibuat dalam alur yang sama.

Login dipakai bersama oleh Admin, Kesiswaan, Kepala Sekolah. Formulir kanan dipertahankan. Foto kiri diperlebar dengan rasio asli 4:3, tanpa rotasi dan tanpa memotong papan nama; panel foto disembunyikan pada layar kecil.


## Kesiswaan: konteks siswa dan detail terpadu

Menu Pusat Siswa membuka direktori nama/NISN dan kelas. Profil memiliki tab Ringkasan, Kehadiran, Pelanggaran, Penanganan yang Diizinkan, dan Prestasi. Nama siswa di antrean, laporan, rekap dan prestasi menuju profil yang sama. Detail memakai URL, tombol kembali mempertahankan konteks daftar; double-click merupakan pintasan tambahan.

Kategori menampilkan identitas dan kartu versi bersama laporan terkait. Prestasi menampilkan peserta, bukti dan audit; tombol koreksi/pembatalan hanya pada non-ekskul aktif. Formulir siswa terisi awal ketika dibuat dari profil, tetap mendukung tim. Rekap memakai tab kehadiran/pelanggaran, dengan pratinjau dan unduhan CSV memakai filter sama.

Dashboard memisahkan antrean verifikasi laporan dari antrean keputusan usulan. Semua KPI interaktif membuka bagian terkait. Kartu detail memakai radius 20 px, kartu kecil 16 px, kontrol 12 px, warna/navy dan komponen ManagementUi bersama. Layar sempit memakai susunan bertingkat; hanya tabel/grafik yang menggulir horizontal. Login dan portal Admin dipertahankan.
