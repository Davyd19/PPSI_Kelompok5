# Mobile SIM Kesiswaan (Guru)

Aplikasi Flutter khusus akun **Guru** (akun dibuat oleh Admin). Berjalan di **Android dan iOS**. Jalankan backend lebih dahulu.

```powershell
flutter pub get
flutter run
```

## Alamat backend (`API_BASE_URL`)

| Perangkat | Perintah |
|---|---|
| Android emulator | `flutter run` (otomatis `http://10.0.2.2:3000/api/v1`) |
| iOS Simulator (Mac) | `flutter run` (otomatis `http://127.0.0.1:3000/api/v1`) |
| HP fisik Android / iPhone | `flutter run --dart-define=API_BASE_URL=http://<IP-komputer>:3000/api/v1` (HP dan komputer di Wi-Fi yang sama) |
| Produksi | `--dart-define=API_BASE_URL=https://<domain-server>/api/v1` (iOS wajib HTTPS) |

## iOS

Build iOS **hanya bisa dari macOS** dengan Xcode (tidak bisa dari Windows).

```bash
flutter pub get
cd ios && pod install && cd ..
open -a Simulator
flutter run
```

- iPhone fisik: buka `ios/Runner.xcworkspace` di Xcode → *Runner* → *Signing & Capabilities* → pilih Team (Apple ID), lalu `flutter run`. Saat pertama kali, izinkan **Jaringan Lokal** dan percayai developer di *Pengaturan → Umum → VPN & Manajemen Perangkat*.
- Izin yang sudah dideklarasikan di `ios/Runner/Info.plist`: kamera & galeri (bukti pelanggaran), jaringan lokal. HTTP hanya diizinkan ke jaringan lokal untuk pengembangan.
- QR presensi dibuat dengan `qr_flutter` (murni Dart), tampil sama di Android dan iOS.

flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

API_BASE_URL di atas untuk Android emulator. Lihat [panduan pengembangan](../docs/development/README.md) untuk perangkat fisik/iOS. Beranda siswa mempertahankan simulasi Scan QR lokal, pencegahan presensi ganda, detail agenda/badge/notifikasi, dan reset ketika keluar. Presensi ekskul tetap manual oleh pembina pada implementasi modul nanti.
