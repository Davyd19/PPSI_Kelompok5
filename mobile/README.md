# Mobile SIM Kesiswaan

Flutter untuk Siswa, Orang Tua, Guru, Wali Kelas, Guru BK, dan Pembina Ekstrakurikuler. Jalankan backend lebih dahulu. Pemilihan profil merupakan simulasi; tidak ada autentikasi nyata.

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

API_BASE_URL di atas untuk Android emulator. Lihat [panduan pengembangan](../docs/development/README.md) untuk perangkat fisik/iOS. Beranda siswa mempertahankan simulasi Scan QR lokal, pencegahan presensi ganda, detail agenda/badge/notifikasi, dan reset ketika keluar. Presensi ekskul tetap manual oleh pembina pada implementasi modul nanti.
