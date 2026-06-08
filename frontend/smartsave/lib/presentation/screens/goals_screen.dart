import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../../presentation/providers/goal_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../data/models/goal_model.dart';
import '../widgets/common/empty_state.dart';
import '../../app/routes.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalProvider>().loadGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final goalProvider = context.watch<GoalProvider>();
    final authProvider = context.watch<AuthProvider>();
    final format = CurrencyUtil.getFormat(authProvider.user?.currency);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddGoalDialog(context)),
      ]),
      body: goalProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : goalProvider.goals.isEmpty
              ? const EmptyState(icon: Icons.flag_outlined, title: 'No goals yet', subtitle: 'Set your first savings goal')
              : RefreshIndicator(
                  onRefresh: () => goalProvider.loadGoals(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: goalProvider.goals.length + 1,
                    itemBuilder: (ctx, index) {
                      if (index == 0) {
                        return _buildSummaryCard(context, goalProvider, format);
                      }
                      final goal = goalProvider.goals[index - 1];
                      return _buildGoalCard(context, goal, format, goalProvider);
                    },
                  ),
                ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, GoalProvider provider, NumberFormat format) {
    final totalTarget = provider.goals.fold(0.0, (s, g) => s + g.targetAmount);
    final totalCurrent = provider.goals.fold(0.0, (s, g) => s + g.currentAmount);
    final progress = totalTarget > 0 ? (totalCurrent / totalTarget) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppColors.successGradient, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total Saved', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          Text('${provider.goals.length} goals', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        ]),
        const SizedBox(height: 8),
        Text(format.format(totalCurrent), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('of ${format.format(totalTarget)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white.withOpacity(0.3), valueColor: const AlwaysStoppedAnimation(Colors.white), minHeight: 8)),
      ]),
    );
  }

  Widget _buildGoalCard(BuildContext context, GoalModel goal, NumberFormat format, GoalProvider provider) {
    final progress = goal.targetAmount > 0 ? goal.currentAmount / goal.targetAmount : 0.0;
    final goalColor = _parseColor(goal.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey100)),
      child: Column(children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: goalColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(_getGoalIcon(goal.icon), color: goalColor)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(goal.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('${format.format(goal.currentAmount)} / ${format.format(goal.targetAmount)}', style: Theme.of(context).textTheme.bodySmall),
          ])),
          Column(children: [
            Text('${goal.progress.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(goal.status, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), backgroundColor: AppColors.grey100, valueColor: AlwaysStoppedAnimation(goalColor), minHeight: 6)),
        const SizedBox(height: 12),
        Row(children: [
          if (goal.targetDate != null) ...[
            const Icon(Icons.calendar_today, size: 14, color: AppColors.grey500),
            const SizedBox(width: 4),
            Text(DateFormat('MMM yyyy').format(goal.targetDate!), style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
          ],
          if (goal.monthlyContribution > 0) Text('${format.format(goal.monthlyContribution)}/mo', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _showContributeDialog(context, goal, provider), child: const Text('Add Funds'))),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _showEditGoalDialog(context, goal)),
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger), onPressed: () => _confirmDelete(context, goal.id, provider)),
        ]),
      ]),
    );
  }

  Color _parseColor(String color) {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  String? _validateAmount(String? v) {
    if (v == null || v.isEmpty) return 'Enter an amount';
    if (double.tryParse(v) == null) return 'Enter a valid number';
    if (double.parse(v) <= 0) return 'Amount must be greater than 0';
    return null;
  }

  void _showAddGoalDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final contributionCtrl = TextEditingController();
    String category = 'Other';
    String priority = 'medium';
    final currency = context.read<AuthProvider>().user?.currency;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('New Savings Goal'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Goal Name', hintText: 'e.g. New Laptop'), textCapitalization: TextCapitalization.words, validator: (v) => v == null || v.trim().isEmpty ? 'Enter a goal name' : null),
            const SizedBox(height: 12),
            TextFormField(controller: amountCtrl, decoration: InputDecoration(labelText: 'Target Amount', prefixText: CurrencyUtil.getPrefixText(currency)), keyboardType: TextInputType.number, validator: _validateAmount),
            const SizedBox(height: 12),
            TextFormField(controller: contributionCtrl, decoration: InputDecoration(labelText: 'Monthly Contribution', prefixText: CurrencyUtil.getPrefixText(currency), hintText: 'Optional'), keyboardType: TextInputType.number, validator: (v) {
              if (v == null || v.isEmpty) return null;
              if (double.tryParse(v) == null) return 'Enter a valid number';
              if (double.parse(v) <= 0) return 'Amount must be greater than 0';
              return null;
            }),
            const SizedBox(height: 12),
            DropdownButtonFormField(value: category, items: ['Emergency Fund', 'Travel', 'Education', 'Shopping', 'Investment', 'Debt Payment', 'Retirement', 'Other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => category = v ?? 'Other', decoration: const InputDecoration(labelText: 'Category')),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (!formKey.currentState!.validate()) return;
          final success = await context.read<GoalProvider>().createGoal({
            'title': nameCtrl.text,
            'targetAmount': double.parse(amountCtrl.text),
            'monthlyContribution': double.tryParse(contributionCtrl.text) ?? 0,
            'category': category,
            'priority': priority,
          });
          if (success && ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Create Goal')),
      ],
    ));
  }

  void _showContributeDialog(BuildContext context, GoalModel goal, GoalProvider provider) {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final currency = context.read<AuthProvider>().user?.currency;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Add to "${goal.title}"'),
      content: Form(
        key: formKey,
        child: TextFormField(controller: amountCtrl, decoration: InputDecoration(labelText: 'Amount', prefixText: CurrencyUtil.getPrefixText(currency)), keyboardType: TextInputType.number, autofocus: true, validator: _validateAmount),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (!formKey.currentState!.validate()) return;
          final success = await provider.addContribution(goal.id, double.parse(amountCtrl.text));
          if (success && ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Add')),
      ],
    ));
  }

  void _showEditGoalDialog(BuildContext context, GoalModel goal) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: goal.title);
    final amountCtrl = TextEditingController(text: goal.targetAmount.toString());
    final contributionCtrl = TextEditingController(text: goal.monthlyContribution.toString());
    String categoryValue = goal.category;
    final currency = context.read<AuthProvider>().user?.currency;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Goal'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Goal Name'), textCapitalization: TextCapitalization.words, validator: (v) => v == null || v.trim().isEmpty ? 'Enter a goal name' : null),
            const SizedBox(height: 12),
            TextFormField(controller: amountCtrl, decoration: InputDecoration(labelText: 'Target Amount', prefixText: CurrencyUtil.getPrefixText(currency)), keyboardType: TextInputType.number, validator: _validateAmount),
            const SizedBox(height: 12),
            TextFormField(controller: contributionCtrl, decoration: InputDecoration(labelText: 'Monthly Contribution', prefixText: CurrencyUtil.getPrefixText(currency)), keyboardType: TextInputType.number, validator: (v) {
              if (v == null || v.isEmpty) return null;
              if (double.tryParse(v) == null) return 'Enter a valid number';
              if (double.parse(v) <= 0) return 'Amount must be greater than 0';
              return null;
            }),
            const SizedBox(height: 12),
            DropdownButtonFormField(value: categoryValue, items: ['Emergency Fund', 'Travel', 'Education', 'Shopping', 'Investment', 'Debt Payment', 'Retirement', 'Other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => categoryValue = v ?? 'Other', decoration: const InputDecoration(labelText: 'Category')),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final success = await context.read<GoalProvider>().updateGoal(goal.id, {
            'title': nameCtrl.text,
            'targetAmount': double.parse(amountCtrl.text),
            'monthlyContribution': double.tryParse(contributionCtrl.text) ?? 0,
            'category': categoryValue,
          });
          if (success && ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Save')),
      ],
    ));
  }

  void _confirmDelete(BuildContext context, String goalId, GoalProvider provider) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Goal?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () async {
          await provider.deleteGoal(goalId);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
      ],
    ));
  }

  IconData _getGoalIcon(String icon) {
    const icons = {'savings': Icons.savings, 'account_balance': Icons.account_balance, 'card_giftcard': Icons.card_giftcard, 'flight': Icons.flight, 'school': Icons.school, 'shopping_cart': Icons.shopping_cart, 'home': Icons.home, 'directions_car': Icons.directions_car};
    return icons[icon] ?? Icons.flag;
  }
}
