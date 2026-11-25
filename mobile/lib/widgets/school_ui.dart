import 'package:flutter/material.dart';
import '../theme.dart';
import 'design_tokens.dart';

const schoolBlue = Color(0xFF2768B2);
const schoolGreen = Color(0xFF1E7D4F);
const schoolOrange = Color(0xFFB26A00);
const schoolPurple = Color(0xFF6A4BB2);
const schoolRed = Color(0xFFC62828);
const schoolAccents = [schoolBlue, schoolOrange, schoolPurple, schoolGreen];

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
      border: Border.all(color: color == Colors.white ? line : color),
    ),
    child: child,
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
  });
  final String name;
  final GreetingInfo first, second;
  final DateTime? date;
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: .22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -30, top: -30, child: _circle(130, .08)),
          Positioned(right: 40, bottom: -40, child: _circle(90, .06)),
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
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
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
                              _stat(first),
                              const SizedBox(height: 10),
                              _stat(second),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: _stat(first)),
                              const SizedBox(width: 10),
                              Expanded(child: _stat(second)),
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

  Widget _circle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
  Widget _stat(GreetingInfo info) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(12),
    ),
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
  Widget _tile(SchoolMenuItem item) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 104),
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
            border: Border.all(color: item.color.withValues(alpha: .25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: item.color,
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
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(SchoolDesign.pageInset),
    decoration: const BoxDecoration(
      color: navy,
      borderRadius: SchoolDesign.cardBorder,
    ),
    child: Column(
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
    ),
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
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(SchoolDesign.controlRadius),
          ),
          child: const Icon(
            Icons.school_outlined,
            size: 21,
            color: Colors.white,
          ),
        ),
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
              maxLines: 2,
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
