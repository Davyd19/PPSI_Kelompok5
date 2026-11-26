# Panduan perubahan proyek

Sebelum mengubah kode, baca [aturan sistem](docs/SYSTEM_RULES.md), kemudian panduan desain [bersama](docs/design/DESIGN.md), [web](frontend_web/DESIGN.md), atau [mobile](mobile/DESIGN.md) sesuai cakupan.

- Aturan bisnis mengikuti SYSTEM_RULES, source code dan permintaan terbaru pengguna. Gambar UI bukan sumber aturan bisnis. Jika perubahan yang diminta bertentangan atau ambigu, jelaskan dampaknya dan klarifikasi sebelum mengubah aturan. Jangan meminta ulang izin untuk pekerjaan yang sudah jelas disetujui.
- Pertahankan perubahan lokal dan pekerjaan anggota lain. Periksa status Git sebelum bekerja. Jangan membuat branch, commit, push, merge atau mengubah remote tanpa permintaan pengguna.
- Backend mengikuti route → controller → model. Gunakan helper/komponen bersama yang sudah ada; jangan membuat lapisan arsitektur tambahan hanya untuk menyusun ulang kode.
- Satu akun mempunyai satu peran utama. Guru BK memakai fitur dasar Guru; tugas Wali Kelas/Pembina menambah menu dalam workspace yang sama. Jangan membuat pemilih peran setelah login.
- QR hanya presensi sekolah. Presensi ekskul manual oleh Pembina. Belum Diisi tidak otomatis Alfa. Jangan menambahkan keterlambatan, poin, sanksi otomatis, atau badge manual.
- Perubahan skema memakai migrasi tambahan. Jangan mengedit migrasi yang sudah dipakai, menjalankan sync alter, DROP/reset database, atau menimpa akun lama tanpa instruksi eksplisit.
- Rahasia tetap di konfigurasi lokal; jangan menulis kata sandi/hash/token ke audit atau log. Akun contoh dijelaskan terpisah dalam panduan pengembangan.
- Jalankan pemeriksaan yang relevan dengan perubahan. Integrasi memakai database QA terpisah. Jangan build APK jika pengguna memilih membangunnya sendiri.
- Sebutkan pengujian yang benar-benar dijalankan serta keterbatasannya. Widget test bukan bukti bahwa aplikasi sudah diuji di perangkat Android.
- Saat aturan berubah dengan persetujuan pengguna, perbarui SYSTEM_RULES, kontrak API dan pengujian terkait. Laporan lama di docs/archive adalah riwayat, bukan spesifikasi terkini.
