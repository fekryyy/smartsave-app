class RecurringTransactionModel {
  final String id;
  final String type;
  final double amount;
  final String category;
  final String description;
  final String frequency;
  final int interval;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextExecutionDate;
  final String paymentMethod;
  final bool isActive;

  RecurringTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.description = '',
    required this.frequency,
    this.interval = 1,
    required this.startDate,
    this.endDate,
    required this.nextExecutionDate,
    this.paymentMethod = 'Cash',
    this.isActive = true,
  });

  factory RecurringTransactionModel.fromJson(Map<String, dynamic> json) {
    return RecurringTransactionModel(
      id: json['_id'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      frequency: json['frequency'] ?? 'monthly',
      interval: json['interval'] ?? 1,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      nextExecutionDate: json['nextExecutionDate'] != null ? DateTime.parse(json['nextExecutionDate']) : DateTime.now(),
      paymentMethod: json['paymentMethod'] ?? 'Cash',
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
    'category': category,
    'description': description,
    'frequency': frequency,
    'interval': interval,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'paymentMethod': paymentMethod,
  };
}
