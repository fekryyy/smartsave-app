import 'package:flutter/material.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/register_screen.dart';
import '../presentation/screens/forgot_password_screen.dart';
import '../presentation/screens/dashboard_screen.dart';
import '../presentation/screens/add_expense_screen.dart';
import '../presentation/screens/add_income_screen.dart';
import '../presentation/screens/analytics_screen.dart';
import '../presentation/screens/goals_screen.dart';
import '../presentation/screens/goal_detail_screen.dart';
import '../presentation/screens/budget_screen.dart';
import '../presentation/screens/profile_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../presentation/screens/notifications_screen.dart';
import '../presentation/screens/onboarding_screen.dart';
import '../presentation/screens/transactions_screen.dart';
import '../presentation/screens/transaction_detail_screen.dart';
import '../presentation/screens/gamification_screen.dart';
import '../presentation/screens/calendar_screen.dart';
import '../presentation/screens/subscriptions_screen.dart';
import '../presentation/screens/net_worth_screen.dart';
import '../presentation/screens/auto_save_screen.dart';
import '../presentation/screens/report_screen.dart';
import '../presentation/screens/heatmap_screen.dart';
import '../presentation/screens/level_screen.dart';
import '../presentation/screens/quick_add_screen.dart';
import '../presentation/screens/financial_advisor_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String addExpense = '/add-expense';
  static const String addIncome = '/add-income';
  static const String analytics = '/analytics';
  static const String goals = '/goals';
  static const String goalDetail = '/goal-detail';
  static const String budget = '/budget';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String transactions = '/transactions';
  static const String notifications = '/notifications';
  static const String transactionDetail = '/transaction-detail';
  static const String onboarding = '/onboarding';
  static const String gamification = '/gamification';
  static const String calendar = '/calendar';
  static const String subscriptions = '/subscriptions';
  static const String netWorth = '/net-worth';
  static const String autoSave = '/auto-save';
  static const String report = '/report';
  static const String heatmap = '/heatmap';
  static const String level = '/level';
  static const String quickAdd = '/quick-add';
  static const String financialAdvisor = '/financial-advisor';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case addExpense:
        return MaterialPageRoute(builder: (_) => const AddExpenseScreen());
      case addIncome:
        return MaterialPageRoute(builder: (_) => const AddIncomeScreen());
      case analytics:
        return MaterialPageRoute(builder: (_) => const AnalyticsScreen());
      case goals:
        return MaterialPageRoute(builder: (_) => const GoalsScreen());
      case goalDetail:
        final goalId = routeSettings.arguments as String?;
        return MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goalId ?? ''));
      case budget:
        return MaterialPageRoute(builder: (_) => const BudgetScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case transactions:
        return MaterialPageRoute(builder: (_) => const TransactionsScreen());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case transactionDetail:
        final txId = routeSettings.arguments as String?;
        return MaterialPageRoute(builder: (_) => TransactionDetailScreen(transactionId: txId ?? ''));
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case gamification:
        return MaterialPageRoute(builder: (_) => const GamificationScreen());
      case calendar:
        return MaterialPageRoute(builder: (_) => const CalendarScreen());
      case subscriptions:
        return MaterialPageRoute(builder: (_) => const SubscriptionsScreen());
      case netWorth:
        return MaterialPageRoute(builder: (_) => const NetWorthScreen());
      case autoSave:
        return MaterialPageRoute(builder: (_) => const AutoSaveScreen());
      case report:
        final mode = routeSettings.arguments as String?;
        return MaterialPageRoute(builder: (_) => ReportScreen(mode: mode));
      case heatmap:
        return MaterialPageRoute(builder: (_) => const HeatmapScreen());
      case level:
        return MaterialPageRoute(builder: (_) => const LevelScreen());
      case quickAdd:
        return MaterialPageRoute(builder: (_) => const QuickAddScreen());
      case financialAdvisor:
        return MaterialPageRoute(builder: (_) => const FinancialAdvisorScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
