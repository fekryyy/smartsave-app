import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../providers/net_worth_provider.dart';
import '../providers/auth_provider.dart';
import '../../data/models/net_worth_model.dart';
import '../../app/app.dart';

class NetWorthScreen extends StatefulWidget {
  const NetWorthScreen({super.key});
  @override
  State<NetWorthScreen> createState() => _NetWorthScreenState();
}

class _NetWorthScreenState extends State<NetWorthScreen> with RouteAware {
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
    context.read<NetWorthProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final nwProvider = context.watch<NetWorthProvider>();
    final authProvider = context.watch<AuthProvider>();
    final format = CurrencyUtil.getFormat(authProvider.user?.currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nw = nwProvider.netWorth;

    return Scaffold(
      appBar: AppBar(title: const Text('Net Worth')),
      body: nwProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => nwProvider.load(),
              child: ListView(padding: const EdgeInsets.all(20), children: [
                _buildNetWorthCard(context, nw, format, isDark),
                const SizedBox(height: 24),
                if (nwProvider.history.isNotEmpty) _buildChart(context, nwProvider.history, format, isDark),
                const SizedBox(height: 24),
                _buildSection(context, 'Assets', nw?.entries.lastOrNull?.assets ?? {}, AppColors.success, format, isDark,
                  {'cash':'Cash','bankAccounts':'Bank Accounts','savings':'Savings','investments':'Investments','otherAssets':'Other Assets'},
                  {'cash':Icons.money,'bankAccounts':Icons.account_balance,'savings':Icons.savings,'investments':Icons.trending_up,'otherAssets':Icons.inventory_2}),
                const SizedBox(height: 20),
                _buildSection(context, 'Liabilities', nw?.entries.lastOrNull?.liabilities ?? {}, AppColors.danger, format, isDark,
                  {'creditCardDebt':'Credit Card Debt','loans':'Loans','personalDebt':'Personal Debt','mortgage':'Mortgage'},
                  {'creditCardDebt':Icons.credit_card,'loans':Icons.account_balance,'personalDebt':Icons.person,'mortgage':Icons.home}),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _showAddEntrySheet(context, nwProvider, format, isDark),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Entry'),
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
                const SizedBox(height: 20),
              ]),
            ),
    );
  }

  Widget _buildNetWorthCard(BuildContext context, NetWorthModel? nw, NumberFormat format, bool isDark) {
    final netWorth = nw?.netWorth ?? 0;
    final isPos = netWorth >= 0;
    final color = isPos ? AppColors.success : AppColors.danger;
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(children: [
        Text('Net Worth', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.grey500)),
        const SizedBox(height: 8),
        Text(format.format(netWorth.abs()), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isPos ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 16),
          const SizedBox(width: 4),
          Text(isPos ? 'Positive' : 'Negative', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _stat(context, 'Total Assets', format.format(nw?.totalAssets ?? 0), AppColors.success),
          const SizedBox(width: 12),
          _stat(context, 'Total Liabilities', format.format(nw?.totalLiabilities ?? 0), AppColors.danger),
        ]),
      ]),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
        Text(label, style: TextStyle(color: AppColors.grey500, fontSize: 10)),
      ])));
  }

  Widget _buildChart(BuildContext context, List<Map<String, dynamic>> history, NumberFormat format, bool isDark) {
    final values = history.map((h) => (h['netWorth'] as num?)?.toDouble() ?? 0).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).clamp(1, double.infinity);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Net Worth History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Container(height: 140, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(values.length, (i) {
          final ratio = ((values[i] - minVal) / range);
          final isPos = values[i] >= 0;
          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              height: (ratio * 100).clamp(4, 100.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isPos ? [AppColors.success, AppColors.success.withValues(alpha: 0.6)] : [AppColors.danger, AppColors.danger.withValues(alpha: 0.6)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(DateFormat('MMM').format(DateTime.parse(history[i]['date'] as String)), style: TextStyle(fontSize: 8, color: AppColors.grey500)),
          ])));
        })),
      ),
    ]);
  }

  Widget _buildSection(BuildContext context, String title, Map<String, double> items, Color color, NumberFormat format, bool isDark, Map<String, String> labels, Map<String, IconData> icons) {
    final total = items.values.fold(0.0, (a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(title == 'Assets' ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 18),
        const SizedBox(width: 8),
        Text('$title  \u2022 ${format.format(total)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      ...items.entries.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.grey100)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icons[e.key] ?? Icons.circle, color: color, size: 16)),
          const SizedBox(width: 12),
          Expanded(child: Text(labels[e.key] ?? e.key, style: Theme.of(context).textTheme.bodyMedium)),
          Text(format.format(e.value), style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ]),
      )),
    ]);
  }

  void _showAddEntrySheet(BuildContext context, NetWorthProvider provider, NumberFormat format, bool isDark) {
    final last = provider.netWorth?.entries.lastOrNull;
    final lastAssets = last?.assets ?? {};
    final lastLiabilities = last?.liabilities ?? {};
    final controllers = {
      'Cash': TextEditingController(text: (lastAssets['cash'] ?? 0) > 0 ? lastAssets['cash'].toString() : ''),
      'Bank Accounts': TextEditingController(text: (lastAssets['bankAccounts'] ?? 0) > 0 ? lastAssets['bankAccounts'].toString() : ''),
      'Savings': TextEditingController(text: (lastAssets['savings'] ?? 0) > 0 ? lastAssets['savings'].toString() : ''),
      'Investments': TextEditingController(text: (lastAssets['investments'] ?? 0) > 0 ? lastAssets['investments'].toString() : ''),
      'Other Assets': TextEditingController(text: (lastAssets['otherAssets'] ?? 0) > 0 ? lastAssets['otherAssets'].toString() : ''),
      'Credit Card Debt': TextEditingController(text: (lastLiabilities['creditCardDebt'] ?? 0) > 0 ? lastLiabilities['creditCardDebt'].toString() : ''),
      'Loans': TextEditingController(text: (lastLiabilities['loans'] ?? 0) > 0 ? lastLiabilities['loans'].toString() : ''),
      'Personal Debt': TextEditingController(text: (lastLiabilities['personalDebt'] ?? 0) > 0 ? lastLiabilities['personalDebt'].toString() : ''),
      'Mortgage': TextEditingController(text: (lastLiabilities['mortgage'] ?? 0) > 0 ? lastLiabilities['mortgage'].toString() : ''),
    };
    final assetKeys = ['Cash', 'Bank Accounts', 'Savings', 'Investments', 'Other Assets'];
    final assetMapKeys = ['cash', 'bankAccounts', 'savings', 'investments', 'otherAssets'];
    final liabilityKeys = ['Credit Card Debt', 'Loans', 'Personal Debt', 'Mortgage'];
    final liabilityMapKeys = ['creditCardDebt', 'loans', 'personalDebt', 'mortgage'];
    final icons = {
      'Cash': Icons.money, 'Bank Accounts': Icons.account_balance, 'Savings': Icons.savings,
      'Investments': Icons.trending_up, 'Other Assets': Icons.inventory_2,
      'Credit Card Debt': Icons.credit_card, 'Loans': Icons.account_balance,
      'Personal Debt': Icons.person, 'Mortgage': Icons.home,
    };

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(controller: scrollController, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.grey500.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            Text('Add Entry', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Text('Assets', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...List.generate(assetKeys.length, (i) => _field(assetKeys[i], controllers[assetKeys[i]]!, icons[assetKeys[i]]!, AppColors.success)),
            const SizedBox(height: 16),
            Text('Liabilities', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...List.generate(liabilityKeys.length, (i) => _field(liabilityKeys[i], controllers[liabilityKeys[i]]!, icons[liabilityKeys[i]]!, AppColors.danger)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final data = {
                  'assets': {for (int i = 0; i < assetKeys.length; i++) assetMapKeys[i]: double.tryParse(controllers[assetKeys[i]]!.text) ?? 0},
                  'liabilities': {for (int i = 0; i < liabilityKeys.length; i++) liabilityMapKeys[i]: double.tryParse(controllers[liabilityKeys[i]]!.text) ?? 0},
                };
                final success = await provider.addEntry(data);
                if (success && ctx.mounted) Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Save Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(
      controller: ctrl, keyboardType: TextInputType.number,
      decoration: InputDecoration(prefixIcon: Icon(icon, color: color, size: 18), labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    ));
  }
}
