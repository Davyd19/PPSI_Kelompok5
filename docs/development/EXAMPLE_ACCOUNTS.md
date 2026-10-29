# Akun contoh prototipe UI

Semua akun di bawah menggunakan kata sandi **Contoh123!**. Identitas akun menentukan peran; tidak ada tombol demo atau pemilih peran pada login.

| Platform | Identitas | Peran |
|---|---|---|
| Web | admin | Admin |
| Web | kesiswaan | Kesiswaan |
| Web | kepsek | Kepala Sekolah |
| Mobile | siswa | Siswa |
| Mobile | ortu | Orang Tua |
| Mobile | guru | Guru |
| Mobile | wali | Wali Kelas |
| Mobile | bk | Guru BK |
| Mobile | pembina | Pembina Ekstrakurikuler |

Ini pencocokan lokal untuk navigasi prototipe, bukan autentikasi atau pembatasan akses nyata. Kata sandi tidak dikirim ke API, disimpan, atau dicatat. Jangan gunakan kredensial sekolah sebenarnya. Identitas dari platform lain ditolak dengan arahan platform yang sesuai.

Setelah akun cocok, klien mengambil profil dan dashboard dari API. Backend harus berjalan. Login gagal bila profil/API tidak tersedia. Kata sandi dibersihkan setelah percobaan masuk. Keluar mereset sesi dan simulasi presensi. Tidak ada Ingat Saya.

Login dan beranda mengikuti referensi gambar. Tautan bantuan/lupa sandi memberi informasi tanpa mengaku mengirim reset. Menu di luar cakupan membuka keterangan fitur belum tersedia. Notifikasi/profil serta detail siswa yang sudah dibuat tetap bekerja. Grafik web dapat mengganti periode September/Oktober dan tingkat kelas; kartu yang berjudul Hari Ini tetap snapshot 22 Oktober 2026.
