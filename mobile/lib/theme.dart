import 'widgets/design_tokens.dart';
import 'package:flutter/material.dart';

// Token warna yang sama dengan portal web (styles/portal.css) agar web dan mobile terasa satu sistem.
const navy = Color(0xFF0E2A47),
    blue = Color(0xFF3D5F92),
    muted = Color(0xFF5A6A7C),
    canvas = Color(0xFFF4F6F9),
    line = Color(0xFFE3E8F0),
    soft = Color(0xFFF1F4F9),
    danger = Color(0xFFB0584F);

/// Warna merek dari logo: navy tua, biru buku, dan kuning matahari.
const brandDeep = Color(0xFF0A1F3A),
    brandMid = Color(0xFF12365E),
    brandBlue = Color(0xFF1E63A8),
    brandSun = Color(0xFFF2C14E),
    brandSky = Color(0xFF5FA8E8);

/// Gradasi merek untuk kartu sapaan, kepala halaman, dan login.
const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [brandDeep, brandMid, brandBlue],
  stops: [0, .6, 1],
);

/// Bayangan lembut untuk kartu putih agar tidak terasa datar.
const softShadow = [
  BoxShadow(color: Color(0x0F0E2A47), blurRadius: 18, offset: Offset(0, 6)),
];

/// Bayangan untuk panel bergradasi.
const brandShadow = [
  BoxShadow(color: Color(0x330A1F3A), blurRadius: 22, offset: Offset(0, 10)),
];

/// Palet grafik dan aksen lembut: (warna utama, latar lembut).
const cNavy = (Color(0xFF26476F), Color(0xFFE5EBF4)),
    cTeal = (Color(0xFF2B7C86), Color(0xFFE0F0F1)),
    cGreen = (Color(0xFF3F7F5F), Color(0xFFE3F1E9)),
    cAmber = (Color(0xFFB3842F), Color(0xFFF6EEDB)),
    cBrick = (Color(0xFFB0584F), Color(0xFFF8E6E3)),
    cHeather = (Color(0xFF77679A), Color(0xFFECE8F4));
const accentCycle = [cNavy, cTeal, cAmber, cGreen, cHeather];

/// Aksen khas tiap jenis akun, setara dengan warna aksen portal web.
class PortalTone extends InheritedWidget {
  const PortalTone({
    super.key,
    required this.color,
    required this.soft,
    required this.ink,
    required super.child,
  });

  final Color color, soft, ink;

  static const _teal = (
    Color(0xFF226A75),
    Color(0xFFE0EFF1),
    Color(0xFF174B53),
  );
  static const _slate = (
    Color(0xFF3D5F92),
    Color(0xFFE6ECF6),
    Color(0xFF283F63),
  );
  static const _green = (
    Color(0xFF3A7656),
    Color(0xFFE3F0E8),
    Color(0xFF24503A),
  );

  /// Guru = teal (seperti portal Kesiswaan), siswa = biru batu, orang tua = hijau.
  factory PortalTone.forRoles(List<String> roles, {required Widget child}) {
    final t = roles.contains('SISWA')
        ? _slate
        : roles.contains('ORANG_TUA')
        ? _green
        : _teal;
    return PortalTone(color: t.$1, soft: t.$2, ink: t.$3, child: child);
  }

  static PortalTone of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PortalTone>() ??
      const PortalTone(
        color: Color(0xFF226A75),
        soft: Color(0xFFE0EFF1),
        ink: Color(0xFF174B53),
        child: SizedBox.shrink(),
      );

  @override
  bool updateShouldNotify(PortalTone old) =>
      color != old.color || soft != old.soft || ink != old.ink;
}

final appTheme = ThemeData(
  fontFamily: SchoolDesign.fontFamily,
  useMaterial3: true,
  // Transisi halaman yang halus dan konsisten (memudar sambil bergeser).
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
  ),
  scaffoldBackgroundColor: canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: navy,
    primary: navy,
    surface: Colors.white,
    error: danger,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontFamily: SchoolDesign.fontFamily,
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -.4,
      color: navy,
    ),
    headlineSmall: TextStyle(
      fontFamily: SchoolDesign.fontFamily,
      fontSize: 23,
      fontWeight: FontWeight.w700,
      letterSpacing: -.3,
      color: navy,
    ),
    titleLarge: TextStyle(
      fontFamily: SchoolDesign.fontFamily,
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: -.2,
      color: navy,
    ),
    titleMedium: TextStyle(
      fontFamily: SchoolDesign.fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: navy,
    ),
    labelSmall: TextStyle(
      fontFamily: SchoolDesign.fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: .8,
      color: muted,
    ),
    bodyMedium: TextStyle(
      fontFamily: SchoolDesign.fontFamily,
      fontSize: 13,
      height: 1.45,
      color: muted,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    foregroundColor: navy,
    elevation: 0,
    scrolledUnderElevation: 0,
    shape: Border(bottom: BorderSide(color: line)),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    height: 68,
    // Menu aktif ditandai pil navy (ikon putih) + label tebal.
    indicatorColor: brandMid,
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        color: states.contains(WidgetState.selected) ? Colors.white : muted,
      ),
    ),
    elevation: 8,
    shadowColor: const Color(0x220A1F3A),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontFamily: SchoolDesign.fontFamily,
        fontSize: 12,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
        color: states.contains(WidgetState.selected) ? navy : muted,
      ),
    ),
  ),
  cardTheme: const CardThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: SchoolDesign.cardBorder,
      side: BorderSide(color: line),
    ),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(SchoolDesign.dialogRadius),
      ),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SchoolDesign.dialogRadius),
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: navy,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SchoolDesign.controlRadius),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    constraints: const BoxConstraints(minHeight: SchoolDesign.touchTarget),
    filled: true,
    fillColor: soft,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SchoolDesign.controlRadius),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SchoolDesign.controlRadius),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SchoolDesign.controlRadius),
      borderSide: const BorderSide(color: blue, width: 1.5),
    ),
  ),
  // Warna teks chip ditulis eksplisit agar tetap terbaca (tanpa warna, teks bisa putih di atas latar terang).
  chipTheme: ChipThemeData(
    backgroundColor: Colors.white,
    selectedColor: const Color(0xFFE0EFF1),
    checkmarkColor: const Color(0xFF174B53),
    side: WidgetStateBorderSide.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? BorderSide.none
          : const BorderSide(color: line),
    ),
    shape: const StadiumBorder(),
    labelStyle: const TextStyle(
      fontFamily: SchoolDesign.fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: navy,
    ),
    secondaryLabelStyle: const TextStyle(
      fontFamily: SchoolDesign.fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF174B53),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: navy,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SchoolDesign.controlRadius),
      ),
      textStyle: const TextStyle(
        fontFamily: SchoolDesign.fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: navy,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SchoolDesign.controlRadius),
      ),
      side: const BorderSide(color: line),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: const Color(0xFF226A75),
    ),
  ),
);
