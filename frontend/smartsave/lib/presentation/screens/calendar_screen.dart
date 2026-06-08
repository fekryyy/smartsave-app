import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../providers/calendar_provider.dart';
import '../providers/auth_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _currentMonth;
  final _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(_today.year, _today.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() => context.read<CalendarProvider>().loadData(_currentMonth.year, _currentMonth.month);

  String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarProvider>();
    final authProvider = context.watch<AuthProvider>();
    final format = CurrencyUtil.getFormat(authProvider.user?.currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Calendar')),
      body: calendar.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton(onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1)); _loadData(); }, icon: const Icon(Icons.chevron_left)),
                  Text(DateFormat('MMMM yyyy').format(_currentMonth), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  IconButton(onPressed: () { setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1)); _loadData(); }, icon: const Icon(Icons.chevron_right)),
                ]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].map((l) => Expanded(child: Center(child: Text(l, style: TextStyle(fontSize: 11, color: isDark ? AppColors.grey500 : AppColors.grey600, fontWeight: FontWeight.w600))))).toList()),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _loadData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Wrap(
                          spacing: 0, runSpacing: 4,
                          children: [
                            ...List.generate(firstWeekday, (_) => const Expanded(child: SizedBox())),
                            ...List.generate(daysInMonth, (day) {
                              final date = DateTime(_currentMonth.year, _currentMonth.month, day + 1);
                              final data = calendar.calendarData?.daily[_dayKey(date)];
                              final income = (data?['income'] as num?)?.toDouble() ?? 0;
                              final expense = (data?['expense'] as num?)?.toDouble() ?? 0;
                              final savings = (data?['savings'] as num?)?.toDouble() ?? 0;
                              final isToday = date.day == _today.day && date.month == _today.month && date.year == _today.year;
                              return SizedBox(
                                width: (MediaQuery.of(context).size.width - 16) / 7,
                                child: GestureDetector(
                                  onTap: () => _showDayDetail(context, date, data, calendar, format, isDark),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.all(2),
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isToday ? AppColors.primary.withOpacity(0.15) : isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(12),
                                      border: isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
                                    ),
                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                                      Text('${day + 1}', style: TextStyle(fontSize: 13, fontWeight: isToday ? FontWeight.w700 : FontWeight.w500, color: isToday ? AppColors.primary : null)),
                                      if (income > 0 || expense > 0 || savings > 0) ...[
                                        const SizedBox(height: 3),
                                        Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                                          if (income > 0) _dot(AppColors.success),
                                          if (expense > 0) _dot(AppColors.danger),
                                          if (savings > 0) _dot(AppColors.primaryLight),
                                        ]),
                                      ],
                                    ]),
                                  ),
                                ),
                              );
                            }),
                          ].map((c) => c).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (calendar.calendarData != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                            ...[AppColors.success, AppColors.danger, AppColors.primaryLight, AppColors.primary]
                              .asMap().entries.map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: e.value, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text(['Income','Expense','Savings','Recurring'][e.key], style: TextStyle(color: AppColors.grey500, fontSize: 11)),
                              ])).toList(),
                          ]),
                        ),
                    ]),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _dot(Color color) => Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  void _showDayDetail(BuildContext context, DateTime date, Map<String, dynamic>? data, CalendarProvider calendar, NumberFormat format, bool isDark) {
    final income = (data?['income'] as num?)?.toDouble() ?? 0;
    final expense = (data?['expense'] as num?)?.toDouble() ?? 0;
    final savings = (data?['savings'] as num?)?.toDouble() ?? 0;
    final transactions = ((data?['transactions'] as List?) ?? []).cast<Map<String, dynamic>>();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65, maxChildSize: 0.9, minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(controller: scrollController, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: AppColors.grey500.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            Text(DateFormat('EEEE, MMMM d, yyyy').format(date), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(children: [
              _chip(context, 'Income', format.format(income), AppColors.success, Icons.arrow_upward),
              const SizedBox(width: 8),
              _chip(context, 'Expenses', format.format(expense), AppColors.danger, Icons.arrow_downward),
              const SizedBox(width: 8),
              _chip(context, 'Savings', format.format(savings), AppColors.primaryLight, Icons.savings_outlined),
            ]),
            const SizedBox(height: 20),
            if (transactions.isNotEmpty) ...[
              Text('Transactions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...transactions.map((t) {
                final isInc = t['type'] == 'income';
                final c = isInc ? AppColors.success : AppColors.danger;
                return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(isInc ? Icons.arrow_upward : Icons.arrow_downward, color: c, size: 16)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t['category'] ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      if ((t['description'] ?? '').isNotEmpty) Text(t['description'], style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey500)),
                    ])),
                    Text(format.format((t['amount'] as num?)?.toDouble() ?? 0), style: TextStyle(color: c, fontWeight: FontWeight.w700)),
                  ]));
              }),
            ] else
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.grey500.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('No transactions for this day', style: TextStyle(color: AppColors.grey500)))),
            if (calendar.calendarData != null) ...[
              _buildRecurringDeadlines(context, calendar.calendarData!.upcomingRecurring, date, format, isDark, Icons.repeat, AppColors.primary, 'Recurring'),
              _buildRecurringDeadlines(context, calendar.calendarData!.budgetDeadlines, date, format, isDark, Icons.alarm, AppColors.warning, 'Budget Deadlines'),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String value, Color color, IconData icon) {
    return Expanded(child: Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [Icon(icon, color: color, size: 18), const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        Text(label, style: TextStyle(color: AppColors.grey500, fontSize: 10))])));
  }

  Widget _buildRecurringDeadlines(BuildContext context, List<Map<String, dynamic>> items, DateTime date, NumberFormat format, bool isDark, IconData icon, Color color, String title) {
    final filtered = items.where((r) {
      final d = DateTime.tryParse(r['nextDate'] ?? r['date'] ?? '');
      return d != null && d.day == date.day && d.month == date.month && d.year == date.year;
    }).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      ...filtered.map((r) {
        final label = r['name'] ?? r['category'] ?? r['title'] ?? '';
        final sub = r['frequency'] ?? r['status'] ?? '';
        final amt = (r['amount'] as num?)?.toDouble() ?? 0;
        return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 16)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(sub, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey500)),
            ])),
            if (amt > 0) Text(format.format(amt), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ]));
      }),
    ]);
  }
}
