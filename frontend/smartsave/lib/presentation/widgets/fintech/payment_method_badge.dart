import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class PaymentMethodBadge extends StatelessWidget {
  final String method;
  final double iconSize;
  final double fontSize;
  final bool showIcon;

  const PaymentMethodBadge({
    super.key,
    required this.method,
    this.iconSize = 12,
    this.fontSize = 10,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.paymentMethodColors[method] ?? AppColors.paymentOther;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(AppConstants.paymentMethodIcons[method] ?? Icons.payment_rounded, size: iconSize, color: color),
            const SizedBox(width: 4),
          ],
          Text(method, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
