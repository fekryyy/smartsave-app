import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? trend;

  const MetricCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: iconColor)),
          if (trend != null) ...[
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (trend!.startsWith('+') ? AppColors.success : AppColors.danger).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(trend!.startsWith('+') ? Icons.arrow_upward : Icons.arrow_downward, size: 10, color: trend!.startsWith('+') ? AppColors.success : AppColors.danger),
                const SizedBox(width: 2),
                Text(trend!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: trend!.startsWith('+') ? AppColors.success : AppColors.danger)),
              ])),
          ],
        ]),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey500 : AppColors.grey400)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
      ]),
    );
  }
}
