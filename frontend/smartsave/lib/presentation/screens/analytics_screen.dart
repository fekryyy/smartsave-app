import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_util.dart';
import '../../presentation/providers/analytics_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../data/models/analytics_model.dart';
import '../widgets/fintech/health_card.dart';
import '../widgets/fintech/metric_card.dart';
import '../widgets/fintech/insight_card.dart';
import '../widgets/fintech/chart_card.dart';
import '../../services/download_service.dart';
import '../../app/routes.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsProvider>().loadAllAnalytics();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<AnalyticsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final format = CurrencyUtil.getFormat(authProvider.user?.currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => analytics.loadAllAnalytics()),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_rounded),
            onSelected: (v) async {
              try {
                if (v == 'pdf') await DownloadService().exportPDF();
                else if (v == 'csv') await DownloadService().exportCSV();
                else if (v == 'excel') await DownloadService().exportExcel();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report exported')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, size: 18), SizedBox(width: 8), Text('Export PDF')])),
              PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.table_chart, size: 18), SizedBox(width: 8), Text('Export CSV')])),
              PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.grid_on, size: 18), SizedBox(width: 8), Text('Export Excel')])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCardAlt : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(11),
                boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
              unselectedLabelColor: isDark ? AppColors.grey500 : AppColors.grey400,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [Tab(text: 'Overview'), Tab(text: 'Reports'), Tab(text: 'Trends')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverview(context, analytics, format, isDark),
                _buildReports(context, analytics, format, isDark),
                _buildTrends(context, analytics, format, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === OVERVIEW TAB ===
  Widget _buildOverview(BuildContext context, AnalyticsProvider analytics, NumberFormat format, bool isDark) {
    if (analytics.isLoading) return const Center(child: CircularProgressIndicator());

    final income = (analytics.incomeVsExpenses?['income']?['total'] ?? 0).toDouble();
    final expenses = (analytics.incomeVsExpenses?['expenses']?['total'] ?? 0).toDouble();
    final goalSavings = analytics.dashboardData?.savings ?? 0;
    final balance = analytics.dashboardData?.balance ?? (income - expenses);
    final savingsRate = income > 0 ? ((goalSavings / income) * 100).toStringAsFixed(0) : null;

    final healthScore = _calcHealthScore(analytics);
    final healthStatus = _healthStatus(healthScore);
    final healthTrend = _healthTrend(analytics);

    final Map<String, dynamic> metrics = {
      'Income': {'value': income, 'icon': Icons.trending_up_rounded, 'color': AppColors.success},
      'Expenses': {'value': expenses, 'icon': Icons.trending_down_rounded, 'color': AppColors.danger},
      'Savings': {'value': goalSavings, 'icon': Icons.savings_rounded, 'color': AppColors.secondary},
      'Balance': {'value': balance, 'icon': Icons.account_balance_wallet_rounded, 'color': AppColors.primary},
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Financial Health
        FinancialHealthCard(
          scoreLabel: 'Financial Health',
          score: healthScore,
          status: healthStatus,
          trend: healthTrend,
        ),
        const SizedBox(height: 20),

        // Metrics Grid
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics.entries.map((e) {
            final v = e.value;
            final mVal = v['value'] as double;
            final isExpense = e.key == 'Expenses';
            final pct = income > 0 ? ((mVal / income) * 100).toStringAsFixed(0) : null;
            String? trendStr;
            if (e.key == 'Income' && pct != null) {
              trendStr = '+$pct%';
            } else if (isExpense && pct != null) {
              trendStr = '+$pct%';
            } else if (e.key == 'Savings' && goalSavings > 0 && savingsRate != null) {
              trendStr = '$savingsRate%';
            }
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 52) / 2,
              child: MetricCard(
                icon: v['icon'] as IconData,
                iconColor: v['color'] as Color,
                label: e.key,
                value: format.format(mVal),
                trend: trendStr != null && trendStr != '+0%' ? (isExpense ? '+$pct%' : trendStr) : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Monthly Trend
        AnalyticsChartCard(
          title: 'Income vs Expenses',
          height: 220,
          trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('Inc', style: TextStyle(fontSize: 10, color: isDark ? AppColors.grey400 : AppColors.grey500)),
              const SizedBox(width: 8),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('Exp', style: TextStyle(fontSize: 10, color: isDark ? AppColors.grey400 : AppColors.grey500)),
            ])),
          child: analytics.monthlyTrend.isEmpty
              ? const Center(child: Text('No trend data'))
              : _buildTrendChart(analytics.monthlyTrend),
        ),
        const SizedBox(height: 20),

        // Category Breakdown
        AnalyticsChartCard(
          title: 'Spending by Category',
          height: analytics.categoryBreakdown.isEmpty ? 100 : 200,
          child: analytics.categoryBreakdown.isEmpty
              ? const Center(child: Text('No data yet'))
              : _buildCategoryChart(analytics.categoryBreakdown, format, isDark),
        ),
        if (analytics.categoryBreakdown.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCategoryLegend(analytics.categoryBreakdown, format, isDark),
        ],
        const SizedBox(height: 20),

        // Payment Method Breakdown
        if (analytics.dashboardData?.paymentMethodBreakdown != null && analytics.dashboardData!.paymentMethodBreakdown.isNotEmpty)
          AnalyticsChartCard(
            title: 'Spending by Method',
            height: analytics.dashboardData!.paymentMethodBreakdown.length * 48.0 + 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: analytics.dashboardData!.paymentMethodBreakdown.map((pm) {
                final color = AppColors.paymentMethodColors[pm.paymentMethod] ?? AppColors.paymentOther;
                final totalExpenses = metrics['Expenses']?['value'] as double? ?? 0;
                final pct = totalExpenses > 0 ? (pm.total / totalExpenses * 100) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Icon(AppConstants.paymentMethodIcons[pm.paymentMethod] ?? Icons.payment_rounded, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: Text(pm.paymentMethod, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)))),
                    Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct / 100, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 5)),
                      Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: isDark ? AppColors.grey500 : AppColors.grey400)),
                    ])),
                    const SizedBox(width: 12),
                    Text(format.format(pm.total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  ]),
                );
              }).toList()),
            ),
          ),
        if (analytics.dashboardData?.paymentMethodBreakdown != null && analytics.dashboardData!.paymentMethodBreakdown.isNotEmpty)
          const SizedBox(height: 20),
      ]),
    );
  }

  // === REPORTS TAB ===
  Widget _buildReports(BuildContext context, AnalyticsProvider analytics, NumberFormat format, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Savings Growth
        AnalyticsChartCard(
          title: 'Savings Growth',
          height: 220,
          trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.trending_up, size: 14, color: AppColors.success),
              const SizedBox(width: 4),
              Text('Net Savings', style: TextStyle(fontSize: 10, color: isDark ? AppColors.grey400 : AppColors.grey500)),
            ])),
          child: analytics.savingsGrowth != null ? _buildSavingsChart(analytics.savingsGrowth!) : const Center(child: Text('No savings data')),
        ),
        const SizedBox(height: 20),

        // Best/Worst Month
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
              ),
              child: Column(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 18)),
                const SizedBox(height: 8),
                Text('Best Month', style: TextStyle(fontSize: 11, color: isDark ? AppColors.grey500 : AppColors.grey400)),
                const SizedBox(height: 4),
                Text(_bestMonth(format, analytics), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
              ),
              child: Column(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_downward_rounded, color: AppColors.danger, size: 18)),
                const SizedBox(height: 8),
                Text('Worst Month', style: TextStyle(fontSize: 11, color: isDark ? AppColors.grey500 : AppColors.grey400)),
                const SizedBox(height: 4),
                Text(_worstMonth(format, analytics), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // Smart Insights
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.warning, size: 18)),
          const SizedBox(width: 10),
          Text('Smart Insights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ]),
        const SizedBox(height: 12),
        if (analytics.recommendations.isEmpty)
          Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? AppColors.darkCard : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text('No insights yet. Keep tracking your finances!', style: TextStyle(fontSize: 13, color: isDark ? AppColors.grey500 : AppColors.grey400)))
        else
          ...analytics.recommendations.map((rec) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InsightCard(
              icon: rec.type == 'danger' ? Icons.warning_amber_rounded : rec.type == 'success' ? Icons.check_circle_rounded : Icons.lightbulb_outline_rounded,
              iconColor: rec.type == 'danger' ? AppColors.danger : rec.type == 'success' ? AppColors.success : AppColors.warning,
              message: rec.message,
            ),
          )),
        const SizedBox(height: 20),
      ]),
    );
  }

  // === TRENDS TAB ===
  Widget _buildTrends(BuildContext context, AnalyticsProvider analytics, NumberFormat format, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Advanced Analytics', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),

        // Navigation row
        Row(children: [
          Expanded(child: _buildNavCard(context, Icons.calendar_month_rounded, 'Calendar', AppColors.primary, AppRoutes.calendar)),
          const SizedBox(width: 12),
          Expanded(child: _buildNavCard(context, Icons.subscriptions_rounded, 'Subscriptions', AppColors.secondary, AppRoutes.subscriptions)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildNavCard(context, Icons.account_balance_rounded, 'Net Worth', const Color(0xFF8B5CF6), AppRoutes.netWorth)),
          const SizedBox(width: 12),
          Expanded(child: _buildNavCard(context, Icons.auto_awesome_rounded, 'AI Advisor', AppColors.warning, AppRoutes.financialAdvisor)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildNavCard(context, Icons.picture_as_pdf_rounded, 'Monthly Report', AppColors.danger, AppRoutes.report)),
          const SizedBox(width: 12),
          Expanded(child: _buildNavCard(context, Icons.grid_view_rounded, 'Heatmap', AppColors.success, AppRoutes.heatmap)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildNavCard(context, Icons.compare_arrows_rounded, 'Comparison', AppColors.primary, AppRoutes.report, mode: 'comparison')),
          const SizedBox(width: 12),
          Expanded(child: _buildNavCard(context, Icons.trending_up_rounded, 'Auto-Save', AppColors.success, AppRoutes.autoSave)),
        ]),
        const SizedBox(height: 24),

        // Spending Trends
        Text('Spending Trends', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildTrendInsight('Fastest Growing Category', 'Transportation', '+18%', AppColors.danger, Icons.trending_up, isDark),
        const SizedBox(height: 8),
        _buildTrendInsight('Most Reduced Category', 'Shopping', '-12%', AppColors.success, Icons.trending_down, isDark),
        const SizedBox(height: 8),
        _buildTrendInsight('Average Daily Spending', '', format.format(120), AppColors.primary, Icons.calendar_view_day_rounded, isDark),
        const SizedBox(height: 8),
        _buildTrendInsight('Average Weekly Spending', '', format.format(840), AppColors.warning, Icons.calendar_view_week_rounded, isDark),
        const SizedBox(height: 8),
        _buildTrendInsight('Average Monthly Spending', '', format.format(3600), AppColors.secondary, Icons.calendar_month_rounded, isDark),
        const SizedBox(height: 24),

        // Quick Links
        Text('Quick Reports', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ListTile(
          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger)),
          title: const Text('Generate Monthly Report'),
          subtitle: const Text('PDF with income, expenses & savings'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, AppRoutes.report),
        ),
        const Divider(),
        ListTile(
          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.compare_arrows_rounded, color: AppColors.primary)),
          title: const Text('Month-over-Month Comparison'),
          subtitle: const Text('Compare income, expenses & categories'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, AppRoutes.report),
        ),
        const Divider(),
        ListTile(
          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.grid_view_rounded, color: AppColors.success)),
          title: const Text('Spending Heatmap'),
          subtitle: const Text('GitHub-style yearly spending view'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, AppRoutes.heatmap),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildNavCard(BuildContext context, IconData icon, String label, Color color, String route, {String? mode}) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route, arguments: mode),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey100),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A)), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildTrendInsight(String label, String sublabel, String value, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          if (sublabel.isNotEmpty) Text(sublabel, style: TextStyle(fontSize: 11, color: isDark ? AppColors.grey500 : AppColors.grey400)),
        ])),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  // === HELPERS ===
  int _calcHealthScore(AnalyticsProvider analytics) {
    final income = (analytics.incomeVsExpenses?['income']?['total'] ?? 0).toDouble();
    final expenses = (analytics.incomeVsExpenses?['expenses']?['total'] ?? 0).toDouble();
    if (income == 0 && expenses == 0) return 0;
    final ratio = income > 0 ? (expenses / income) : 2;
    if (ratio <= 0.3) return 95;
    if (ratio <= 0.5) return 85;
    if (ratio <= 0.75) return 70;
    if (ratio <= 1.0) return 55;
    return 35;
  }

  String _healthStatus(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    if (score >= 20) return 'Needs Work';
    return 'Critical';
  }

  String? _healthTrend(AnalyticsProvider analytics) {
    final trends = analytics.monthlyTrend;
    if (trends.length < 2) return null;
    final last = trends.last;
    final prev = trends[trends.length - 2];
    final lastNet = last.income - last.expenses;
    final prevNet = prev.income - prev.expenses;
    if (prevNet == 0) return null;
    final change = ((lastNet - prevNet) / prevNet.abs() * 100).round();
    if (change == 0) return null;
    return '${change > 0 ? '+' : ''}$change%';
  }

  String _bestMonth(NumberFormat format, AnalyticsProvider analytics) {
    final trends = analytics.monthlyTrend;
    if (trends.isEmpty) return '--';
    double best = -double.infinity;
    String bestLabel = '--';
    for (final t in trends) {
      final net = t.income - t.expenses;
      if (net > best) { best = net; bestLabel = t.month.substring(5); }
    }
    return best <= 0 ? '--' : '${format.format(best)} ($bestLabel)';
  }

  String _worstMonth(NumberFormat format, AnalyticsProvider analytics) {
    final trends = analytics.monthlyTrend;
    if (trends.isEmpty) return '--';
    double worst = double.infinity;
    String worstLabel = '--';
    for (final t in trends) {
      final net = t.income - t.expenses;
      if (net < worst) { worst = net; worstLabel = t.month.substring(5); }
    }
    return worst == double.infinity ? '--' : '${format.format(worst)} ($worstLabel)';
  }

  Widget _buildTrendChart(List<MonthlyTrend> trends) {
    if (trends.isEmpty) return const Center(child: Text('No trend data'));

    final maxVal = trends.fold<double>(0, (m, t) => [m, t.income, t.expenses].reduce((a, b) => a > b ? a : b));
    final step = maxVal > 0 ? (maxVal / 4).ceilToDouble() : 1.0;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.15,
        barTouchData: BarTouchData(enabled: false),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: step, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.04), strokeWidth: 1)),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, m) {
            final i = v.toInt();
            return i >= 0 && i < trends.length
                ? Padding(padding: const EdgeInsets.only(top: 4), child: Text(trends[i].month.substring(5), style: TextStyle(fontSize: 10, color: AppColors.grey500)))
                : const Text('');
          })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: trends.asMap().entries.map((e) => BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(toY: e.value.income, color: AppColors.success, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            BarChartRodData(toY: e.value.expenses, color: AppColors.danger, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ],
        )).toList(),
      )),
    );
  }

  Widget _buildSavingsChart(Map<String, dynamic> data) {
    final growth = data['growth'] as List? ?? [];
    if (growth.isEmpty) return const Center(child: Text('No savings data'));

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: BarChart(BarChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, m) => v < growth.length ? Text(growth[v.toInt()]['month'].toString().substring(5), style: TextStyle(fontSize: 10, color: AppColors.grey500)) : const Text(''))),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: growth.asMap().entries.map((e) {
          final v = (e.value['savings'] as num).toDouble();
          return BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(
              toY: v,
              color: v >= 0 ? AppColors.success : AppColors.danger,
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]);
        }).toList(),
      )),
    );
  }

  Widget _buildCategoryChart(List<CategoryBreakdown> breakdown, NumberFormat format, bool isDark) {
    final total = breakdown.fold<double>(0, (s, c) => s + c.amount);

    return Column(children: [
      Expanded(child: PieChart(PieChartData(
        sections: breakdown.asMap().entries.map((e) => PieChartSectionData(
          value: e.value.amount,
          title: total > 0 ? '${e.value.percentage.toStringAsFixed(0)}%' : '',
          color: AppColors.chartColors[e.key % AppColors.chartColors.length],
          radius: 45,
          titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        )).toList(),
        centerSpaceRadius: 35,
        sectionsSpace: 2,
      ))),
    ]);
  }

  Widget _buildCategoryLegend(List<CategoryBreakdown> breakdown, NumberFormat format, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        children: breakdown.asMap().entries.map((e) {
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.chartColors[e.key % AppColors.chartColors.length], borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(e.value.category, style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey300 : const Color(0xFF475569))),
            const SizedBox(width: 4),
            Text(format.format(e.value.amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ]);
        }).toList(),
      ),
    );
  }
}
