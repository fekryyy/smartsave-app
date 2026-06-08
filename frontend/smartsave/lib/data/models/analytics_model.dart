class PaymentMethodBreakdown {
  final String paymentMethod;
  final double total;
  final int count;

  PaymentMethodBreakdown({
    required this.paymentMethod,
    this.total = 0,
    this.count = 0,
  });

  factory PaymentMethodBreakdown.fromJson(Map<String, dynamic> json) {
    return PaymentMethodBreakdown(
      paymentMethod: json['_id'] ?? '',
      total: (json['total'] ?? 0).toDouble(),
      count: json['count'] ?? 0,
    );
  }
}

class DashboardData {
  final double balance;
  final double monthlyIncome;
  final double monthlyExpenses;
  final double savings;
  final double remainingBudget;
  final List<dynamic> recentTransactions;
  final List<PaymentMethodBreakdown> paymentMethodBreakdown;
  final int month;
  final int year;

  DashboardData({
    this.balance = 0,
    this.monthlyIncome = 0,
    this.monthlyExpenses = 0,
    this.savings = 0,
    this.remainingBudget = 0,
    this.recentTransactions = const [],
    this.paymentMethodBreakdown = const [],
    int? month,
    int? year,
  }) : month = month ?? DateTime.now().month,
       year = year ?? DateTime.now().year;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      balance: (json['balance'] ?? 0).toDouble(),
      monthlyIncome: (json['monthlyIncome'] ?? 0).toDouble(),
      monthlyExpenses: (json['monthlyExpenses'] ?? 0).toDouble(),
      savings: (json['savings'] ?? 0).toDouble(),
      remainingBudget: (json['remainingBudget'] ?? 0).toDouble(),
      recentTransactions: json['recentTransactions'] ?? [],
      paymentMethodBreakdown: (json['paymentMethodBreakdown'] as List?)
          ?.map((e) => PaymentMethodBreakdown.fromJson(e))
          .toList() ?? [],
      month: json['month'],
      year: json['year'],
    );
  }
}

class CategoryBreakdown {
  final String category;
  final double amount;
  final int count;
  final double percentage;

  CategoryBreakdown({
    required this.category,
    this.amount = 0,
    this.count = 0,
    this.percentage = 0,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      category: json['category'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      count: json['count'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class MonthlyTrend {
  final String month;
  final double income;
  final double expenses;

  MonthlyTrend({
    required this.month,
    this.income = 0,
    this.expenses = 0,
  });

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) {
    return MonthlyTrend(
      month: json['month'] ?? '',
      income: (json['income'] ?? 0).toDouble(),
      expenses: (json['expenses'] ?? 0).toDouble(),
    );
  }
}

class Recommendation {
  final String type;
  final String category;
  final String message;
  final String impact;

  Recommendation({
    required this.type,
    required this.category,
    required this.message,
    required this.impact,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      type: json['type'] ?? '',
      category: json['category'] ?? '',
      message: json['message'] ?? '',
      impact: json['impact'] ?? '',
    );
  }
}
