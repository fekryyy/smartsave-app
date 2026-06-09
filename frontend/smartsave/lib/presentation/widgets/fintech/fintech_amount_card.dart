import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class FintechAmountCard extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String prefix;
  final String? Function(String?)? validator;

  const FintechAmountCard({
    super.key,
    required this.controller,
    required this.label,
    required this.prefix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintCol = isDark ? AppColors.grey500 : const Color(0xFF94A3B8);
    final sectionCol = isDark ? AppColors.grey400 : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: sectionCol)),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(prefix, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: hintCol))),
          const SizedBox(width: 4),
          SizedBox(
            width: 200,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: textCol, letterSpacing: -1),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: hintCol.withValues(alpha: 0.2), letterSpacing: -1),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              validator: validator,
            ),
          ),
        ]),
      ]),
    );
  }
}
