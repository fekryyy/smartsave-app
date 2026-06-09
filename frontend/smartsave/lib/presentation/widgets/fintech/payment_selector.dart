import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PaymentMethodSelector extends StatelessWidget {
  final List<String> methods;
  final String selected;
  final ValueChanged<String> onChanged;
  final IconData Function(String) iconBuilder;

  const PaymentMethodSelector({
    super.key,
    required this.methods,
    required this.selected,
    required this.onChanged,
    required this.iconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardAlt : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: methods.map((m) {
            final isSelected = selected == m;
            final color = AppColors.paymentMethodColors[m] ?? AppColors.paymentOther;
            return GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: isDark ? 0.2 : 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  border: isSelected ? Border.all(color: color.withValues(alpha: 0.5)) : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(iconBuilder(m), size: 15, color: isSelected ? color : (isDark ? AppColors.grey400 : const Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  Text(m, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? color : (isDark ? AppColors.grey400 : const Color(0xFF475569)))),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle_rounded, size: 14, color: color),
                  ],
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
