# Mobile SIM Kesiswaan — SMAN 12 Padang

Flutter untuk Siswa, Orang Tua, Guru, dan Guru BK. Wali Kelas/Pembina merupakan tugas tambahan pada akun Guru/Guru BK. Admin, Kesiswaan, dan Kepala Sekolah memakai web. [Akun contoh](../docs/development/EXAMPLE_ACCOUNTS.md) · [Panduan desain](DESIGN.md).

Jalankan migrasi/seed dan backend dahulu. Dari mobile:

```powershell
flutter pub get
flutter run
```

| Perangkat | Alamat API |
|---|---|
| Android emulator | Bawaan http://10.0.2.2:3000/api/v1 |
| iOS Simulator | Bawaan http://127.0.0.1:3000/api/v1 |
| HP fisik | flutter run --dart-define=API_BASE_URL=http://IP-komputer:3000/api/v1 |
| Produksi | --dart-define=API_BASE_URL=https://domain-server/api/v1 |

Login, refresh, logout, dan profil memakai API. Guru mempertahankan halaman profil yang dapat diedit; Siswa/Orang Tua memakai halaman operasional hasil integrasi tim. QR berlaku untuk sekolah; ekskul dicatat manual oleh Pembina. Fitur BK/Wali yang belum tersedia diberi keterangan, tanpa data simulasi pengganti.

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Build Android dijalankan pengguna. Percobaan build pada sesi integrasi berhenti karena drive C: kehabisan ruang, bukan karena error kompilasi Dart. Build/runtime APK terbaru belum diverifikasi; kosongkan ruang sebelum membangun. Artefak perantara build gagal telah dibersihkan; kode dan data tidak direset.

Build iOS memerlukan macOS, Xcode, CocoaPods, dan signing perangkat bila diperlukan. Runtime iOS belum diperiksa pada Windows. Kamera/galeri mengikuti izin yang sudah dideklarasikan dalam proyek.

## Jika executionHistory Gradle terkunci

Hentikan Run/build yang masih berjalan di Android Studio atau terminal lain. Gunakan satu proses build untuk proyek ini. Daemon Gradle versi proyek dapat dihentikan dengan `android/gradlew.bat --stop`. Jangan menghapus cache ketika build masih aktif.

Pada pemeriksaan 25 November 2026, daemon 9.5 dihentikan dan cache executionHistory lama dicadangkan di android/.gradle/9.5.0/executionHistory.backup-*. Pemeriksaan `gradlew help --no-daemon` berhasil dengan JDK Android Studio 21.0.6. Ini memverifikasi startup/task Gradle, bukan keberhasilan assembleDebug atau runtime APK.

Terminal biasa terdeteksi memakai Java 8. Jika menjalankan Gradle dari PowerShell, atur Java untuk sesi terminal tersebut menggunakan JDK Android Studio (sesuaikan path jika instalasi berbeda):

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

Pengaturan tersebut tidak mengubah Java global Windows. Untuk Flutter, gunakan konfigurasi JDK Flutter/Android Studio yang konsisten. Build mobile tetap dijalankan pengguna.
