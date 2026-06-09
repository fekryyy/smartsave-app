import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_util.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../presentation/providers/transaction_provider.dart';
import '../../presentation/providers/recurring_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../widgets/fintech/fintech_amount_card.dart';
import '../widgets/fintech/category_selector.dart';
import '../widgets/fintech/payment_selector.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  String _selectedCategory = 'Food';
  String _selectedPayment = 'Cash';
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  String _recurringFrequency = 'monthly';
  DateTime? _recurringEndDate;
  File? _receiptImage;
  bool _scanning = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isRecurring) {
      final success = await context.read<RecurringProvider>().createRecurring({
        'type': 'expense',
        'amount': double.parse(_amountController.text),
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'frequency': _recurringFrequency,
        'startDate': _selectedDate.toIso8601String(),
        'endDate': _recurringEndDate?.toIso8601String(),
        'paymentMethod': _selectedPayment,
      });
      if (success && mounted) {
        setState(() => _showSuccess = true);
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.pop(context);
      }
    } else {
      final success = await context.read<TransactionProvider>().addTransaction({
        'type': 'expense',
        'amount': double.parse(_amountController.text),
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'date': _selectedDate.toIso8601String(),
        'paymentMethod': _selectedPayment,
      });
      if (success && mounted) {
        setState(() => _showSuccess = true);
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.pop(context);
      }
    }
  }

  Future<void> _scanReceipt(ImageSource source) async {
    final xFile = await _picker.pickImage(source: source, maxWidth: 2048);
    if (xFile == null) return;
    setState(() { _receiptImage = File(xFile.path); _scanning = true; });
    try {
      final result = await ApiClient().uploadFile(ApiConstants.ocrScan, xFile.path, 'receipt');
      final data = result.dataOrThrow['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        if (data['amount'] != null) _amountController.text = data['amount'].toString();
        if (data['category'] != null) _selectedCategory = data['category'] as String;
        if (data['merchant'] != null && _descriptionController.text.isEmpty) _descriptionController.text = data['merchant'] as String;
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt scan failed. Enter details manually.')));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary, surface: Colors.white, onSurface: Color(0xFF0F172A))), child: child!),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  IconData _getIcon(String cat) {
    switch (cat) {
      case 'Food': return Icons.restaurant_rounded;
      case 'Transportation': return Icons.directions_car_rounded;
      case 'Shopping': return Icons.shopping_bag_rounded;
      case 'Bills': return Icons.receipt_long_rounded;
      case 'Entertainment': return Icons.movie_rounded;
      case 'Health': return Icons.favorite_rounded;
      case 'Education': return Icons.school_rounded;
      case 'Travel': return Icons.flight_rounded;
      default: return Icons.more_horiz_rounded;
    }
  }

  IconData _paymentIcon(String m) {
    switch (m) {
      case 'Cash': return Icons.money_rounded;
      case 'Credit Card': return Icons.credit_card_rounded;
      case 'Debit Card': return Icons.credit_score_rounded;
      case 'Bank Transfer': return Icons.account_balance_rounded;
      case 'Mobile Wallet': return Icons.phone_android_rounded;
      default: return Icons.payment_rounded;
    }
  }

  String? _validateAmount(String? v) {
    if (v == null || v.isEmpty) return 'Enter an amount';
    if (double.tryParse(v) == null) return 'Enter a valid number';
    if (double.parse(v) <= 0) return 'Amount must be greater than 0';
    return null;
  }

  _mapCategoryColors() {
    return { for (var c in AppConstants.expenseCategories) c : Color(AppConstants.categoryColors[c] ?? 0xFF9CA3AF) };
  }

  _mapCategoryIcons() {
    return { for (var c in AppConstants.expenseCategories) c : _getIcon(c) };
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final currency = context.watch<AuthProvider>().user?.currency;
    final prefix = CurrencyUtil.getPrefixText(currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC);
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintCol = isDark ? AppColors.grey500 : const Color(0xFF94A3B8);
    final sectionCol = isDark ? AppColors.grey400 : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(children: [
          Form(
            key: _formKey,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // === HEADER ===
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Add Expense', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: textCol, letterSpacing: -0.5)),
                          const SizedBox(height: 2),
                          Text('Track your spending', style: TextStyle(fontSize: 13, color: hintCol)),
                        ]),
                        Row(children: [
                          GestureDetector(
                            onTap: () async {
                              final src = await showModalBottomSheet<ImageSource>(
                                context: context,
                                builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  ListTile(leading: const Icon(Icons.camera_alt_rounded), title: const Text('Camera'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
                                  ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
                                ])),
                              );
                              if (src != null) _scanReceipt(src);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _receiptImage != null ? AppColors.success.withValues(alpha: 0.15) : (isDark ? AppColors.darkCardAlt : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _scanning
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(_receiptImage != null ? Icons.receipt_long_rounded : Icons.camera_alt_outlined, size: 20,
                                      color: _receiptImage != null ? AppColors.success : (isDark ? AppColors.grey400 : AppColors.grey500)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? AppColors.darkCardAlt : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.close_rounded, size: 20, color: isDark ? AppColors.grey400 : AppColors.grey500)),
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 24),

                      // === AMOUNT CARD ===
                      FintechAmountCard(
                        controller: _amountController,
                        label: 'How much did you spend?',
                        prefix: prefix,
                        validator: _validateAmount,
                      ),
                      const SizedBox(height: 24),

                      // === CATEGORY ===
                      Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sectionCol, letterSpacing: 0.3)),
                      const SizedBox(height: 12),
                      CategorySelector(
                        categories: AppConstants.expenseCategories,
                        selected: _selectedCategory,
                        onChanged: (v) => setState(() => _selectedCategory = v),
                        icons: _mapCategoryIcons(),
                        categoryColors: _mapCategoryColors(),
                      ),
                      const SizedBox(height: 24),

                      // === PAYMENT METHOD ===
                      Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sectionCol, letterSpacing: 0.3)),
                      const SizedBox(height: 12),
                      PaymentMethodSelector(
                        methods: AppConstants.paymentMethods,
                        selected: _selectedPayment,
                        onChanged: (v) => setState(() => _selectedPayment = v),
                        iconBuilder: _paymentIcon,
                      ),
                      const SizedBox(height: 24),

                      // === RECURRING TOGGLE ===
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Recurring', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textCol)),
                            subtitle: _isRecurring ? Text('Every $_recurringFrequency', style: TextStyle(fontSize: 12, color: hintCol)) : null,
                            secondary: const Icon(Icons.repeat_rounded, size: 20, color: AppColors.primary),
                            value: _isRecurring,
                            activeThumbColor: AppColors.primary,
                            onChanged: (v) => setState(() => _isRecurring = v),
                          ),
                          if (_isRecurring) ...[
                            Divider(height: 1, indent: 0, color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(children: [
                                Text('Frequency', style: TextStyle(fontSize: 13, color: sectionCol)),
                                const Spacer(),
                                DropdownButton<String>(
                                  value: _recurringFrequency,
                                  underline: const SizedBox(),
                                  style: TextStyle(fontSize: 14, color: textCol),
                                  dropdownColor: cardBg,
                                  items: ['daily', 'weekly', 'monthly', 'yearly'].map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1)))).toList(),
                                  onChanged: (v) { if (v != null) setState(() => _recurringFrequency = v); },
                                ),
                              ]),
                            ),
                            Divider(height: 1, indent: 0, color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: _recurringEndDate ?? DateTime.now().add(const Duration(days: 365)),
                                  firstDate: DateTime.now(), lastDate: DateTime(2035),
                                  builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary, surface: Colors.white, onSurface: Color(0xFF0F172A))), child: child!),
                                );
                                if (picked != null) setState(() => _recurringEndDate = picked);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(children: [
                                  Icon(Icons.event_rounded, size: 20, color: hintCol),
                                  const SizedBox(width: 12),
                                  Text(_recurringEndDate != null ? 'Until ${_formatDate(_recurringEndDate!)}' : 'No end date (ongoing)', style: TextStyle(fontSize: 14, color: _recurringEndDate != null ? textCol : hintCol)),
                                  const Spacer(),
                                  Icon(Icons.chevron_right_rounded, size: 18, color: hintCol),
                                ]),
                              ),
                            ),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 24),

                      // === DETAILS CARD ===
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(children: [
                          Row(children: [
                            Icon(Icons.note_outlined, size: 20, color: hintCol),
                            const SizedBox(width: 12),
                            Expanded(child: TextField(
                              controller: _descriptionController,
                              style: TextStyle(fontSize: 15, color: textCol),
                              decoration: InputDecoration(
                                hintText: 'Optional note', hintStyle: TextStyle(color: hintCol, fontSize: 15),
                                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14), isDense: true,
                              ),
                              maxLines: 1,
                            )),
                          ]),
                          Divider(height: 1, indent: 32, color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                Icon(Icons.calendar_today_rounded, size: 20, color: hintCol),
                                const SizedBox(width: 12),
                                Text(_formatDate(_selectedDate), style: TextStyle(fontSize: 15, color: textCol)),
                                const Spacer(),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isDark ? AppColors.darkCardAlt : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.chevron_right_rounded, size: 18, color: hintCol)),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      // === ERROR ===
                      if (txProvider.errorMessage != null)
                        Container(width: double.infinity, padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.danger.withValues(alpha: 0.2))),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                            const SizedBox(width: 10),
                            Expanded(child: Text(txProvider.errorMessage!, style: const TextStyle(fontSize: 13, color: AppColors.danger))),
                          ])),
                      SizedBox(height: txProvider.errorMessage != null ? 12 : 0),

                      // === SUBMIT ===
                      SizedBox(width: double.infinity, height: 56,
                        child: ElevatedButton(
                          onPressed: txProvider.isLoading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.danger.withValues(alpha: 0.4),
                            disabledForegroundColor: Colors.white60,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            shadowColor: AppColors.danger.withValues(alpha: 0.3),
                          ),
                          child: txProvider.isLoading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.add_circle_outline, size: 20),
                                  SizedBox(width: 8),
                                  Text('Add Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ]),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              )),
            ]),
          ),

          // === SUCCESS OVERLAY ===
          if (_showSuccess)
            Positioned.fill(
              child: Container(
                color: bg.withValues(alpha: 0.95),
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    builder: (ctx, value, _) => Transform.scale(
                      scale: value,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 8))]),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 48)),
                        const SizedBox(height: 20),
                        Text('Expense Added!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textCol)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
