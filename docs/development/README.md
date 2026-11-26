# Kerja tim

Instalasi dan perintah run ada di [README utama](../../README.md). Baca [aturan sistem](../SYSTEM_RULES.md) dan desain platform sebelum mengubah kode.

- Koordinasikan perubahan skema, autentikasi dan komponen bersama. Gunakan migrasi tambahan; jangan menjalankan sync alter atau reset database anggota lain.
- Backend tetap route → controller → model. Nama file mengikuti fitur. Komponen umum dipakai bersama, komponen khusus tetap dekat halaman.
- Untuk pekerjaan baru, gunakan branch `feature/...` atau `fix/...` sesuai kesepakatan tim dan PR ke main. Jangan membuat branch/commit/push melalui AI tanpa permintaan pengguna. Hubungkan PR ke issue yang benar-benar diselesaikan.
- Simpan `.env`, dependency, build dan konfigurasi lokal di luar Git. Akun contoh hanya untuk pengembangan.
- Jalankan pemeriksaan sesuai cakupan. Integrasi memakai database QA terpisah; widget test tidak menggantikan uji perangkat.

## Masalah umum

- Login gagal setelah mengubah seed: seed tidak menimpa akun lama. Periksa akun/peran aktif di database atau lakukan reset sandi melalui Admin.
- API gagal: pastikan MySQL dan backend berjalan, koneksi `.env` benar, serta migrasi terbaru sudah dijalankan.
- Emulator gagal terhubung: gunakan 10.0.2.2, bukan localhost. Perangkat fisik memakai IP LAN komputer.
- Vite menampilkan halaman Laravel: Anda menjalankan proyek atau port lain. Jalankan React dari frontend_web dan gunakan URL yang dicetak terminal tersebut.

[Akun contoh](EXAMPLE_ACCOUNTS.md) · [API BK/Wali](BK_WALI.md) · [Arsip pemeriksaan lama](../archive/README.md)
