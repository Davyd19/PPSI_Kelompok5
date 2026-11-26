# Akun pengembangan SIM Kesiswaan

Dari backend, jalankan `npm run db:migrate`, lalu `npm run db:seed:required` dan `npm run db:seed:development`. Seed pengembangan juga menyiapkan seed wajib, hanya untuk development/test, tanpa SEED_* di .env.

| Identitas | Peran utama | Platform |
|---|---|---|
| contoh.admin | Admin | Web |
| contoh.kesiswaan | Kesiswaan | Web |
| contoh.kepsek | Kepala Sekolah | Web |
| contoh.guru | Guru | Mobile |
| contoh.bk | Guru BK, termasuk fitur dasar Guru | Mobile |
| contoh.wali | Guru dengan tugas Wali Kelas | Mobile |
| contoh.pembina | Guru dengan tugas Pembina Ekstrakurikuler | Mobile |
| contoh.siswa | Siswa | Mobile |
| contoh.ortu | Orang Tua | Mobile |

Kata sandi awal akun contoh yang **baru dibuat**: `Contoh123!`. Akun yang sudah ada mempertahankan kata sandi, status, dan peran utamanya. Guru dengan tugas Wali Kelas/Pembina memakai akun yang sama; akses mengikuti penugasan aktif, tanpa pemilih peran setelah login.

Migrasi memetakan peran lama, bukan mengubahnya berdasarkan nama akun. Akun contoh.guru lama yang berperan BK tetap BK. Ubah secara eksplisit melalui Admin bila diperlukan. Jika beberapa peran utama aktif berbenturan, migrasi berhenti sebelum perubahan skema dan menampilkan akun yang perlu ditentukan perannya.

Alamat API Android emulator: `http://10.0.2.2:3000/api/v1`; perangkat fisik menggunakan IP LAN komputer. Lihat [aturan sistem](../SYSTEM_RULES.md) dan [setup](../../README.md).

Perintah `npm run badge:recalculate` menghitung ulang badge; backend juga menjadwalkan perhitungan tiap lima menit. Tidak ada pemberian badge manual.

## Kompatibilitas database sebelum integrasi

Jika database masih mempunyai tabel bukti_laporan dan kolom tempat_kejadian/id_peran_utama yang dibuat migrasi lama, jalankan db:migrate dengan kode terbaru. Migrasi mengenali kolom yang sudah ada dan mengubah nama tabel bukti menjadi lampiran_laporan_pelanggaran sambil mempertahankan datanya. Berkas bukti lama tetap dapat diunduh dari direktori laporan lama melalui API Kesiswaan berizin. Jangan DROP database hanya untuk mengatasi perbedaan nama tabel.

contoh.wali mempunyai kelas XI Wali Contoh terpisah agar tidak bertabrakan dengan penugasan contoh.guru; kelas tersebut belum memiliki anggota siswa contoh. contoh.pembina ditugaskan pada Pramuka Contoh. Akun yang sudah ada tidak ditimpa.
