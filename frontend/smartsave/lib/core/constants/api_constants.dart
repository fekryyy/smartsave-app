import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class ApiConstants {
  /// Android emulator uses 10.0.2.2 to reach the host machine.
  /// All other platforms (iOS simulator, macOS, web, real devices) use localhost
  /// when the backend runs on the same machine during development.
  static String get _host {
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return 'localhost';
  }

  static String get baseUrl => 'http://$_host:5001/api';
  static String get socketUrl => 'http://$_host:5001';

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String googleLogin = '/auth/google';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String refreshToken = '/auth/refresh-token';
  static const String profile = '/auth/profile';
  static const String changePassword = '/auth/change-password';

  // Transaction endpoints
  static const String transactions = '/transactions';
  static const String recentTransactions = '/transactions/recent';

  // Budget endpoints
  static const String budgets = '/budgets';
  static const String budgetOverview = '/budgets/overview';

  // Goal endpoints
  static const String goals = '/goals';
  static const String goalProgress = '/goals/progress';

  // Analytics endpoints
  static const String dashboard = '/analytics/dashboard';
  static const String categoryBreakdown = '/analytics/category-breakdown';
  static const String monthlyTrend = '/analytics/monthly-trend';
  static const String incomeVsExpenses = '/analytics/income-vs-expenses';
  static const String savingsGrowth = '/analytics/savings-growth';
  static const String report = '/analytics/report';

  // Export endpoints
  static const String exportPdf = '/export/pdf';
  static const String exportCsv = '/export/csv';
  static const String exportExcel = '/export/excel';

  // Recommendations
  static const String recommendations = '/recommendations';

  // OCR
  static const String ocrScan = '/ocr/scan';

  // Notifications
  static const String notifications = '/notifications';

  // Recurring Transactions
  static const String recurringTransactions = '/recurring';

  // Financial Advisor
  static const String financialAdvisorAnalysis = '/financial-advisor/analysis';
  static const String financialAdvisorScore = '/financial-advisor/score';
  static const String financialAdvisorInsights = '/financial-advisor/insights';
  static const String financialAdvisorActionPlan = '/financial-advisor/action-plan';
  static const String financialAdvisorPredictions = '/financial-advisor/predictions';
  static const String financialAdvisorAsk = '/financial-advisor/ask';

  // Profile
  static const String profileStats = '/profile/stats';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
