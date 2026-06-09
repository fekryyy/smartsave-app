import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../../data/models/subscription_model.dart';
import '../../app/app.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> with RouteAware {
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
    context.read<SubscriptionProvider>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final authProvider = context.watch<AuthProvider>();
    final format = CurrencyUtil.getFormat(authProvider.user?.currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddEditSheet(context, null, format, isDark)),
        ],
      ),
      body: subProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => subProvider.loadAll(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(children: [
                      _buildSummaryRow(context, subProvider, format, isDark),
                      const SizedBox(height: 20),
                    ]),
                  )),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final sub = subProvider.subscriptions[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: RepaintBoundary(child: _buildSubCard(context, sub, subProvider, format, isDark)),
                        );
                      },
                      childCount: subProvider.subscriptions.length,
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditSheet(context, null, format, isDark),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, SubscriptionProvider provider, NumberFormat format, bool isDark) {
    return Row(children: [
      Expanded(child: _gradientCard(
        context, 'Monthly', format.format(provider.monthlyTotal),
        AppColors.primary, Icons.calendar_month, isDark,
      )),
      const SizedBox(width: 12),
      Expanded(child: _gradientCard(
        context, 'Yearly', format.format(provider.yearlyTotal),
        AppColors.success, Icons.calendar_view_month, isDark,
      )),
    ]);
  }

  Widget _gradientCard(BuildContext context, String label, String value, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 12),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.white : null)),
        Text(label, style: TextStyle(color: AppColors.grey500, fontSize: 12)),
      ]),
    );
  }

  Widget _buildSubCard(BuildContext context, SubscriptionModel sub, SubscriptionProvider provider, NumberFormat format, bool isDark) {
    final color = sub.isActive ? AppColors.primary : AppColors.grey500;
    return Dismissible(
      key: Key(sub.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Delete Subscription'),
          content: Text('Remove ${sub.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
          ],
        ));
        if (confirm == true) await provider.delete(sub.id);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.grey100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.subscriptions_outlined, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(sub.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  if (sub.category != 'Other')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(sub.category, style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                ]),
                if (sub.description.isNotEmpty)
                  Text(sub.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey500), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              GestureDetector(
                onTap: () => provider.update(sub.id, {'isActive': !sub.isActive}),
                child: Container(
                  width: 42, height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: sub.isActive ? AppColors.success : AppColors.grey500.withValues(alpha: 0.3),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: sub.isActive ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 20, height: 20,
                      margin: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Text(format.format(sub.amount), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(width: 4),
              Text('/${sub.renewalFrequency}', style: TextStyle(color: AppColors.grey500, fontSize: 12)),
              const Spacer(),
              if (sub.nextBillingDate != null) ...[
                Icon(Icons.date_range, size: 12, color: AppColors.grey500),
                const SizedBox(width: 4),
                Text('Next: ${DateFormat('MMM dd').format(sub.nextBillingDate!)}', style: TextStyle(color: AppColors.grey500, fontSize: 11)),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  void _showAddEditSheet(BuildContext context, SubscriptionModel? existing, NumberFormat format, bool isDark) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(text: existing?.amount.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final billingDateCtrl = TextEditingController(text: existing?.billingDate.toString() ?? '1');
    final currencyCtrl = TextEditingController(text: existing?.currency ?? 'USD');

    String frequency = existing?.renewalFrequency ?? 'monthly';
    String category = existing?.category ?? 'Other';
    bool reminder = existing?.reminderEnabled ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) => Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollController,
              children: [
                Center(child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.grey500.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                )),
                Text(existing == null ? 'Add Subscription' : 'Edit Subscription',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                  style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 14),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                  style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 14),
                TextField(controller: billingDateCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Billing Day of Month', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                  style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Renewal Frequency', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                  items: ['weekly', 'monthly', 'quarterly', 'yearly'].map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1)))).toList(),
                  onChanged: (v) => setSheetState(() => frequency = v ?? 'monthly'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                  items: ['Streaming', 'Software', 'Cloud', 'Fitness', 'Food', 'Music', 'News', 'Other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setSheetState(() => category = v ?? 'Other'),
                ),
                const SizedBox(height: 14),
                TextField(controller: descCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                  style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Payment Reminder'),
                  value: reminder,
                  onChanged: (v) => setSheetState(() => reminder = v),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    final data = {
                      'name': nameCtrl.text,
                      'amount': double.tryParse(amountCtrl.text) ?? 0,
                      'billingDate': int.tryParse(billingDateCtrl.text) ?? 1,
                      'renewalFrequency': frequency,
                      'category': category,
                      'description': descCtrl.text,
                      'currency': currencyCtrl.text,
                      'reminderEnabled': reminder,
                    };
                    bool success;
                    if (existing == null) {
                      success = await context.read<SubscriptionProvider>().create(data);
                    } else {
                      success = await context.read<SubscriptionProvider>().update(existing.id, data);
                    }
                    if (success && ctx.mounted) Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(existing == null ? 'Add Subscription' : 'Save Changes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
