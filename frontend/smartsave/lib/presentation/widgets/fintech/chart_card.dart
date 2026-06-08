import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AnalyticsChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double height;
  final Widget? trailing;

  const AnalyticsChartCard({
    super.key,
    required this.title,
    required this.child,
    this.height = 220,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 16),
        SizedBox(height: height, child: child),
      ]),
    );
  }
}
