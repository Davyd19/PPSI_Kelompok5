import 'package:flutter/material.dart';

import '../../../theme.dart';

/// Label kolom yang diletakkan rapi di atas kotak input.
class KasusFieldLabel extends StatelessWidget {
  const KasusFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final isRequired = text.endsWith('*');
    final base = isRequired
        ? text.substring(0, text.length - 1).trimRight()
        : text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: base,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: navy,
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFC62828)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dekorasi input seragam dan rapi tanpa floating label yang keluar dari kotak.
InputDecoration kasusInputDecoration({
  required String hint,
  String? errorText,
  Widget? prefixIcon,
}) {
  final radius = BorderRadius.circular(10);
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: muted),
    errorText: errorText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: const Color(0xFFF3F6FC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: Color(0xFFDCE6F3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: Color(0xFFDCE6F3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: navy, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: Color(0xFFC62828)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: Color(0xFFC62828), width: 1.4),
    ),
  );
}

/// Tombol pemilih tanggal yang jelas dan responsif saat ditekan.
class KasusDatePickerField extends StatelessWidget {
  const KasusDatePickerField({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      KasusFieldLabel(label),
      Material(
        color: const Color(0xFFF3F6FC),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDCE6F3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 19,
                  color: navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    valueText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: navy,
                    ),
                  ),
                ),
                const Text(
                  'Ubah',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: blue,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: blue),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
