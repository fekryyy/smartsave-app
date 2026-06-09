import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_util.dart';
import '../../presentation/providers/budget_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../data/models/budget_model.dart';
import '../widgets/common/empty_state.dart';
import '../../app/app.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> with RouteAware {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
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
    _loadData();
  }

  void _loadData() {
    context.read<BudgetProvider>().loadOverview();
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final authProvider = context.watch<AuthProvider>();
    final format = CurrencyUtil.getFormat(authProvider.user?.currency);
    final overview = budgetProvider.overview;
    final summary = overview?['summary'];

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddBudgetDialog(context)),
      ]),
      body: budgetProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => budgetProvider.loadOverview(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(children: [
                      if (budgetProvider.errorMessage != null)
                        Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(budgetProvider.errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                            GestureDetector(onTap: () => budgetProvider.clearError(), child: const Icon(Icons.close, color: AppColors.danger, size: 16)),
                          ])),
                      // Overall Budget Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))]),
                        child: Column(children: [
                          Text('Monthly Budget', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text(format.format(summary?['totalBudget'] ?? 0), style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Spent: ${format.format(summary?['totalSpent'] ?? 0)}  |  Remaining: ${format.format(summary?['remaining'] ?? 0)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 16),
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ((summary?['percentageUsed'] ?? 0) / 100).clamp(0.0, 1.0), backgroundColor: Colors.white.withValues(alpha: 0.3), valueColor: const AlwaysStoppedAnimation(Colors.white), minHeight: 8)),
                          const SizedBox(height: 4),
                          Text('${summary?['percentageUsed'] ?? 0}% used', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      Text('Category Budgets', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                    ]),
                  )),
                  if (budgetProvider.budgets.isEmpty)
                    const SliverToBoxAdapter(child: EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No budgets set', subtitle: 'Set category budgets to track spending'))
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final budget = budgetProvider.budgets[index];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                            child: RepaintBoundary(child: _buildBudgetCard(context, budget, format)),
                          );
                        },
                        childCount: budgetProvider.budgets.length,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildBudgetCard(BuildContext context, BudgetModel budget, NumberFormat format) {
    final percentage = budget.percentageUsed.clamp(0, 100);
    Color barColor;
    if (percentage >= 90) {
      barColor = AppColors.danger;
    } else if (percentage >= 75) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey100)),
      child: Column(children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: barColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(_getCategoryIcon(budget.category), color: barColor)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(budget.category, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('${format.format(budget.spent)} / ${format.format(budget.amount)}', style: Theme.of(context).textTheme.bodySmall),
          ])),
          Text('${percentage.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: barColor)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (percentage / 100).clamp(0.0, 1.0), backgroundColor: AppColors.grey100, valueColor: AlwaysStoppedAnimation(barColor), minHeight: 6)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Remaining: ${format.format(budget.remaining)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: percentage >= 90 ? AppColors.danger : AppColors.grey500)),
          Row(children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showEditBudgetDialog(context, budget)),
            IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger), onPressed: () async => await context.read<BudgetProvider>().deleteBudget(budget.id)),
          ]),
        ]),
      ]),
    );
  }

  String? _validateAmount(String? v) {
    if (v == null || v.isEmpty) return 'Enter an amount';
    if (double.tryParse(v) == null) return 'Enter a valid number';
    if (double.parse(v) <= 0) return 'Amount must be greater than 0';
    return null;
  }

  void _showAddBudgetDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    String category = 'Food';
    final currency = context.read<AuthProvider>().user?.currency;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Set Category Budget'),
      content: Form(
        key: formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField(initialValue: category, items: AppConstants.expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => category = v ?? 'Food', decoration: const InputDecoration(labelText: 'Category')),
          const SizedBox(height: 12),
          TextFormField(controller: amountCtrl, decoration: InputDecoration(labelText: 'Budget Amount', prefixText: CurrencyUtil.getPrefixText(currency)), keyboardType: TextInputType.number, validator: _validateAmount),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (!formKey.currentState!.validate()) return;
          final success = await context.read<BudgetProvider>().createBudget({
            'category': category,
            'amount': double.parse(amountCtrl.text),
          });
          if (success && ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Set Budget')),
      ],
    ));
  }

  void _showEditBudgetDialog(BuildContext context, BudgetModel budget) {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(text: budget.amount.toString());
    final currency = context.read<AuthProvider>().user?.currency;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Edit ${budget.category} Budget'),
      content: Form(
        key: formKey,
        child: TextFormField(controller: amountCtrl, decoration: InputDecoration(labelText: 'Budget Amount', prefixText: CurrencyUtil.getPrefixText(currency)), keyboardType: TextInputType.number, validator: _validateAmount),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (!formKey.currentState!.validate()) return;
          final success = await context.read<BudgetProvider>().updateBudget(budget.id, {'amount': double.parse(amountCtrl.text)});
          if (success && ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Save')),
      ],
    ));
  }

  IconData _getCategoryIcon(String category) {
    const icons = {'Food': Icons.restaurant, 'Transportation': Icons.directions_car, 'Shopping': Icons.shopping_cart, 'Bills': Icons.receipt_long, 'Entertainment': Icons.movie, 'Health': Icons.local_hospital, 'Education': Icons.school, 'Travel': Icons.flight, 'Other': Icons.category, 'Overall': Icons.account_balance_wallet};
    return icons[category] ?? Icons.category;
  }
}
