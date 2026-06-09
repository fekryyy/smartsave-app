import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../../presentation/providers/report_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../data/models/report_model.dart';
import '../../core/network/api_client.dart';
import '../../app/app.dart';

class ReportScreen extends StatefulWidget {
  final String? mode;
  const ReportScreen({super.key, this.mode});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> with RouteAware {
  late int _year;
  late int _month;
  bool _exporting = false;
  bool _isComparison = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _isComparison = widget.mode == 'comparison';
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
    _load();
  }

  Future<void> _load() async {
    if (_isComparison) {
      await context.read<ReportProvider>().loadComparison(_year, _month);
    } else {
      await context.read<ReportProvider>().loadReport(_year, _month);
    }
  }

  void _previousMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
    _load();
  }

  Future<void> _exportPDF() async {
    setState(() => _exporting = true);
    try {
      final result = await ApiClient().getBytes('/export/pdf', queryParameters: {
        'year': _year.toString(),
        'month': _month.toString(),
      });
      final bytes = result.dataOrThrow;
      final path = 'report_${_year}_$_month.pdf';
      await Share.shareXFiles([XFile.fromData(bytes, path: path, mimeType: 'application/pdf')]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final authProvider = context.watch<AuthProvider>();
    final format = CurrencyUtil.getFormat(authProvider.user?.currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final report = reportProvider.currentReport;
    final comparison = reportProvider.comparison;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isComparison ? 'Month Comparison' : 'Monthly Report'),
        actions: [
          if (_exporting)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _exportPDF,
            ),
        ],
      ),
      body: reportProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: _isComparison
                    ? _buildComparisonView(comparison, format, isDark)
                    : [
                        _buildMonthPicker(context, isDark),
                        const SizedBox(height: 20),
                        if (report == null)
                          const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No report data for this period')))
                        else ...[
                          _buildSummaryGrid(report, format, isDark),
                          const SizedBox(height: 20),
                          _buildComparisonRow(report, isDark),
                          const SizedBox(height: 24),
                          _buildInsightCards(report, format, isDark),
                          const SizedBox(height: 24),
                          _buildBudgetPerformance(report, format, isDark),
                          const SizedBox(height: 24),
                          _buildCategoryBreakdown(report, format, isDark),
                        ],
                      ],
              ),
            ),
    );
  }

  List<Widget> _buildComparisonView(List<ComparisonItem> comparison, NumberFormat format, bool isDark) {
    if (comparison.isEmpty) {
      return [const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No comparison data available')))];
    }
    return [
      _buildMonthPicker(context, isDark),
      const SizedBox(height: 20),
      ...comparison.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('${DateFormat('MMMM').format(DateTime(item.year, item.month))} ${item.year}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          _compRow('Income', format.format(item.income), AppColors.success),
          _compRow('Expenses', format.format(item.expense), AppColors.danger),
          _compRow('Savings', format.format(item.savings), AppColors.primary),
        ]),
      )),
    ];
  }

  Widget _compRow(String label, String value, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: AppColors.grey500, fontSize: 13))),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
    ]));
  }

  Widget _buildMonthPicker(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: _previousMonth),
        Text(
          '${DateFormat('MMMM').format(DateTime(_year, _month))} $_year',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: _nextMonth),
      ]),
    );
  }

  Widget _buildSummaryGrid(MonthlyReport report, NumberFormat format, bool isDark) {
    final items = [
      _SummaryItem('Total Income', format.format(report.totalIncome), Icons.trending_up_rounded, AppColors.success),
      _SummaryItem('Total Expenses', format.format(report.totalExpenses), Icons.trending_down_rounded, AppColors.danger),
      _SummaryItem('Net Savings', format.format(report.netSavings), Icons.savings_rounded, AppColors.primary),
      _SummaryItem('Savings Rate', '${report.savingsRate.toStringAsFixed(1)}%', Icons.pie_chart_rounded, AppColors.warning),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: item.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey500 : AppColors.grey400)),
              const SizedBox(height: 2),
              Text(item.value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildComparisonRow(MonthlyReport report, bool isDark) {
    final comparisons = [
      _ComparisonData('Income', report.incomeChange, AppColors.success),
      _ComparisonData('Expenses', report.expenseChange, AppColors.danger),
      _ComparisonData('Savings', report.savingsChange, AppColors.primary),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('vs Previous Month', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.grey400 : AppColors.grey500)),
        const SizedBox(height: 12),
        Row(children: comparisons.map((c) {
          final isPositive = c.change >= 0;
          final isExpense = c.label == 'Expenses';
          final goodChange = isExpense ? !isPositive : isPositive;
          final arrowColor = goodChange ? AppColors.success : AppColors.danger;
          final arrowIcon = isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

          return Expanded(
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Icon(arrowIcon, size: 14, color: arrowColor),
                const SizedBox(width: 2),
                Text('${isPositive ? '+' : ''}${c.change.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: arrowColor)),
              ]),
              const SizedBox(height: 2),
              Text(c.label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.grey500 : AppColors.grey400)),
            ]),
          );
        }).toList()),
      ]),
    );
  }

  Widget _buildInsightCards(MonthlyReport report, NumberFormat format, bool isDark) {
    return Column(children: [
      _buildInfoCard(
        icon: Icons.credit_card_rounded,
        iconColor: AppColors.secondary,
        title: 'Most Used Payment Method',
        value: report.mostUsedMethod.isEmpty ? 'N/A' : report.mostUsedMethod,
        isDark: isDark,
      ),
      const SizedBox(height: 10),
      _buildInfoCard(
        icon: Icons.receipt_long_rounded,
        iconColor: AppColors.danger,
        title: 'Largest Expense',
        value: report.largestExpense != null
            ? '${report.largestExpense!['category'] ?? 'Unknown'}: ${format.format((report.largestExpense!['amount'] ?? 0).toDouble())}'
            : 'N/A',
        isDark: isDark,
      ),
      const SizedBox(height: 10),
      _buildInfoCard(
        icon: Icons.category_rounded,
        iconColor: AppColors.warning,
        title: 'Top Spending Category',
        value: report.topCategory.isEmpty ? 'N/A' : report.topCategory,
        isDark: isDark,
      ),
    ]);
  }

  Widget _buildInfoCard({required IconData icon, required Color iconColor, required String title, required String value, required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey500 : AppColors.grey400)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ])),
      ]),
    );
  }

  Widget _buildBudgetPerformance(MonthlyReport report, NumberFormat format, bool isDark) {
    final budgets = report.budgetPerformance;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Budget Performance', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (budgets.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? AppColors.darkCard : Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Text('No budgets set for this period', style: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400)),
        )
      else
        ...budgets.map((b) {
          final spent = (b['spent'] ?? 0).toDouble();
          final budget = (b['budget'] ?? 0).toDouble();
          final pct = budget > 0 ? (spent / budget * 100) : 0.0;
          final pctClamped = pct.clamp(0, 100) / 100;

          Color barColor;
          if (pct >= 100) barColor = AppColors.danger;
          else if (pct >= 80) barColor = AppColors.warning;
          else barColor = AppColors.success;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(b['category'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)))),
                Text('${format.format(spent)} / ${format.format(budget)}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey500 : AppColors.grey400)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
                value: pctClamped,
                backgroundColor: barColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 6,
              )),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: barColor),
              )),
            ]),
          );
        }),
    ]);
  }

  Widget _buildCategoryBreakdown(MonthlyReport report, NumberFormat format, bool isDark) {
    final categories = report.categoryBreakdown;
    final total = categories.fold<double>(0, (s, c) => s + (c['amount'] ?? 0).toDouble());

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Category Breakdown', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (categories.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? AppColors.darkCard : Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Text('No data', style: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400)),
        )
      else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
          ),
          child: Column(children: categories.asMap().entries.map((e) {
            final cat = e.value;
            final catName = cat['category'] ?? cat['_id'] ?? '';
            final catAmount = (cat['amount'] ?? 0).toDouble();
            final catPct = total > 0 ? (catAmount / total * 100) : 0.0;
            final color = AppColors.chartColors[e.key % AppColors.chartColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: Text(catName, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)))),
                Expanded(flex: 2, child: Text(format.format(catAmount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)), textAlign: TextAlign.right)),
                SizedBox(width: 40, child: Text('${catPct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey500 : AppColors.grey400), textAlign: TextAlign.right)),
              ]),
            );
          }).toList()),
        ),
    ]);
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryItem(this.label, this.value, this.icon, this.color);
}

class _ComparisonData {
  final String label;
  final double change;
  final Color color;
  const _ComparisonData(this.label, this.change, this.color);
}
