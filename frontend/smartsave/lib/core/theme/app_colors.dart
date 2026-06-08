import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF3730A3);

  // Secondary
  static const Color secondary = Color(0xFF06B6D4);
  static const Color secondaryLight = Color(0xFF67E8F9);
  static const Color secondaryDark = Color(0xFF0891B2);

  // Success / Income
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFA7F3D0);
  static const Color successDark = Color(0xFF059669);

  // Danger / Expense
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFECACA);
  static const Color dangerDark = Color(0xFFDC2626);

  // Warning
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFDE68A);

  // Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // Dark mode (new premium fintech palette)
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF172033);
  static const Color darkCardAlt = Color(0xFF1E293B);
  static const Color darkBorder = Color(0x14FFFFFF);

  // Payment method identity colors
  static const Color paymentCash = Color(0xFF10B981);
  static const Color paymentCredit = Color(0xFF3B82F6);
  static const Color paymentDebit = Color(0xFF8B5CF6);
  static const Color paymentBank = Color(0xFFF59E0B);
  static const Color paymentWallet = Color(0xFF06B6D4);
  static const Color paymentOther = Color(0xFF6B7280);

  static const Map<String, Color> paymentMethodColors = {
    'Cash': paymentCash,
    'Credit Card': paymentCredit,
    'Debit Card': paymentDebit,
    'Bank Transfer': paymentBank,
    'Mobile Wallet': paymentWallet,
    'Other': paymentOther,
  };

  // Glass
  static Color glassLight = Colors.white.withOpacity(0.06);
  static Color glassMedium = Colors.white.withOpacity(0.10);
  static Color glassBorder = Colors.white.withOpacity(0.12);

  // Chart colors
  static const List<Color> chartColors = [
    Color(0xFF4F46E5),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  static const List<Color> categoryChartColors = [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFB347),
    Color(0xFFA8E6CF),
    Color(0xFFDDA0DD),
    Color(0xFF98D8C8),
    Color(0xFFF7DC6F),
    Color(0xFFBB8FCE),
    Color(0xFF85C1E9),
  ];

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
