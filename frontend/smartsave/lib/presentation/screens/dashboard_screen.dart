import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_util.dart';
import '../../presentation/providers/transaction_provider.dart';
import '../../presentation/providers/analytics_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/notification_provider.dart';
import '../../presentation/providers/subscription_provider.dart';
import '../../presentation/providers/xp_provider.dart';
import '../../data/models/transaction_model.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/fintech/payment_method_badge.dart';
import '../../app/routes.dart';
import '../../app/app.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with RouteAware {
  /// Tracks the last known auth session ID to detect when the user changes.
  /// When the session changes (e.g., switching Google accounts), all
  /// dashboard providers must clear their stale data before reloading.
  int _lastSessionId = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboardData());
  }

  /// Loads all dashboard data providers.
  /// Called on first mount and whenever the auth session changes.
  void _loadDashboardData() {
    context.read<TransactionProvider>().loadDashboard();
    context.read<AnalyticsProvider>().loadDashboard();
    context.read<NotificationProvider>().loadNotifications();
    context.read<SubscriptionProvider>().loadAll();
    context.read<XpProvider>().load();
  }

  /// Resets all dashboard providers to their initial empty state.
  /// Called when the auth session changes to prevent data leakage
  /// between user accounts (e.g., signing in with a different Google account).
  void _resetDashboardProviders() {
    context.read<TransactionProvider>().resetState();
    context.read<AnalyticsProvider>().resetState();
    context.read<NotificationProvider>().resetState();
    context.read<SubscriptionProvider>().resetState();
    context.read<XpProvider>().resetState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    context.read<NotificationProvider>().loadNotifications();
    context.read<TransactionProvider>().loadDashboard();
    context.read<AnalyticsProvider>().loadDashboard();
    context.read<SubscriptionProvider>().loadAll();
    context.read<XpProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final analyticsProvider = context.watch<AnalyticsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final subProvider = context.watch<SubscriptionProvider>();
    final xpProvider = context.watch<XpProvider>();

    // ── Auth session change detection ──
    // When the authenticated user changes (e.g., switching Google accounts,
    // logging out and logging in as a different user), all dashboard
    // providers must clear their stale data and reload.
    if (authProvider.sessionId != _lastSessionId) {
      final newSessionId = authProvider.sessionId;
      final oldSessionId = _lastSessionId;
      _lastSessionId = newSessionId;
      // Schedule reset + reload after this build frame to avoid
      // calling notifyListeners() during build().
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (oldSessionId >= 0) {
          // Only reset if this is a real session change (not the first load)
          _resetDashboardProviders();
        }
        _loadDashboardData();
      });
    }
    final dashboard = txProvider.dashboardData;
    final currencyFormat = CurrencyUtil.getFormat(authProvider.user?.currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upcomingSubs = subProvider.upcoming;
    final levelProgress = xpProvider.progress;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await txProvider.loadDashboard();
            await analyticsProvider.loadDashboard();
            await subProvider.loadAll();
            await xpProvider.load();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInDown(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Hello!', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.grey500)),
                    Text(authProvider.user?.name ?? 'Smart Saver', style: Theme.of(context).textTheme.headlineSmall),
                  ]),
                  Row(children: [
                    Stack(children: [
                      IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.grey600), onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications)),
                      if (notifProvider.unreadCount > 0)
                        Positioned(right: 6, top: 6, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                          child: Text('${notifProvider.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                        ),
                    ]),
                    IconButton(icon: const Icon(Icons.settings_outlined, color: AppColors.grey600), onPressed: () => Navigator.pushNamed(context, AppRoutes.settings)),
                    GestureDetector(onTap: () => Navigator.pushNamed(context, AppRoutes.profile), child: CircleAvatar(radius: 16, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: const Icon(Icons.person, size: 18, color: AppColors.primary))),
                  ]),
                ])),
                const SizedBox(height: 20),

                // Balance Card
                FadeInUp(delay: const Duration(milliseconds: 100), child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Current Balance', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(currencyFormat.format(dashboard?.balance ?? 0), style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(children: [
                      _buildStatChip(Icons.arrow_upward, 'Income', currencyFormat.format(dashboard?.monthlyIncome ?? 0), AppColors.success),
                      const SizedBox(width: 12),
                      _buildStatChip(Icons.arrow_downward, 'Expenses', currencyFormat.format(dashboard?.monthlyExpenses ?? 0), AppColors.danger),
                    ]),
                  ]),
                )),
                const SizedBox(height: 20),

                // Stats Row
                FadeInUp(delay: const Duration(milliseconds: 200), child: Row(children: [
                  Expanded(child: _buildStatCard('Savings', currencyFormat.format(dashboard?.savings ?? 0), Icons.savings_outlined, AppColors.success)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('Budget Left', currencyFormat.format(dashboard?.remainingBudget ?? 0), Icons.account_balance_wallet_outlined, AppColors.warning)),
                ])),
                const SizedBox(height: 24),

                // Quick Actions Row 1
                FadeInUp(delay: const Duration(milliseconds: 250), child: Row(children: [
                  Expanded(child: _buildQuickAction(context, Icons.trending_down, 'Add Expense', AppColors.danger, () => Navigator.pushNamed(context, AppRoutes.addExpense))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildQuickAction(context, Icons.trending_up, 'Add Income', AppColors.success, () => Navigator.pushNamed(context, AppRoutes.addIncome))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildQuickAction(context, Icons.flash_on_rounded, 'Quick Add', AppColors.warning, () => Navigator.pushNamed(context, AppRoutes.quickAdd))),
                ])),
                const SizedBox(height: 12),

                // Quick Actions Row 2
                FadeInUp(delay: const Duration(milliseconds: 260), child: Row(children: [
                  Expanded(child: _buildQuickAction(context, Icons.calendar_month_rounded, 'Calendar', AppColors.primary, () => Navigator.pushNamed(context, AppRoutes.calendar))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildQuickAction(context, Icons.subscriptions_rounded, 'Subscriptions', AppColors.secondary, () => Navigator.pushNamed(context, AppRoutes.subscriptions))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildQuickAction(context, Icons.account_balance_rounded, 'Net Worth', const Color(0xFF8B5CF6), () => Navigator.pushNamed(context, AppRoutes.netWorth))),
                ])),
                const SizedBox(height: 12),

                // Quick Actions Row 3
                FadeInUp(delay: const Duration(milliseconds: 270), child: Row(children: [
                  Expanded(child: _buildQuickAction(context, Icons.savings_outlined, 'Savings Goals', AppColors.success, () => Navigator.pushNamed(context, AppRoutes.goals))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildQuickAction(context, Icons.analytics_outlined, 'Analytics', AppColors.secondary, () => Navigator.pushNamed(context, AppRoutes.analytics))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildQuickAction(context, Icons.emoji_events_rounded, 'Challenges', AppColors.warning, () => Navigator.pushNamed(context, AppRoutes.gamification))),
                ])),
                const SizedBox(height: 12),

                // Quick Actions Row 4 — Financial Advisor
                FadeInUp(delay: const Duration(milliseconds: 275), child: Row(children: [
                  Expanded(child: _buildQuickAction(context, Icons.auto_awesome_rounded, 'AI Advisor', AppColors.primary, () => Navigator.pushNamed(context, AppRoutes.financialAdvisor))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildQuickAction(context, Icons.account_balance_wallet_rounded, 'Budgets', AppColors.success, () => Navigator.pushNamed(context, AppRoutes.budget))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildQuickAction(context, Icons.receipt_long_rounded, 'Reports', const Color(0xFF8B5CF6), () => Navigator.pushNamed(context, AppRoutes.report))),
                ])),
                const SizedBox(height: 24),

                // XP Level Progress Card
                FadeInUp(delay: const Duration(milliseconds: 280), child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.level),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
                    ),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.auto_awesome_rounded, color: AppColors.warning, size: 24)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text('Level ${xpProvider.level}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text(xpProvider.levelName, style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: levelProgress / 100, backgroundColor: AppColors.grey100, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning), minHeight: 6)),
                        const SizedBox(height: 4),
                        Text('${xpProvider.xp} / ${xpProvider.nextThreshold} XP', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey500)),
                      ])),
                      const Icon(Icons.chevron_right, color: AppColors.grey500),
                    ]),
                  ),
                )),
                const SizedBox(height: 16),

                const SizedBox(height: 16),

                // Upcoming Subscriptions
                if (upcomingSubs.isNotEmpty)
                  FadeInUp(delay: const Duration(milliseconds: 300), child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: isDark ? AppColors.darkCard : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Upcoming Subscriptions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.subscriptions), child: const Text('Manage')),
                      ]),
                      const SizedBox(height: 8),
                      ...upcomingSubs.take(3).map((sub) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.subscriptions_rounded, color: AppColors.secondary, size: 18)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(sub['name'] ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text('Next: ${_formatDate(sub['nextBillingDate'])}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey500)),
                          ])),
                          Text(currencyFormat.format((sub['amount'] ?? 0).toDouble()), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.danger)),
                        ]),
                      )),
                    ]),
                  )),
                if (upcomingSubs.isNotEmpty) const SizedBox(height: 16),

                // Net Worth Quick Snapshot - new section after subscriptions
                FadeInUp(delay: const Duration(milliseconds: 310), child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.netWorth),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: isDark ? AppColors.darkCard : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100)),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.account_balance_rounded, color: Color(0xFF8B5CF6), size: 22)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Net Worth', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.grey500)),
                        Text('Track assets & liabilities', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey500)),
                      ])),
                      const Icon(Icons.chevron_right, color: AppColors.grey500),
                    ]),
                  ),
                )),
                const SizedBox(height: 24),

                // Payment Method Spending
                if (dashboard != null && dashboard.paymentMethodBreakdown.isNotEmpty)
                  FadeInUp(delay: const Duration(milliseconds: 320), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Spending by Method', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ...dashboard.paymentMethodBreakdown.map((pm) {
                      final color = AppColors.paymentMethodColors[pm.paymentMethod] ?? AppColors.paymentOther;
                      final pct = dashboard.monthlyExpenses > 0 ? (pm.total / dashboard.monthlyExpenses * 100) : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Icon(AppConstants.paymentMethodIcons[pm.paymentMethod] ?? Icons.payment_rounded, size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(flex: 2, child: Text(pm.paymentMethod, style: Theme.of(context).textTheme.bodyMedium)),
                          Expanded(flex: 3, child: Column(children: [
                            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct / 100, backgroundColor: color.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6)),
                            const SizedBox(height: 2),
                            Text('${pct.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey500)),
                          ])),
                          const SizedBox(width: 12),
                          Text(currencyFormat.format(pm.total), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ]),
                      );
                    }),
                    const SizedBox(height: 16),
                  ])),

                // Recent Transactions
                FadeInUp(delay: const Duration(milliseconds: 330), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.transactions), child: const Text('See All')),
                ])),
                const SizedBox(height: 8),
                ..._buildRecentTransactions(context, txProvider.recentTransactions, currencyFormat, isDark: Theme.of(context).brightness == Brightness.dark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey100)),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
        ]),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 12),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }

  List<Widget> _buildRecentTransactions(BuildContext context, List<TransactionModel> transactions, NumberFormat format, {bool isDark = false}) {
    if (transactions.isEmpty) {
      return [FadeInUp(child: const EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions yet', subtitle: 'Tap + to add your first transaction'))];
    }

    return transactions.take(5).map((tx) => FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.transactionDetail, arguments: tx.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey100)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: tx.type == 'income' ? AppColors.successLight : AppColors.dangerLight, borderRadius: BorderRadius.circular(12)), child: Icon(_getCategoryIcon(tx.category), color: tx.type == 'income' ? AppColors.success : AppColors.danger, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(tx.category, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 6),
                PaymentMethodBadge(method: tx.paymentMethod),
              ]),
              if (tx.description.isNotEmpty) Text(tx.description, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${tx.type == 'income' ? '+' : '-'}${format.format(tx.amount)}', style: TextStyle(fontWeight: FontWeight.w600, color: tx.type == 'income' ? AppColors.success : AppColors.danger)),
              Text(DateFormat('MMM dd').format(tx.date), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
        ),
      ),
    )).toList();
  }

  IconData _getCategoryIcon(String category) {
    const icons = {
      'Food': Icons.restaurant, 'Transportation': Icons.directions_car, 'Shopping': Icons.shopping_cart,
      'Bills': Icons.receipt_long, 'Entertainment': Icons.movie, 'Health': Icons.local_hospital,
      'Education': Icons.school, 'Travel': Icons.flight, 'Salary': Icons.account_balance,
      'Freelance': Icons.computer, 'Investment': Icons.trending_up, 'Gift': Icons.card_giftcard,
      'Refund': Icons.undo, 'Other': Icons.category,
    };
    return icons[category] ?? Icons.receipt;
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      return DateFormat('MMM dd').format(DateTime.parse(date.toString()));
    } catch (_) {
      return 'N/A';
    }
  }
}
