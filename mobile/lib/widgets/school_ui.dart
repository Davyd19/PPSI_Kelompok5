import 'dart:async';

import 'package:flutter/material.dart';
import '../theme.dart';
import 'design_tokens.dart';

const schoolBlue = Color(0xFF2768B2);
const schoolGreen = Color(0xFF1E7D4F);
const schoolOrange = Color(0xFFB26A00);
const schoolPurple = Color(0xFF6A4BB2);
const schoolRed = Color(0xFFC62828);
const schoolAccents = [schoolBlue, schoolOrange, schoolPurple, schoolGreen];

/// Apakah semua kata pada [query] muncul di salah satu [fields]
/// (tanpa membedakan huruf besar/kecil, urutan kata bebas).
bool matchesSearch(String query, Iterable<String?> fields) {
  final words = query.trim().toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return true;
  final haystack = fields.whereType<String>().join(' ').toLowerCase();
  return words.every(haystack.contains);
}

/// Kolom pencarian seragam untuk semua daftar: ikon cari, tombol hapus,
/// dan jeda opsional ([debounce]) untuk pencarian ke server.
class SchoolSearchField extends StatefulWidget {
  const SchoolSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.debounce = Duration.zero,
    this.initialValue = '',
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final Duration debounce;
  final String initialValue;

  @override
  State<SchoolSearchField> createState() => _SchoolSearchFieldState();
}

class _SchoolSearchFieldState extends State<SchoolSearchField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {}); // tampilkan/sembunyikan tombol hapus
    _timer?.cancel();
    if (widget.debounce == Duration.zero) {
      widget.onChanged(value);
    } else {
      _timer = Timer(widget.debounce, () => widget.onChanged(value));
    }
  }

  void _clear() {
    _controller.clear();
    _timer?.cancel();
    setState(() {});
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(SchoolDesign.controlRadius),
      boxShadow: softShadow,
    ),
    child: TextField(
      controller: _controller,
      onChanged: _changed,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                icon: const Icon(Icons.close, size: 18),
                onPressed: _clear,
              ),
      ),
    ),
  );
}

/// Lokasi berkas logo aplikasi.
const schoolLogoAsset = 'assets/images/logo.png';

/// Logo SIM Kesiswaan SMAN 12 Padang. Dipakai di login dan kepala halaman.
class SchoolLogo extends StatelessWidget {
  const SchoolLogo({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    schoolLogoAsset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    semanticLabel: 'Logo SIM Kesiswaan',
    // Cadangan bila aset belum termuat (mis. sebelum build ulang).
    errorBuilder: (_, _, _) =>
        Icon(Icons.school_outlined, size: size * .8, color: navy),
  );
}

class SchoolSectionTitle extends StatelessWidget {
  const SchoolSectionTitle(
    this.title, {
    super.key,
    required this.icon,
    this.color = schoolBlue,
  });
  final String title;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: navy,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class SchoolCard extends StatelessWidget {
  const SchoolCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.accent,
    this.padding = const EdgeInsets.all(SchoolDesign.pageInset),
  });
  final Widget child;
  final Color color;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: SchoolDesign.cardBorder,
      border: Border.all(
        color: color == Colors.white ? line.withValues(alpha: .7) : color,
      ),
      // Kartu putih diberi bayangan lembut agar tidak terasa datar.
      boxShadow: color == Colors.white ? softShadow : null,
    ),
    child: child,
  );
}

/// Cahaya lembut (gradasi radial ke transparan) untuk panel bergradasi.
class SchoolGlow extends StatelessWidget {
  const SchoolGlow({
    super.key,
    required this.size,
    this.color = brandSun,
    this.opacity = .22,
  });
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

/// Panel bergradasi merek (navy -> biru logo) dengan cahaya lembut dan
/// tanda air logo. Dipakai kartu sapaan beranda dan kepala halaman fitur.
class SchoolBrandPanel extends StatelessWidget {
  const SchoolBrandPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
    this.watermark = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool watermark;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: brandGradient,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: brandShadow,
    ),
    child: Stack(
      children: [
        const Positioned(top: -70, right: -50, child: SchoolGlow(size: 190)),
        const Positioned(
          bottom: -80,
          left: -60,
          child: SchoolGlow(size: 200, color: brandSky, opacity: .18),
        ),
        if (watermark)
          Positioned(
            right: -18,
            bottom: -22,
            child: IgnorePointer(
              child: Opacity(
                opacity: .09,
                child: const SchoolLogo(size: 120),
              ),
            ),
          ),
        Padding(padding: padding, child: child),
      ],
    ),
  );
}

typedef GreetingInfo = ({IconData icon, String value, String label});

class SchoolGreeting extends StatelessWidget {
  const SchoolGreeting({
    super.key,
    required this.name,
    required this.first,
    required this.second,
    this.date,
    this.onFirstTap,
    this.onSecondTap,
  });
  final String name;
  final GreetingInfo first, second;
  final DateTime? date;

  /// Bila diisi, kotak info dapat diketuk (mis. membuka notifikasi).
  final VoidCallback? onFirstTap, onSecondTap;
  @override
  Widget build(BuildContext context) {
    final now = date ?? DateTime.now();
    final greeting = now.hour < 11
        ? 'Selamat pagi'
        : now.hour < 15
        ? 'Selamat siang'
        : now.hour < 18
        ? 'Selamat sore'
        : 'Selamat malam';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return SchoolBrandPanel(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '$greeting,',
                        style: const TextStyle(
                          color: Color(0xFFD9E9FA),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${now.day} ${months[now.month - 1]} ${now.year}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 8),
                // Garis aksen kuning matahari dari logo.
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: brandSun,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, c) {
                    final stacked =
                        MediaQuery.textScalerOf(context).scale(13) > 20 ||
                        c.maxWidth < 250;
                    return stacked
                        ? Column(
                            children: [
                              _stat(first, onFirstTap),
                              const SizedBox(height: 10),
                              _stat(second, onSecondTap),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: _stat(first, onFirstTap)),
                              const SizedBox(width: 10),
                              Expanded(child: _stat(second, onSecondTap)),
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(GreetingInfo info, VoidCallback? onTap) => Material(
    color: Colors.white.withValues(alpha: .12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Colors.white.withValues(alpha: .14)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: _statBody(info, onTap != null)),
  );

  Widget _statBody(GreetingInfo info, bool tappable) => Padding(
    padding: const EdgeInsets.all(10),
    child: Row(
      children: [
        Icon(info.icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                info.label,
                style: const TextStyle(color: Color(0xFFD9E9FA), fontSize: 10),
              ),
            ],
          ),
        ),
        if (tappable)
          const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
      ],
    ),
  );
}

class SchoolMenuItem {
  const SchoolMenuItem(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class SchoolMenuGrid extends StatelessWidget {
  const SchoolMenuGrid({super.key, required this.items});
  final List<SchoolMenuItem> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = MediaQuery.textScalerOf(context).scale(11) > 13.2
          ? 2
          : c.maxWidth < 300
          ? 2
          : items.length == 5 || items.length == 6
          ? 3
          : 4;
      return Column(
        children: [
          for (var offset = 0; offset < items.length; offset += columns)
            Padding(
              padding: EdgeInsets.only(
                bottom: offset + columns < items.length ? 10 : 0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < columns; index++) ...[
                      if (index > 0) const SizedBox(width: 10),
                      Expanded(
                        child: offset + index >= items.length
                            ? const SizedBox.shrink()
                            : _tile(items[offset + index]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  Widget _tile(SchoolMenuItem item) => Container(
    constraints: const BoxConstraints(minHeight: 104),
    decoration: const BoxDecoration(
      borderRadius: SchoolDesign.cardBorder,
      boxShadow: softShadow,
    ),
    child: Material(
      color: Colors.white,
      borderRadius: SchoolDesign.cardBorder,
      child: InkWell(
        borderRadius: SchoolDesign.cardBorder,
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: SchoolDesign.cardBorder,
            border: Border.all(color: line.withValues(alpha: .7)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  // Gradasi halus dari warna ikon agar tidak datar.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(item.color, Colors.white, .18)!,
                      item.color,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withValues(alpha: .25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: navy,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String schoolStatusLabel(Object? value) => value == null
    ? 'Belum diisi'
    : value
          .toString()
          .toLowerCase()
          .replaceAll('_', ' ')
          .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase());
Color schoolStatusColor(Object? value) =>
    switch (value?.toString().toUpperCase()) {
      'HADIR' ||
      'AKTIF' ||
      'DITERIMA' ||
      'DISETUJUI' ||
      'TERVERIFIKASI' ||
      'SELESAI' => schoolGreen,
      'TERLAMBAT' || 'MENUNGGU' || 'PERLU_REVISI' => schoolOrange,
      'ALFA' || 'DITOLAK' || 'DIBATALKAN' => schoolRed,
      'IZIN' || 'DIBUKA' => schoolBlue,
      'SAKIT' => schoolPurple,
      _ => muted,
    };

class SchoolStatus extends StatelessWidget {
  const SchoolStatus(
    this.value, {
    super.key,
    this.label,
    this.color,
    this.icon,
  });
  final Object? value;
  final String? label;
  final Color? color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final ink = color ?? schoolStatusColor(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label ?? schoolStatusLabel(value),
              style: TextStyle(
                fontSize: 12,
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared dialog header, surface and actions; domain-specific content stays with its screen.
class SchoolDialog extends StatelessWidget {
  const SchoolDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.icon,
    this.scrollable = true,
  });
  final Widget? title, content, icon;
  final List<Widget>? actions;
  final bool scrollable;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: scrollable,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    icon: icon,
    title: title == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SIM KESISWAAN',
                style: TextStyle(
                  color: schoolBlue,
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              DefaultTextStyle(
                style: const TextStyle(
                  color: navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
                child: title!,
              ),
            ],
          ),
    content: content,
    actions: actions,
    actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
    titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
    contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
  );
}

class SchoolEmpty extends StatelessWidget {
  const SchoolEmpty(
    this.message, {
    super.key,
    this.icon = Icons.inbox_outlined,
    this.onRetry,
  });
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => SchoolCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: schoolBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: schoolBlue),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Solid context header for feature pages, sharing the application's typography and spacing.
class SchoolContextHeader extends StatelessWidget {
  const SchoolContextHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: SchoolBrandPanel(
      radius: 16,
      watermark: false,
      padding: const EdgeInsets.all(SchoolDesign.pageInset),
      child: _content(context),
    ),
  );

  Widget _content(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              color: Color(0xFFD9E9FA),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
        if (trailing != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(SchoolDesign.controlRadius),
            ),
            child: trailing!,
          ),
        ],
      ],
  );
}

InputDecoration schoolInputDecoration({
  String? hint,
  String? errorText,
  Widget? prefixIcon,
}) => InputDecoration(
  hintText: hint,
  errorText: errorText,
  prefixIcon: prefixIcon,
);

class SchoolLoading extends StatelessWidget {
  const SchoolLoading({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Memuat data',
    child: const Center(child: CircularProgressIndicator()),
  );
}

class SchoolPageTitle extends StatelessWidget {
  const SchoolPageTitle({
    super.key,
    required this.title,
    this.accent = schoolBlue,
    this.showMark = true,
  });
  final String title;
  final Color accent;
  final bool showMark;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (showMark) ...[
        const SchoolLogo(size: 38),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SMAN 12 PADANG',
              style: TextStyle(fontSize: 11, color: accent, letterSpacing: .6),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
}

/// The caller decides whether to close its form after the success dialog is acknowledged.
Future<bool> showSchoolSuccess(
  BuildContext context, {
  required Widget title,
  required Widget content,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => SchoolDialog(
        icon: const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFE6F4EC),
          child: Icon(Icons.check_rounded, color: schoolGreen, size: 34),
        ),
        title: title,
        content: content,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Kembali'),
          ),
        ],
      ),
    ) ==
    true;
