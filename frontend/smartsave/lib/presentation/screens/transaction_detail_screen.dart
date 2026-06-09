import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_util.dart';
import '../../presentation/providers/transaction_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../data/models/transaction_model.dart';
import '../widgets/fintech/payment_method_badge.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionModel? _transaction;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final txProvider = context.read<TransactionProvider>();
    final found = txProvider.transactions.where((t) => t.id == widget.transactionId).firstOrNull;
    if (found != null) {
      setState(() { _transaction = found; _loading = false; });
    } else {
      txProvider.loadTransactions().then((_) {
        if (mounted) {
          setState(() {
            _transaction = txProvider.transactions.where((t) => t.id == widget.transactionId).firstOrNull;
            _loading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final format = CurrencyUtil.getFormat(authProvider.user?.currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Transaction Details'), backgroundColor: bg, surfaceTintColor: Colors.transparent, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transaction == null
              ? const Center(child: Text('Transaction not found'))
              : _buildContent(_transaction!, format, isDark),
    );
  }

  Widget _buildContent(TransactionModel tx, NumberFormat format, bool isDark) {
    final isIncome = tx.type == 'income';
    final color = isIncome ? AppColors.success : AppColors.danger;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintCol = isDark ? AppColors.grey500 : AppColors.grey400;
    final pmColor = AppColors.paymentMethodColors[tx.paymentMethod] ?? AppColors.paymentOther;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Amount Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(children: [
            Text('${isIncome ? 'Income' : 'Expense'}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Text('${isIncome ? '+' : '-'}${format.format(tx.amount)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            PaymentMethodBadge(method: tx.paymentMethod, iconSize: 14, fontSize: 12),
          ]),
        ),
        const SizedBox(height: 24),

        // Detail Rows
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0))),
          child: Column(children: [
            _detailRow(Icons.category_outlined, 'Category', tx.category, textCol, hintCol),
            const Divider(height: 24),
            _detailRow(Icons.description_outlined, 'Description', tx.description.isEmpty ? 'No description' : tx.description, textCol, hintCol),
            const Divider(height: 24),
            _detailRow(Icons.calendar_today_rounded, 'Date', DateFormat('MMM dd, yyyy').format(tx.date), textCol, hintCol),
            const Divider(height: 24),
            _detailRowWithWidget('Payment Method', Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(AppConstants.paymentMethodIcons[tx.paymentMethod] ?? Icons.payment_rounded, size: 18, color: pmColor),
              const SizedBox(width: 8),
              Text(tx.paymentMethod, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: pmColor)),
            ]), hintCol),
            if (tx.isRecurring) ...[
              const Divider(height: 24),
              _detailRow(Icons.repeat_rounded, 'Recurring', tx.recurringFrequency ?? 'Yes', textCol, hintCol),
            ],
          ]),
        ),
        const SizedBox(height: 24),

        // Tags
        if (tx.tags.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tags', style: TextStyle(fontSize: 13, color: hintCol)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 6, children: tx.tags.map((tag) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(tag, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
              )).toList()),
            ]),
          ),

        if (tx.receiptUrl != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0))),
            child: Row(children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text('Receipt attached', style: TextStyle(fontSize: 14, color: textCol))),
              const Icon(Icons.chevron_right, color: AppColors.grey400),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color textCol, Color hintCol) {
    return Row(children: [
      Icon(icon, size: 20, color: hintCol),
      const SizedBox(width: 12),
      Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 13, color: hintCol))),
      Expanded(flex: 3, child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textCol), textAlign: TextAlign.end)),
    ]);
  }

  Widget _detailRowWithWidget(String label, Widget trailing, Color hintCol) {
    return Row(children: [
      Icon(Icons.payment_rounded, size: 20, color: hintCol),
      const SizedBox(width: 12),
      Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 13, color: hintCol))),
      Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: trailing)),
    ]);
  }
}
