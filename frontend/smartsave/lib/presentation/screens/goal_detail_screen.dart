import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../../presentation/providers/goal_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../data/models/goal_model.dart';

class GoalDetailScreen extends StatelessWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    final goalProvider = context.watch<GoalProvider>();
    final goal = goalProvider.goals.where((g) => g.id == goalId).firstOrNull;
    final authProvider = context.watch<AuthProvider>();
    final format = CurrencyUtil.getFormat(authProvider.user?.currency);

    if (goal == null) {
      return Scaffold(appBar: AppBar(title: const Text('Goal')), body: const Center(child: Text('Goal not found')));
    }

    final progress = goal.targetAmount > 0 ? goal.currentAmount / goal.targetAmount : 0.0;

    return Scaffold(
      appBar: AppBar(title: Text(goal.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Progress circle
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.grey100)),
            child: Column(children: [
              CircularPercentIndicator(
                radius: 80,
                lineWidth: 12,
                percent: progress.clamp(0.0, 1.0),
                center: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${goal.progress.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('complete', style: Theme.of(context).textTheme.bodySmall),
                ]),
                progressColor: Color(int.parse(goal.color.replaceFirst('#', '0xFF'))),
                backgroundColor: AppColors.grey100,
                circularStrokeCap: CircularStrokeCap.round,
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _buildInfo(format.format(goal.currentAmount), 'Saved', context),
                _buildInfo(format.format(goal.targetAmount), 'Target', context),
                _buildInfo(format.format(goal.remaining), 'Remaining', context),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // Details
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey100)),
            child: Column(children: [
              _buildDetailRow('Category', goal.category, context),
              _buildDetailRow('Priority', goal.priority.toUpperCase(), context),
              _buildDetailRow('Monthly Contribution', goal.monthlyContribution > 0 ? format.format(goal.monthlyContribution) : 'Not set', context),
              if (goal.targetDate != null) _buildDetailRow('Target Date', DateFormat('MMM dd, yyyy').format(goal.targetDate!), context),
              if (goal.estimatedCompletionDate != null) _buildDetailRow('Est. Completion', DateFormat('MMM yyyy').format(goal.estimatedCompletionDate!), context),
              if (goal.description.isNotEmpty) _buildDetailRow('Notes', goal.description, context),
            ]),
          ),
          const SizedBox(height: 24),

          // Add contribution
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Contribution'),
              onPressed: () => _showContributeDialog(context, goal),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildInfo(String value, String label, BuildContext context) {
    return Column(children: [Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text(label, style: Theme.of(context).textTheme.bodySmall)]);
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: Theme.of(context).textTheme.bodyMedium), Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))]));
  }

  String? _validateAmount(String? v) {
    if (v == null || v.isEmpty) return 'Enter an amount';
    if (double.tryParse(v) == null) return 'Enter a valid number';
    if (double.parse(v) <= 0) return 'Amount must be greater than 0';
    return null;
  }

  void _showContributeDialog(BuildContext context, GoalModel goal) {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final currency = context.read<AuthProvider>().user?.currency;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Contribution'),
      content: Form(
        key: formKey,
        child: TextFormField(controller: amountCtrl, decoration: InputDecoration(labelText: 'Amount', prefixText: CurrencyUtil.getPrefixText(currency)), keyboardType: TextInputType.number, autofocus: true, validator: _validateAmount),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (!formKey.currentState!.validate()) return;
          final success = await context.read<GoalProvider>().addContribution(goal.id, double.parse(amountCtrl.text));
          if (success && ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Add')),
      ],
    ));
  }
}
