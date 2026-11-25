import '../../../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../../../widgets/design_tokens.dart';

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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
  return schoolInputDecoration(
    hint: hint,
    errorText: errorText,
    prefixIcon: prefixIcon,
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
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: SchoolDesign.touchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
