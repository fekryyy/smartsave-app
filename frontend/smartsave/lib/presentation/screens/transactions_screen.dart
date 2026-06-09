import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_util.dart';
import '../../presentation/providers/transaction_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../data/models/transaction_model.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/fintech/payment_method_badge.dart';
import '../../services/download_service.dart';
import '../../app/routes.dart';
import '../../app/app.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  String? _selectedType;
  String? _selectedPaymentMethod;
  String? _selectedCategory;
  final _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final _downloadService = DownloadService();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedType = _tabController.index == 0 ? null : (_tabController.index == 1 ? 'income' : 'expense');
        });
        _load();
      }
    });
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
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _load();
  }

  void _load() {
    context.read<TransactionProvider>().loadTransactions(
      type: _selectedType,
      paymentMethod: _selectedPaymentMethod,
      category: _selectedCategory,
      startDate: _startDate?.toIso8601String(),
      endDate: _endDate?.toIso8601String(),
    );
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      final period = _startDate != null && _endDate != null ? 'custom' : 'monthly';
      if (format == 'pdf') {
        await _downloadService.exportPDF(period: period);
      } else if (format == 'csv') {
        await _downloadService.exportCSV(period: period);
      } else if (format == 'excel') {
        await _downloadService.exportExcel(period: period);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exported successfully')));
      }
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
    final txProvider = context.watch<TransactionProvider>();
    final authProvider = context.watch<AuthProvider>();
    final format = CurrencyUtil.getFormat(authProvider.user?.currency);
    final transactions = txProvider.transactions;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintCol = isDark ? AppColors.grey500 : AppColors.grey400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_rounded),
            onSelected: _export,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, size: 18), SizedBox(width: 8), Text('Export PDF')])),
              const PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.table_chart, size: 18), SizedBox(width: 8), Text('Export CSV')])),
              const PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.grid_on, size: 18), SizedBox(width: 8), Text('Export Excel')])),
            ],
          ),
          if (_exporting) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
        ],
      ),
      body: Column(children: [
        TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'All'), Tab(text: 'Income'), Tab(text: 'Expenses')],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey400,
        ),
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search by category or description...',
              hintStyle: TextStyle(fontSize: 14, color: hintCol),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: hintCol),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: Icon(Icons.clear_rounded, size: 18, color: hintCol), onPressed: () { _searchController.clear(); _load(); })
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.darkCardAlt : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (_) => _load(),
          ),
        ),
        // Filter Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              // Payment Method Filter
              _filterChip(null, 'All', Icons.filter_list_rounded),
              ...AppConstants.paymentMethods.map((m) => _filterChip(m, m, AppConstants.paymentMethodIcons[m] ?? Icons.payment_rounded)),
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: AppColors.grey200),
              const SizedBox(width: 8),
              // Date Range
              _dateChip(context, isDark, hintCol),
            ]),
          ),
        ),
        // Category Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _catChip(null, 'All'),
              ...AppConstants.expenseCategories.map((c) => _catChip(c, c)),
            ]),
          ),
        ),
        Expanded(
          child: txProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : transactions.isEmpty
                  ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions', subtitle: 'Add your first transaction')
                  : RefreshIndicator(
                      onRefresh: () async => _load(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: transactions.length,
                        itemBuilder: (ctx, index) {
                          final tx = transactions[index];
                          return RepaintBoundary(child: _buildTransactionCard(tx, format));
                        },
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _dateChip(BuildContext context, bool isDark, Color hintCol) {
    final hasRange = _startDate != null || _endDate != null;
    final label = hasRange ? '${_startDate != null ? DateFormat('M/d').format(_startDate!) : '...'} - ${_endDate != null ? DateFormat('M/d').format(_endDate!) : '...'}' : 'Date';
    return GestureDetector(
      onTap: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          initialDateRange: _startDate != null && _endDate != null
              ? DateTimeRange(start: _startDate!, end: _endDate!)
              : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
          builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
        );
        if (range != null) {
          setState(() { _startDate = range.start; _endDate = range.end; });
          _load();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasRange ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasRange ? AppColors.primary.withValues(alpha: 0.4) : AppColors.grey200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.date_range_rounded, size: 14, color: hasRange ? AppColors.primary : hintCol),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: hasRange ? FontWeight.w600 : FontWeight.w500, color: hasRange ? AppColors.primary : AppColors.grey600)),
          if (hasRange) ...[
            const SizedBox(width: 4),
            GestureDetector(onTap: () { setState(() { _startDate = null; _endDate = null; }); _load(); }, child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary)),
          ],
        ]),
      ),
    );
  }

  Widget _filterChip(String? value, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == value;
    final color = value != null ? (AppColors.paymentMethodColors[value] ?? AppColors.paymentOther) : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() { _selectedPaymentMethod = isSelected ? null : value; _load(); }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? color.withValues(alpha: 0.5) : AppColors.grey200),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: isSelected ? color : AppColors.grey500),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? color : AppColors.grey600)),
          ]),
        ),
      ),
    );
  }

  Widget _catChip(String? value, String label) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() { _selectedCategory = isSelected ? null : value; _load(); }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.grey200),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? AppColors.primary : AppColors.grey600)),
        ),
      ),
    );
  }
  Widget _buildTransactionCard(TransactionModel tx, NumberFormat format) {
    final isIncome = tx.type == 'income';
    final color = isIncome ? AppColors.success : AppColors.danger;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.transactionDetail, arguments: tx.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey100)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(_getCategoryIcon(tx.category), color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(tx.category, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 6),
              PaymentMethodBadge(method: tx.paymentMethod),
              if (tx.isRecurring) ...[const SizedBox(width: 4), const Icon(Icons.repeat_rounded, size: 12, color: AppColors.primary)],
            ]),
            if (tx.description.isNotEmpty) Text(tx.description, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${isIncome ? '+' : '-'}${format.format(tx.amount)}', style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            Text(DateFormat('MMM dd, yyyy').format(tx.date), style: Theme.of(context).textTheme.bodySmall),
          ]),
        ]),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    const icons = {
      'Food': Icons.restaurant, 'Transportation': Icons.directions_car, 'Shopping': Icons.shopping_cart,
      'Bills': Icons.receipt_long, 'Entertainment': Icons.movie, 'Health': Icons.local_hospital,
      'Education': Icons.school, 'Travel': Icons.flight, 'Salary': Icons.account_balance,
      'Freelance': Icons.computer, 'Investment': Icons.trending_up, 'Gift': Icons.card_giftcard,
      'Refund': Icons.undo, 'Other': Icons.category,
    };
    return icons[category] ?? Icons.receipt;
  }
}
