import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'SmartSave';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Personal Finance & Savings Application';

  static const List<String> expenseCategories = [
    'Food', 'Transportation', 'Shopping', 'Bills',
    'Entertainment', 'Health', 'Education', 'Travel', 'Other',
  ];

  static const List<String> incomeSources = [
    'Salary', 'Freelance', 'Investment', 'Gift', 'Refund', 'Other',
  ];

  static const List<String> paymentMethods = [
    'Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'Mobile Wallet', 'Other',
  ];

  static const List<String> currencies = ['USD', 'EUR', 'GBP', 'EGP', 'SAR', 'AED'];

  static const List<String> goalCategories = [
    'Emergency Fund', 'Travel', 'Education', 'Shopping',
    'Investment', 'Debt Payment', 'Retirement', 'Other',
  ];

  static const Map<String, int> categoryIcons = {
    'Food': 0xe56c,
    'Transportation': 0xe531,
    'Shopping': 0xe8cc,
    'Bills': 0xef72,
    'Entertainment': 0xe404,
    'Health': 0xe550,
    'Education': 0xe80c,
    'Travel': 0xe539,
    'Other': 0xe5c8,
    'Salary': 0xe84f,
    'Freelance': 0xe30a,
    'Investment': 0xe9e5,
    'Gift': 0xe8f6,
    'Refund': 0xe166,
  };

  static const Map<String, IconData> paymentMethodIcons = {
    'Cash': Icons.money_rounded,
    'Credit Card': Icons.credit_card_rounded,
    'Debit Card': Icons.credit_score_rounded,
    'Bank Transfer': Icons.account_balance_rounded,
    'Mobile Wallet': Icons.phone_android_rounded,
    'Other': Icons.payment_rounded,
  };

  static const Map<String, int> categoryColors = {
    'Food': 0xFFFF6B6B,
    'Transportation': 0xFF4ECDC4,
    'Shopping': 0xFFFFB347,
    'Bills': 0xFFA8E6CF,
    'Entertainment': 0xFFDDA0DD,
    'Health': 0xFF98D8C8,
    'Education': 0xFFF7DC6F,
    'Travel': 0xFFBB8FCE,
    'Other': 0xFF85C1E9,
  };
}
