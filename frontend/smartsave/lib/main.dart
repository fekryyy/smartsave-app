import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/app.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/transaction_provider.dart';
import 'presentation/providers/budget_provider.dart';
import 'presentation/providers/goal_provider.dart';
import 'presentation/providers/analytics_provider.dart';
import 'presentation/providers/notification_provider.dart';
import 'presentation/providers/recurring_provider.dart';
import 'presentation/providers/challenge_provider.dart';
import 'presentation/providers/subscription_provider.dart';
import 'presentation/providers/net_worth_provider.dart';
import 'presentation/providers/auto_save_provider.dart';
import 'presentation/providers/calendar_provider.dart';
import 'presentation/providers/report_provider.dart';
import 'presentation/providers/xp_provider.dart';
import 'presentation/providers/financial_advisor_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'data/datasources/local/local_database.dart';
import 'services/cache_manager.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };
  try {
    await LocalDatabase.instance.database;
    await CacheManager().init();
    SyncService().start();
  } catch (_) {
    // Local DB not available (e.g., on web) - continue without offline support
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => RecurringProvider()),
        ChangeNotifierProvider(create: (_) => ChallengeProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => NetWorthProvider()),
        ChangeNotifierProvider(create: (_) => AutoSaveProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => XpProvider()),
        ChangeNotifierProvider(create: (_) => FinancialAdvisorProvider()),
      ],
      child: const SmartSaveApp(),
    ),
  );
}
