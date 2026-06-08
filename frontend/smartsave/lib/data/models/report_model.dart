class MonthlyReport {
  final Map<String, int> period;
  final double totalIncome;
  final double totalExpenses;
  final double netSavings;
  final double savingsRate;
  final double incomeChange;
  final double expenseChange;
  final double savingsChange;
  final String mostUsedMethod;
  final Map<String, dynamic>? largestExpense;
  final String topCategory;
  final List<Map<String, dynamic>> categoryBreakdown;
  final List<Map<String, dynamic>> methodBreakdown;
  final List<Map<String, dynamic>> budgetPerformance;
  final int transactionCount;
  final int incomeCount;
  final int expenseCount;

  MonthlyReport({
    Map<String, int>? period,
    this.totalIncome = 0,
    this.totalExpenses = 0,
    this.netSavings = 0,
    this.savingsRate = 0,
    this.incomeChange = 0,
    this.expenseChange = 0,
    this.savingsChange = 0,
    this.mostUsedMethod = '',
    this.largestExpense,
    this.topCategory = '',
    this.categoryBreakdown = const [],
    this.methodBreakdown = const [],
    this.budgetPerformance = const [],
    this.transactionCount = 0,
    this.incomeCount = 0,
    this.expenseCount = 0,
  }) : period = period ?? {'month': DateTime.now().month, 'year': DateTime.now().year};

  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    return MonthlyReport(
      period: json['period'] != null
          ? Map<String, int>.from(json['period'])
          : null,
      totalIncome: (json['totalIncome'] ?? 0).toDouble(),
      totalExpenses: (json['totalExpenses'] ?? 0).toDouble(),
      netSavings: (json['netSavings'] ?? 0).toDouble(),
      savingsRate: (json['savingsRate'] ?? 0).toDouble(),
      incomeChange: (json['incomeChange'] ?? 0).toDouble(),
      expenseChange: (json['expenseChange'] ?? 0).toDouble(),
      savingsChange: (json['savingsChange'] ?? 0).toDouble(),
      mostUsedMethod: json['mostUsedMethod'] ?? '',
      largestExpense: json['largestExpense'] != null
          ? Map<String, dynamic>.from(json['largestExpense'])
          : null,
      topCategory: json['topCategory'] ?? '',
      categoryBreakdown: json['categoryBreakdown'] != null
          ? List<Map<String, dynamic>>.from(json['categoryBreakdown'])
          : [],
      methodBreakdown: json['methodBreakdown'] != null
          ? List<Map<String, dynamic>>.from(json['methodBreakdown'])
          : [],
      budgetPerformance: json['budgetPerformance'] != null
          ? List<Map<String, dynamic>>.from(json['budgetPerformance'])
          : [],
      transactionCount: json['transactionCount'] ?? 0,
      incomeCount: json['incomeCount'] ?? 0,
      expenseCount: json['expenseCount'] ?? 0,
    );
  }
}

class ComparisonItem {
  final int month;
  final int year;
  final double income;
  final double expense;
  final double savings;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> methods;

  ComparisonItem({
    required this.month,
    required this.year,
    this.income = 0,
    this.expense = 0,
    this.savings = 0,
    this.categories = const [],
    this.methods = const [],
  });

  factory ComparisonItem.fromJson(Map<String, dynamic> json) {
    return ComparisonItem(
      month: json['month'] ?? 0,
      year: json['year'] ?? 0,
      income: (json['income'] ?? 0).toDouble(),
      expense: (json['expense'] ?? 0).toDouble(),
      savings: (json['savings'] ?? 0).toDouble(),
      categories: json['categories'] != null
          ? List<Map<String, dynamic>>.from(json['categories'])
          : [],
      methods: json['methods'] != null
          ? List<Map<String, dynamic>>.from(json['methods'])
          : [],
    );
  }
}

class TrendData {
  final List<Map<String, dynamic>> monthlyAgg;
  final Map<String, dynamic> categoryTrends;
  final Map<String, dynamic> fastestGrowing;
  final Map<String, dynamic> mostReduced;
  final double averageDaily;
  final double averageWeekly;
  final double averageMonthly;
  final double totalSpending;
  final int transactionCount;

  TrendData({
    this.monthlyAgg = const [],
    this.categoryTrends = const {},
    this.fastestGrowing = const {},
    this.mostReduced = const {},
    this.averageDaily = 0,
    this.averageWeekly = 0,
    this.averageMonthly = 0,
    this.totalSpending = 0,
    this.transactionCount = 0,
  });

  factory TrendData.fromJson(Map<String, dynamic> json) {
    return TrendData(
      monthlyAgg: json['monthlyAgg'] != null
          ? List<Map<String, dynamic>>.from(json['monthlyAgg'])
          : [],
      categoryTrends: json['categoryTrends'] != null
          ? Map<String, dynamic>.from(json['categoryTrends'])
          : {},
      fastestGrowing: json['fastestGrowing'] != null
          ? Map<String, dynamic>.from(json['fastestGrowing'])
          : {},
      mostReduced: json['mostReduced'] != null
          ? Map<String, dynamic>.from(json['mostReduced'])
          : {},
      averageDaily: (json['averageDaily'] ?? 0).toDouble(),
      averageWeekly: (json['averageWeekly'] ?? 0).toDouble(),
      averageMonthly: (json['averageMonthly'] ?? 0).toDouble(),
      totalSpending: (json['totalSpending'] ?? 0).toDouble(),
      transactionCount: json['transactionCount'] ?? 0,
    );
  }
}
