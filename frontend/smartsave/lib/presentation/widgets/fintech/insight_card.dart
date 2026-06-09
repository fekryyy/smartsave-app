import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class InsightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;
  final VoidCallback? onTap;

  const InsightCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: iconColor)),
          const SizedBox(width: 14),
          Expanded(child: Text(message, style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? AppColors.grey300 : const Color(0xFF475569)))),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? AppColors.grey500 : AppColors.grey400),
        ]),
      ),
    );
  }
}
