# Integrasi Guru BK dan Wali Kelas

Modul memakai route → controller → model yang sudah ada. Tidak menambah tabel atau mengubah database ketika server dinyalakan.

## Akses dan navigasi

- Guru BK membuka **Penanganan Siswa**; Wali Kelas membuka **Kelas Binaan** pada beranda Guru yang sama.
- Jika akun memiliki kedua kewenangan, kedua pintu fitur tersedia tanpa memilih peran saat login. Fitur dasar Guru, laporan sendiri, profil, dan tugas Pembina tetap tersedia.
- Backend memeriksa akun dan penugasan aktif pada setiap permintaan. Wali hanya dapat mengakses siswa yang saat ini berada di kelas binaannya.
- Penanganan BK hanya terbuka bagi BK penanggung jawab. Laporan yang belum mempunyai penanganan dapat diperiksa BK; tindakan lanjutan BK menetapkan penanggung jawab dalam transaksi.

## Proses yang tersedia

BK: daftar/detail, verifikasi, tambah/ubah rencana konseling terbaru yang masih aktif, catatan konseling, komunikasi orang tua, pemantauan, tindak lanjut, usulan eskalasi/rujukan, dan penutupan.

Wali: daftar/detail siswa binaan, catatan pembinaan, komunikasi orang tua, pemantauan, tindak lanjut, serta usulan penutupan/eskalasi. Wali tidak dapat memverifikasi atau menutup langsung.

- Laporan menunggu verifikasi harus diperiksa sebelum ditindaklanjuti; penolakan tidak membuka konseling.
- Laporan dan penanganan merupakan dua sumber berbeda. DTO menyertakan `sumber: LAPORAN | PENANGANAN`; semua detail dan tindakan menerima query `sumber`, dengan nilai awal `LAPORAN`. ID numerik boleh sama tanpa menunjuk data yang salah.
- Daftar menyatukan laporan yang belum terhubung dan penanganan yang berada dalam kewenangan pengguna. Penanganan tanpa laporan juga tersedia.
- Catatan internal asesmen/konseling, evaluasi eskalasi, dan informasi pendukung BK tidak dikirim kepada Wali. Ringkasan yang diizinkan disimpan terpisah.
- Usulan eskalasi/rujukan masuk ke antrean Kesiswaan yang sudah ada. Keputusan akhir tetap dilakukan oleh pihak berwenang. Usulan penutupan Wali diselesaikan melalui penutupan eksplisit BK.
- Pemantauan “Tidak perlu tindak lanjut” tidak otomatis menutup. Penutupan ditolak ketika eskalasi/rujukan masih menunggu atau sudah disetujui; tidak ada penutupan otomatis saat eskalasi disetujui.
- Penyimpanan dan audit memakai transaksi. Verifikasi ganda dan usulan sejenis yang masih menunggu ditolak. Gagal memuat rencana tidak dianggap sebagai rencana kosong.

## Endpoint

Seluruh endpoint di bawah memerlukan token mobile. Awalan `/api/v1/guru-bk/kasus` dan `/api/v1/wali-kelas/kasus`.

| Metode dan akhiran | BK | Wali |
|---|---|---|
| GET `/` dan `/:id` | Ya | Ya |
| POST `/:id/verifikasi` | Ya | Tidak |
| GET/POST `/:id/rencana-konseling` | Ya | Tidak |
| POST `/:id/catatan-konseling` | Ya | Tidak |
| POST `/:id/catatan-pembinaan` | Tidak | Ya |
| POST `/:id/tindak-lanjut-ortu` | Ya | Ya |
| POST `/:id/pemantauan` | Ya | Ya |
| POST `/:id/tindak-lanjut` | Ya | Ya |
| POST `/:id/eskalasi` | Ya | Tidak |
| POST `/:id/usulan` | Tidak | Ya |
| POST `/:id/tutup` | Ya | Tidak |

Daftar menerima `status` sesuai lima status tampilan. Respons menggunakan `{data: ...}` dan format error backend yang sudah ada. Payload mengikuti `mobile/lib/network/kasus_api.dart`.

## Mencoba lokal

Jalankan backend seperti biasa. Jika memerlukan skenario contoh baru, dari folder backend jalankan `npm run db:seed:development`. Seed menambah contoh pendampingan BK tanpa pelanggaran dan laporan menunggu verifikasi, tanpa mengambil alih penanggung jawab data lama.

Pada main lokal yang memakai peran utama, akun BK adalah `contoh.bk`. Pada versi main remote lama, contoh Guru merangkap BK/Wali sesuai penugasan seed. Ikuti dokumentasi akun proyek untuk kata sandi; seed ulang tidak mengganti sandi akun yang sudah ada.

Tidak perlu DROP database untuk integrasi ini. Migrasi lain yang memang belum dijalankan tetap mengikuti panduan proyek. Modul ini tidak menyediakan pemindahan penanggung jawab penanganan; data lama tetap mengikuti BK yang tercatat.

## Pemeriksaan

- `node --test tests/pendampingan.integration.js`, hanya dengan database uji berakhiran `_qa` yang telah dimigrasi dan di-seed.
- Pengujian mencakup akses Wali, BK lain, catatan privat, validasi, rollback saat audit gagal, verifikasi bersamaan, rencana, keterlibatan orang tua, pemantauan, peninjauan eskalasi Kesiswaan, penutupan, konseling tanpa laporan, dan penugasan berakhir.
- Flutter: `flutter analyze --no-pub` dan `flutter test --no-pub test/kasus_test.dart test/bk_wali_integration_test.dart test/guru_merge_test.dart`.
- Build APK dan uji perangkat dilakukan oleh pemilik proyek.
