class TransactionModel {
  final String id;
  final String type;
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final String paymentMethod;
  final String currency;
  final bool isRecurring;
  final String? recurringFrequency;
  final String? receiptUrl;
  final List<String> tags;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.description = '',
    DateTime? date,
    this.paymentMethod = 'Cash',
    this.currency = 'USD',
    this.isRecurring = false,
    this.recurringFrequency,
    this.receiptUrl,
    this.tags = const [],
  }) : date = date ?? DateTime.now();

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      paymentMethod: json['paymentMethod'] ?? 'Cash',
      currency: json['currency'] ?? 'USD',
      isRecurring: json['isRecurring'] ?? false,
      recurringFrequency: json['recurringFrequency'],
      receiptUrl: json['receiptUrl'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
    'category': category,
    'description': description,
    'date': date.toIso8601String(),
    'paymentMethod': paymentMethod,
    'currency': currency,
    'tags': tags,
    'isRecurring': isRecurring,
    'recurringFrequency': recurringFrequency,
  };
}
