# Aturan sistem SIM Kesiswaan

Dokumen ini menjadi rujukan aturan bisnis bersama tim dan AI. Instalasi ada di [README utama](../README.md), kontrak ada di [API](api/README.md). Jika pengguna menyetujui perubahan aturan, ubah dokumen ini dan kode/pengujian terkait bersama-sama. Jangan menyimpulkan aturan baru dari ilustrasi UI.

## Akun, platform dan tugas

- Guru, Siswa dan Orang Tua memiliki tabel akun masing-masing. Guru memiliki tepat satu peran utama: GURU, GURU_BK, ADMIN, KESISWAAN atau KEPALA_SEKOLAH.
- Admin, Kesiswaan dan Kepala Sekolah memakai web. Siswa, Orang Tua, Guru dan Guru BK memakai mobile.
- Guru BK memperoleh fitur dasar Guru dan fitur BK yang diizinkan. Wali Kelas dan Pembina Ekstrakurikuler merupakan penugasan aktif, bukan akun/peran utama baru.
- Satu akun membuka satu workspace; menu tambahan mengikuti peran utama dan penugasan. Tidak ada pemilih peran setelah login. Akun Guru tidak otomatis mendapat portal Kesiswaan.
- Backend memeriksa status akun, peran dan masa penugasan pada permintaan. Menyembunyikan menu bukan otorisasi.
- Orang Tua hanya melihat anak yang terhubung dalam masa hubungan; Wali Kelas dan Pembina mengikuti kelas/kegiatan yang ditugaskan. Orang Tua yang juga Guru boleh memiliki akun terpisah.
- Login, refresh dan logout memakai API bersama. Logout mencabut sesi perangkat; reset kata sandi/penonaktifan mencabut sesi akun. Seed ulang tidak menimpa sandi/status akun yang sudah ada.

## Akademik

Tahun ajaran, semester, kelas dan riwayat kelas mempertahankan konteks tanggal. Penugasan dan masa keanggotaan tidak boleh bertumpuk sehingga menimbulkan kewenangan atau keanggotaan aktif ganda. Riwayat tidak dihapus hanya karena siswa pindah kelas atau guru berganti tugas.

## Presensi sekolah

- Sesi PAGI dan ZUHUR berlaku bagi seluruh sekolah, dengan roster siswa dari riwayat kelas pada tanggal sesi. Tidak ada cakupan kelas khusus sesi.
- Satu sesi per tanggal dan jenis. Guru/Guru BK membuat satu QR yang sama untuk seluruh siswa. Token tetap sama saat jadwal diedit.
- Waktu QR ditetapkan dengan **jam mulai dan jam tutup WIB pada tanggal sesi**. Server menerima scan jika `mulai <= waktu_server < tutup`, sesi masih terbuka dan siswa berhak. Sebelum mulai dan pada/setelah tutup, scan ditolak.
- Setiap scan yang diterima menghasilkan HADIR. Tidak ada TERLAMBAT untuk pencatatan atau koreksi baru. Data TERLAMBAT lama tetap terbaca dalam riwayat, rekap dan versi aturan lama; tidak dikonversi diam-diam.
- Kedaluwarsa QR hanya menutup akses scan. Guru tetap dapat mencatat manual selama sesi AKTIF, sampai sesi ditutup secara eksplisit.
- Guru/Guru BK aktif dapat mengubah jam mulai/tutup sesi hari ini yang masih terbuka, termasuk mengaktifkan QR kedaluwarsa. Tanggal dan jenis sesi tidak diubah. Sesi DITUTUP tidak dibuka ulang.
- Perubahan jadwal mencatat pelaku serta nilai sebelum/sesudah dalam audit. Tidak mengubah presensi yang sudah tersimpan atau aturan badge lama.
- Pilihan manual: HADIR, IZIN, SAKIT, ALFA, serta PENGECUALIAN_SAH khusus Zuhur. Koreksi memerlukan alasan dan audit.
- Tidak ada catatan berarti BELUM_DIISI, bukan Alfa otomatis. Satu siswa maksimal satu catatan per sesi. Pengecualian sah Zuhur dipisahkan dari ketidakhadiran.
- Kolom batas_tepat_waktu dipertahankan sebagai data legacy, tidak menentukan status pencatatan baru.

## Ekstrakurikuler dan portofolio

- Kegiatan mempunyai periode tahun ajaran, pembina, pendaftaran, keanggotaan dan masa aktif. Siswa boleh mengikuti beberapa ekskul; satu kegiatan dapat memiliki beberapa pembina.
- Siswa mengajukan pendaftaran; Pembina memeriksa sesuai penugasan dan kapasitas jika ditetapkan. Persetujuan dan pembentukan masa aktif dilakukan konsisten dalam transaksi.
- Pertemuan bertanggal menyimpan status sesi presensi. **Presensi sepenuhnya manual oleh Pembina**, anggota dipilih satu per satu. Tidak ada QR ekskul atau pencatatan mandiri siswa.
- Pencatatan awal hanya pada sesi terbuka. Koreksi catatan yang sudah ada dapat dilakukan setelah ditutup dengan alasan dan riwayat. Penutupan tidak mengisi Alfa otomatis.
- Satu catatan per keanggotaan–pertemuan; masa keanggotaan harus mencakup tanggal pertemuan.
- Portofolio menyimpan kegiatan atau prestasi, dapat mempunyai beberapa peserta dan lampiran. Prestasi dapat individu/tim dan boleh di luar ekskul. Pengunggahan/unduhan tetap memeriksa kewenangan.

## Pelanggaran dan pendampingan

- Laporan kejadian diperiksa satu per satu dan merujuk versi aturan pada tanggal kejadian. Aturan yang sudah dipakai tidak ditimpa; perubahan ketentuan dibuat sebagai versi baru.
- Beberapa laporan siswa yang sama dapat menjadi bahan satu PenangananSiswa. Pendampingan juga boleh dibuka tanpa laporan pelanggaran.
- Rencana konseling terpisah dari pelaksanaan. Asesmen, konseling, tindak lanjut, usulan dan keputusan tersimpan sebagai riwayat dengan konteks yang sah.
- Catatan internal BK hanya untuk pihak BK yang berwenang. Pihak lain memperoleh ringkasan yang diizinkan, bukan isi internal.
- Eskalasi dapat disetujui, ditolak atau diminta revisi. Cegah keputusan akhir ganda dengan transaksi/penguncian. Persetujuan eskalasi tidak otomatis menutup penanganan atau mencatat rujukan.
- Tidak ada akumulasi poin atau sanksi otomatis.

## Badge, notifikasi dan audit

- Badge diberikan otomatis dari presensi sekolah/ekskul melalui versi aturan dan level. Tidak ada pemberian atau verifikasi manual.
- Satu syarat terstruktur per level. Progres dihitung dari sumber; pencapaian disimpan unik per siswa–level. Perubahan aturan berlaku semester berikutnya; versi lama tetap menjadi dasar pencapaian lama.
- Hitungan beruntun menggunakan sesi yang berlaku, melewati pengecualian sah; data belum diisi menghasilkan progres sementara. Koreksi dapat menonaktifkan/mengaktifkan kembali pencapaian yang sama dengan audit.
- Aturan baru tidak menawarkan TERLAMBAT; versi historis tidak diubah hanya karena aturan presensi baru.
- Satu notifikasi dapat mempunyai banyak penerima dengan waktu baca masing-masing. Audit merekam pelaku, tindakan, alasan dan perubahan atribut; tidak merekam sandi, hash atau token mentah.

## Implementasi dan tampilan

Sumber skema terkini adalah `backend/src/models/schema.json` beserta migrasi tambahan. Jangan mengasumsikan jumlah tabel selalu tetap. Backend mempertahankan route → controller → model, React dan Flutter memakai komponen bersama. Data kosong, gagal dan fitur belum tersedia harus dinyatakan jujur. Gradien dekoratif diperbolehkan bila konsisten dengan desain; ikon memakai pustaka ikon, bukan emoji.
