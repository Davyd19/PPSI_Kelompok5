# Akun pengembangan SIM Kesiswaan

Jalankan `npm run db:migrate` dan `npm run db:seed:development` dari folder backend. Seeder pengembangan juga menjalankan seed wajib. Seeder berjalan pada mode development atau test. Keduanya menggunakan akun fiktif dengan kata sandi awal **Contoh123!**.

| Identitas | Peran |
|---|---|
| `contoh.admin` | Admin web |
| `contoh.guru` | Kesiswaan dan Kepala Sekolah di web. Guru, Wali Kelas, Guru BK, dan Pembina di mobile sesuai penugasan aktif. |
| `contoh.siswa` | Siswa mobile |
| `contoh.ortu` | Orang Tua mobile |

Seed ulang mempertahankan status dan kata sandi akun yang sudah ada. Untuk konfigurasi database dan perintah menjalankan backend serta web, gunakan [panduan setup](ADMIN_SETUP.md).

Untuk Android Emulator, jalankan `flutter pub get` lalu `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1` dari folder mobile. Pada perangkat fisik, gunakan alamat LAN komputer yang menjalankan backend.

Jalankan `npm run badge:recalculate` dari folder backend untuk menghitung ulang presensi lama. Selama backend berjalan, perhitungan juga dijadwalkan setiap lima menit.

