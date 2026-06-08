class BudgetModel {
  final String id;
  final String category;
  final double amount;
  final double spent;
  final String period;
  final int month;
  final int year;
  final bool notifications;
  final bool isActive;

  BudgetModel({
    required this.id,
    required this.category,
    required this.amount,
    this.spent = 0,
    this.period = 'monthly',
    int? month,
    int? year,
    this.notifications = true,
    this.isActive = true,
  }) : month = month ?? DateTime.now().month,
       year = year ?? DateTime.now().year;

  double get percentageUsed => amount > 0 ? (spent / amount) * 100 : 0;
  double get remaining => amount - spent;

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['_id'] ?? json['id'] ?? '',
      category: json['category'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      spent: (json['spent'] ?? 0).toDouble(),
      period: json['period'] ?? 'monthly',
      month: json['month'] ?? DateTime.now().month,
      year: json['year'] ?? DateTime.now().year,
      notifications: json['notifications'] ?? true,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'amount': amount,
    'period': period,
    'notifications': notifications,
  };
}
