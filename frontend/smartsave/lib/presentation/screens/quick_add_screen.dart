import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../providers/transaction_provider.dart';

class QuickAddScreen extends StatefulWidget {
  const QuickAddScreen({super.key});

  @override
  State<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<QuickAddScreen> with TickerProviderStateMixin {
  stt.SpeechToText? _speech;
  bool _isListening = false;
  String _voiceText = '';
  bool _voiceAvailable = false;

  int? _quickAmount;
  String? _quickCategory;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedType = 'expense';
  String _selectedCategory = 'Food';
  final DateTime _selectedDate = DateTime.now();

  bool _showForm = false;
  bool _showVoiceResult = false;
  Map<String, dynamic>? _parsedVoice;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _speech?.stop();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _ensureSpeechReady() async {
    if (_speech != null) return;
    try {
      _speech = stt.SpeechToText();
      final available = await _speech!.initialize();
      if (mounted) setState(() => _voiceAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _voiceAvailable = false);
    }
  }

  void _startListening() async {
    if (_isListening) return;
    await _ensureSpeechReady();
    if (!_voiceAvailable || _isListening) return;
    setState(() => _isListening = true);
    _speech!.listen(
      onResult: (result) {
        setState(() {
          _voiceText = result.recognizedWords;
          if (result.finalResult) {
            _isListening = false;
            _parseVoiceText(_voiceText);
          }
        });
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() {
    _speech?.stop();
    setState(() {
      _isListening = false;
      if (_voiceText.isNotEmpty) {
        _parseVoiceText(_voiceText);
      }
    });
  }

  void _parseVoiceText(String text) {
    final lower = text.toLowerCase();
    double amount = 0;
    String type = 'expense';
    String category = 'Food';
    String description = '';

    final spentMatch = RegExp(r'(?:spent|spend|paid|used|bought|purchased)\s+(\d+[.,]?\d*)\s+(?:on|for|at)\s+(.+)', caseSensitive: false).firstMatch(lower);
    final receivedMatch = RegExp(r'(?:received|got|earned|made|deposited)\s+(\d+[.,]?\d*)\s+(?:from|for|as)\s+(.+)', caseSensitive: false).firstMatch(lower);

    if (spentMatch != null) {
      type = 'expense';
      amount = double.parse(spentMatch.group(1)!.replaceAll(',', '.'));
      description = spentMatch.group(2)!.trim();
    } else if (receivedMatch != null) {
      type = 'income';
      amount = double.parse(receivedMatch.group(1)!.replaceAll(',', '.'));
      description = receivedMatch.group(2)!.trim();
    } else {
      final numMatch = RegExp(r'(\d+[.,]?\d*)').firstMatch(lower);
      if (numMatch != null) {
        amount = double.parse(numMatch.group(1)!.replaceAll(',', '.'));
        if (lower.contains('received') || lower.contains('got') || lower.contains('income') || lower.contains('salary')) {
          type = 'income';
        }
      }
    }

    if (amount > 0) {
      for (final cat in AppConstants.expenseCategories) {
        if (lower.contains(cat.toLowerCase())) {
          category = cat;
          break;
        }
      }
      if (type == 'income') {
        for (final src in AppConstants.incomeSources) {
          if (lower.contains(src.toLowerCase())) {
            category = src;
            break;
          }
        }
      }

      setState(() {
        _parsedVoice = {
          'amount': amount,
          'category': category,
          'type': type,
          'description': description,
          'date': DateTime.now(),
        };
        _showVoiceResult = true;
        _showForm = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not parse amount from voice. Try saying "spent 50 on food".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openQuickForm(String type) {
    setState(() {
      _selectedType = type;
      _showForm = true;
      _showVoiceResult = false;
      _quickAmount = null;
      if (type == 'income') {
        _selectedCategory = AppConstants.incomeSources.first;
      } else {
        _selectedCategory = AppConstants.expenseCategories.first;
      }
    });
  }

  Future<void> _saveQuickTransaction() async {
    final amount = _quickAmount ?? double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final data = {
      'type': _selectedType,
      'amount': amount,
      'category': _selectedCategory,
      'description': _descriptionController.text,
      'date': _selectedDate.toIso8601String(),
      'paymentMethod': 'Cash',
      'currency': 'USD',
    };

    final success = await context.read<TransactionProvider>().addTransaction(data);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction added!'), behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add transaction'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _saveVoiceTransaction() async {
    if (_parsedVoice == null) return;
    final data = {
      'type': _parsedVoice!['type'],
      'amount': _parsedVoice!['amount'],
      'category': _parsedVoice!['category'],
      'description': _parsedVoice!['description'],
      'date': (_parsedVoice!['date'] as DateTime).toIso8601String(),
      'paymentMethod': 'Cash',
      'currency': 'USD',
    };

    final success = await context.read<TransactionProvider>().addTransaction(data);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction added!'), behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add transaction'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Quick Add'),
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_showForm && !_showVoiceResult) ...[
              _buildQuickActionButtons(isDark),
              const SizedBox(height: 24),
              _buildVoiceSection(isDark),
              const SizedBox(height: 24),
              _buildRecentCategories(isDark),
              const SizedBox(height: 16),
              _buildFrequentAmounts(isDark),
            ],
            if (_showForm) _buildQuickForm(isDark),
            if (_showVoiceResult) _buildVoiceConfirmation(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _openQuickForm('expense'),
            icon: const Icon(Icons.trending_down_rounded, size: 22),
            label: const Text('Quick Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _openQuickForm('income'),
            icon: const Icon(Icons.trending_up_rounded, size: 22),
            label: const Text('Quick Income', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _openQuickForm('savings'),
            icon: const Icon(Icons.savings_outlined, size: 22),
            label: const Text('Quick Savings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      child: Column(
        children: [
          Text(
            'Voice Input',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? AppColors.danger.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: _isListening ? AppColors.danger : AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: _isListening ? AppColors.danger : AppColors.primary,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_isListening)
            const Text(
              'Listening... tap to stop',
              style: TextStyle(color: AppColors.danger, fontSize: 13),
            )
          else if (_voiceText.isNotEmpty)
            Text(
              _voiceText,
              style: TextStyle(color: isDark ? AppColors.grey400 : AppColors.grey500, fontSize: 13),
              textAlign: TextAlign.center,
            )
          else
            Text(
              'Tap to speak. Say "spent 50 on food" or "received 2000 from salary"',
              style: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400, fontSize: 12),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildRecentCategories(bool isDark) {
    final categories = [...AppConstants.expenseCategories, ...AppConstants.incomeSources];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Categories',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = _quickCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _quickCategory = cat);
                    _openQuickForm(_selectedType);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : isDark
                              ? AppColors.darkCardAlt
                              : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : isDark
                                ? AppColors.darkBorder
                                : AppColors.grey100,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : isDark
                                ? AppColors.grey400
                                : AppColors.grey600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequentAmounts(bool isDark) {
    final amounts = [10, 20, 50, 100, 500];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequent Amounts',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: amounts.map((amt) {
              final isSelected = _quickAmount == amt;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _quickAmount = amt;
                      _amountController.text = amt.toString();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : isDark ? AppColors.darkCardAlt : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : isDark ? AppColors.darkBorder : AppColors.grey100,
                      ),
                    ),
                    child: Text(
                      '\$$amt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : isDark ? AppColors.grey400 : AppColors.grey600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedType == 'expense'
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : _selectedType == 'income'
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _selectedType == 'expense'
                      ? Icons.trending_down_rounded
                      : _selectedType == 'income'
                          ? Icons.trending_up_rounded
                          : Icons.savings_outlined,
                  color: _selectedType == 'expense'
                      ? AppColors.danger
                      : _selectedType == 'income'
                          ? AppColors.success
                          : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _selectedType == 'expense'
                    ? 'Quick Expense'
                    : _selectedType == 'income'
                        ? 'Quick Income'
                        : 'Quick Savings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
              labelStyle: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
            dropdownColor: isDark ? AppColors.darkCard : Colors.white,
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: (_selectedType == 'income' ? AppConstants.incomeSources : AppConstants.expenseCategories)
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedCategory = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              labelStyle: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saveQuickTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceConfirmation(bool isDark) {
    if (_parsedVoice == null) return const SizedBox.shrink();
    final amount = (_parsedVoice!['amount'] as double).toStringAsFixed(2);
    final type = _parsedVoice!['type'] as String;
    final category = _parsedVoice!['category'] as String;
    final description = _parsedVoice!['description'] as String;
    final date = _parsedVoice!['date'] as DateTime;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: type == 'income' ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  type == 'income' ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: type == 'income' ? AppColors.success : AppColors.danger,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Parsed Transaction',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Amount', '\$$amount', isDark),
          _buildDetailRow('Category', category, isDark),
          _buildDetailRow('Type', type[0].toUpperCase() + type.substring(1), isDark),
          _buildDetailRow('Date', DateFormat('MMM dd, yyyy').format(date), isDark),
          if (description.isNotEmpty) _buildDetailRow('Description', description, isDark),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saveVoiceTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Confirm & Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _showVoiceResult = false;
                  _parsedVoice = null;
                  _voiceText = '';
                });
              },
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400, fontSize: 13)),
          Text(value, style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }
}
