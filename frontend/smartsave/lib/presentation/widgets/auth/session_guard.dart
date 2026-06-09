import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/net_worth_provider.dart';
import '../../providers/auto_save_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/xp_provider.dart';
import '../../providers/financial_advisor_provider.dart';
import '../../../services/cache_manager.dart';
import '../../../data/datasources/local/local_database.dart';

/// Watches for auth session changes and clears all provider state + caches
/// when the authenticated user changes.
///
/// This is the central defense against data leakage between user sessions.
/// Place this widget as a parent of the main app content (inside the
/// [MultiProvider] tree) so it has access to all providers via [context].
///
/// When [AuthProvider.sessionId] changes:
/// 1. All provider state is reset to initial values (via `resetState()`)
/// 2. All SQLite caches (CacheManager + LocalDatabase pending operations)
///    are cleared
/// 3. Each screen is responsible for reloading its own data (which it does
///    in its `initState` or `build` method via sessionId detection)
///
/// This prevents a logged-in user from seeing stale data from the previous
/// user's session in any provider.
class SessionGuard extends StatefulWidget {
  final Widget child;

  const SessionGuard({required this.child, super.key});

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  /// Tracks the last known auth session ID.
  /// When this differs from [AuthProvider.sessionId], the user has changed
  /// and all providers must be reset.
  int _lastSessionId = -1;

  /// Resets all user-scoped providers to their initial empty state.
  ///
  /// Every provider that holds user-specific data must be listed here.
  /// If a new provider is added, it must be added to this method and to
  /// [MultiProvider] in `main.dart`.
  void _resetAllProviders() {
    context.read<TransactionProvider>().resetState();
    context.read<AnalyticsProvider>().resetState();
    context.read<BudgetProvider>().resetState();
    context.read<GoalProvider>().resetState();
    context.read<NotificationProvider>().resetState();
    context.read<RecurringProvider>().resetState();
    context.read<ChallengeProvider>().resetState();
    context.read<SubscriptionProvider>().resetState();
    context.read<NetWorthProvider>().resetState();
    context.read<AutoSaveProvider>().resetState();
    context.read<CalendarProvider>().resetState();
    context.read<ReportProvider>().resetState();
    context.read<XpProvider>().resetState();
    context.read<FinancialAdvisorProvider>().resetState();
    // NOTE: ThemeProvider is intentionally excluded — it holds a device-level
    // preference (light/dark mode), not user-specific data.
  }

  /// Clears all local caches so stale data from the previous user is not
  /// served after a session change.
  Future<void> _clearAllCaches() async {
    try {
      await CacheManager().invalidateAll();
    } catch (_) {
      // Cache invalidation is non-critical
    }
    try {
      // Clear all user-scoped local tables (transactions, goals, budgets,
      // pending_operations) — not just pending_operations.
      await LocalDatabase.instance.clearAllUserData();
    } catch (_) {
      // Local DB clear is non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.sessionId != _lastSessionId) {
      final newSessionId = authProvider.sessionId;
      final oldSessionId = _lastSessionId;
      _lastSessionId = newSessionId;

      // Schedule reset + cache clear after this build frame to avoid calling
      // notifyListeners() during build().
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (oldSessionId >= 0) {
          // Only reset if this is a real session change (not the first load
          // where oldSessionId is -1). This avoids clearing providers before
          // the initial data loads.
          _resetAllProviders();
          _clearAllCaches();
        }
      });
    }

    return widget.child;
  }
}
