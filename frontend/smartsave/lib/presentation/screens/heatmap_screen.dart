import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../providers/report_provider.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadHeatmap(_selectedYear);
    });
  }

  void _changeYear(int delta) {
    setState(() {
      _selectedYear += delta;
    });
    context.read<ReportProvider>().loadHeatmap(_selectedYear);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Spending Heatmap'),
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildYearSelector(isDark),
                  const SizedBox(height: 20),
                  _buildHeatmapGrid(provider, isDark),
                  const SizedBox(height: 20),
                  _buildLegend(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildYearSelector(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => _changeYear(-1),
          icon: const Icon(Icons.chevron_left),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '$_selectedYear',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () => _changeYear(1),
          icon: const Icon(Icons.chevron_right),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapGrid(ReportProvider provider, bool isDark) {
    final heatmap = provider.heatmap;
    if (heatmap == null) return const SizedBox.shrink();

    final firstDay = DateTime(_selectedYear, 1, 1);
    final lastDay = DateTime(_selectedYear, 12, 31);
    final startWeekday = firstDay.weekday;
    final startDate = firstDay.subtract(Duration(days: startWeekday - DateTime.monday));
    final totalDays = lastDay.difference(startDate).inDays + 1;
    final weeks = (totalDays / 7).ceil();

    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(7, (row) {
                  return SizedBox(
                    height: 14,
                    child: Center(
                      child: Text(
                        dayLabels[row],
                        style: TextStyle(fontSize: 9, color: isDark ? AppColors.grey500 : AppColors.grey400),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(7, (row) {
                      return Row(
                        children: List.generate(weeks, (col) {
                          final dayIndex = col * 7 + row;
                          final date = startDate.add(Duration(days: dayIndex));
                          if (date.year != _selectedYear) {
                            return _buildEmptyCell();
                          }
                          return _buildDayCell(date, heatmap.heatmap, heatmap.maxSpend, isDark);
                        }),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCell() {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Colors.transparent,
      ),
    );
  }

  Widget _buildDayCell(DateTime date, Map<String, Map<String, dynamic>> heatmapData, double maxSpend, bool isDark) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final entry = heatmapData[dateStr];
    final amount = entry != null ? (entry['amount'] ?? 0).toDouble() : 0.0;
    final intensity = maxSpend > 0 ? amount / maxSpend : 0.0;

    Color cellColor;
    if (amount == 0) {
      cellColor = isDark ? AppColors.darkCardAlt.withValues(alpha: 0.5) : AppColors.grey100;
    } else if (intensity <= 0.25) {
      cellColor = AppColors.success.withValues(alpha: 0.3);
    } else if (intensity <= 0.50) {
      cellColor = AppColors.success.withValues(alpha: 0.5);
    } else if (intensity <= 0.75) {
      cellColor = AppColors.success.withValues(alpha: 0.7);
    } else {
      cellColor = AppColors.success.withValues(alpha: 0.95);
    }

    return GestureDetector(
      onTap: () {
        final formatted = NumberFormat.currency(symbol: r'$').format(amount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Date: $dateStr, Spent: $formatted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: cellColor,
        ),
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    final levels = [
      ('No Spend', isDark ? AppColors.darkCardAlt.withValues(alpha: 0.5) : AppColors.grey100),
      ('Low', AppColors.success.withValues(alpha: 0.3)),
      ('Medium', AppColors.success.withValues(alpha: 0.5)),
      ('High', AppColors.success.withValues(alpha: 0.7)),
      ('Very High', AppColors.success.withValues(alpha: 0.95)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending Intensity',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: levels.map((l) {
              return Column(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: l.$2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.$1,
                    style: TextStyle(fontSize: 9, color: isDark ? AppColors.grey500 : AppColors.grey400),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
