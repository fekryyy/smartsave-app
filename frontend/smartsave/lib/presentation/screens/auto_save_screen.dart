import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_util.dart';
import '../../presentation/providers/auto_save_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../data/models/auto_save_model.dart';
import '../widgets/common/empty_state.dart';
import '../../app/routes.dart';

class AutoSaveScreen extends StatefulWidget {
  const AutoSaveScreen({super.key});

  @override
  State<AutoSaveScreen> createState() => _AutoSaveScreenState();
}

class _AutoSaveScreenState extends State<AutoSaveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AutoSaveProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AutoSaveProvider>();
    final authProvider = context.watch<AuthProvider>();
    final format = CurrencyUtil.getFormat(authProvider.user?.currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCount = provider.rules.where((r) => r.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Save Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showRuleSheet(context),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.loadAll(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(children: [
                      _buildSummaryCard(context, provider.totalProjected, activeCount, format, isDark),
                      const SizedBox(height: 24),
                      Text('Your Rules', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                    ]),
                  )),
                  if (provider.rules.isEmpty)
                    const SliverToBoxAdapter(child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: EmptyState(
                        icon: Icons.auto_graph_rounded,
                        title: 'No auto-save rules',
                        subtitle: 'Set rules to save money automatically',
                      ),
                    ))
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final rule = provider.rules[index];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: RepaintBoundary(child: _buildRuleCard(context, rule, format, isDark, provider)),
                          );
                        },
                        childCount: provider.rules.length,
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRuleSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, double totalProjected, int activeCount, NumberFormat format, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total Projected Savings', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 4),
            Text(format.format(totalProjected), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('$activeCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Active', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildRuleCard(BuildContext context, AutoSaveRule rule, NumberFormat format, bool isDark, AutoSaveProvider provider) {
    final typeColors = {
      'Percentage of Income': AppColors.primary,
      'Fixed Daily': AppColors.success,
      'Fixed Payday': AppColors.secondary,
      'Percentage Bonus': AppColors.warning,
      'Round Up': AppColors.success,
    };
    final color = typeColors[rule.type] ?? AppColors.grey500;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(_getTypeIcon(rule.type), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(rule.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(rule.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                rule.type == 'Percentage of Income' || rule.type == 'Percentage Bonus'
                    ? '${rule.percentage.toStringAsFixed(1)}%'
                    : format.format(rule.amount),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.schedule_rounded, size: 14, color: AppColors.grey500),
          const SizedBox(width: 4),
          Text(rule.frequency, style: TextStyle(fontSize: 12, color: AppColors.grey500)),
          if (rule.paydayDay != null) ...[
            const SizedBox(width: 12),
            Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.grey500),
            const SizedBox(width: 4),
            Text('Day ${rule.paydayDay}', style: TextStyle(fontSize: 12, color: AppColors.grey500)),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: rule.isActive ? AppColors.success.withOpacity(0.1) : AppColors.grey200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rule.isActive ? 'Active' : 'Inactive',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: rule.isActive ? AppColors.success : AppColors.grey500),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: isDark ? AppColors.darkCardAlt : AppColors.grey50, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.savings_outlined, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Total contributed: ${format.format(rule.totalContributed)}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey600)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _showRuleSheet(context, rule: rule),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Rule'),
                  content: Text('Delete "${rule.name}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              );
              if (confirm == true) {
                await provider.delete(rule.id);
              }
            },
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: () async {
              await provider.triggerContribution(rule.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contribution triggered')));
              }
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Trigger Now', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ]),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Percentage of Income': return Icons.percent_rounded;
      case 'Fixed Daily': return Icons.today_rounded;
      case 'Fixed Payday': return Icons.payments_rounded;
      case 'Percentage Bonus': return Icons.card_giftcard_rounded;
      case 'Round Up': return Icons.trending_up_rounded;
      default: return Icons.savings_rounded;
    }
  }

  void _showRuleSheet(BuildContext context, {AutoSaveRule? rule}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: rule?.name ?? '');
    final amountCtrl = TextEditingController(text: rule?.amount != 0 ? rule!.amount.toString() : '');
    final percentageCtrl = TextEditingController(text: rule?.percentage != 0 ? '${rule!.percentage.toStringAsFixed(1)}' : '');

    String selectedType = rule?.type ?? 'Percentage of Income';
    String selectedFrequency = rule?.frequency ?? 'monthly';
    int? paydayDay = rule?.paydayDay;
    bool isActive = rule?.isActive ?? true;
    bool isPercentType = selectedType == 'Percentage of Income' || selectedType == 'Percentage Bonus';

    final typeOptions = ['Percentage of Income', 'Fixed Daily', 'Fixed Payday', 'Percentage Bonus', 'Round Up'];
    final frequencyOptions = ['daily', 'weekly', 'bi-weekly', 'monthly'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          isPercentType = selectedType == 'Percentage of Income' || selectedType == 'Percentage Bonus';

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: ListView(children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    rule == null ? 'New Auto-Save Rule' : 'Edit Rule',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Rule Name',
                      hintText: 'e.g. Weekly Coffee Savings',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: typeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setSheetState(() => selectedType = v ?? selectedType),
                  ),
                  const SizedBox(height: 16),
                  if (!isPercentType)
                    TextFormField(
                      controller: amountCtrl,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: CurrencyUtil.getPrefixText(null),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter amount';
                        if (double.tryParse(v) == null) return 'Invalid number';
                        if (double.parse(v) <= 0) return 'Must be greater than 0';
                        return null;
                      },
                    ),
                  if (isPercentType)
                    TextFormField(
                      controller: percentageCtrl,
                      decoration: InputDecoration(
                        labelText: 'Percentage',
                        suffixText: '%',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter percentage';
                        final p = double.tryParse(v);
                        if (p == null) return 'Invalid number';
                        if (p <= 0 || p > 100) return 'Between 1 and 100';
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedFrequency,
                    decoration: InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: frequencyOptions.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) => setSheetState(() => selectedFrequency = v ?? selectedFrequency),
                  ),
                  if (selectedType == 'Fixed Payday') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: paydayDay?.toString() ?? '',
                      decoration: InputDecoration(
                        labelText: 'Payday Day of Month',
                        hintText: 'e.g. 15',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => paydayDay = int.tryParse(v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setSheetState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final data = <String, dynamic>{
                        'name': nameCtrl.text.trim(),
                        'type': selectedType,
                        'frequency': selectedFrequency,
                        'isActive': isActive,
                      };

                      if (isPercentType) {
                        data['percentage'] = double.parse(percentageCtrl.text);
                      } else {
                        data['amount'] = double.parse(amountCtrl.text);
                      }

                      if (selectedType == 'Fixed Payday' && paydayDay != null) {
                        data['paydayDay'] = paydayDay;
                      }

                      bool success;
                      if (rule == null) {
                        success = await context.read<AutoSaveProvider>().create(data);
                      } else {
                        success = await context.read<AutoSaveProvider>().update(rule.id, data);
                      }

                      if (success && ctx.mounted) {
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(rule == null ? 'Rule created' : 'Rule updated')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(rule == null ? 'Create Rule' : 'Save Changes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          );
        });
      },
    );
  }
}
