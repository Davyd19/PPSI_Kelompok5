# Mobile Flutter

Jalankan MySQL dan backend, lalu dari folder ini:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

Android emulator menggunakan `10.0.2.2`; HP fisik menggunakan IP LAN komputer dengan jaringan yang sama. iOS simulator menggunakan `localhost` dan memerlukan macOS/Xcode. Pengaturan HTTP lokal hanya untuk pengembangan.

Login untuk Siswa, Orang Tua, Guru atau Guru BK. Tugas Wali Kelas/Pembina menambah fitur pada akun Guru yang sama; tidak ada pemilih peran. [Daftar akun](../docs/development/EXAMPLE_ACCOUNTS.md).

Pemeriksaan: `flutter analyze` dan `flutter test`. Build/run Android dapat dilakukan melalui Android Studio. Jika Gradle terkunci, hentikan build lain, jalankan `android/gradlew --stop`, lalu coba satu build saja. Pastikan ruang disk cukup.

[Aturan sistem](../docs/SYSTEM_RULES.md) · [Desain mobile](DESIGN.md) · [Instalasi backend](../README.md)
