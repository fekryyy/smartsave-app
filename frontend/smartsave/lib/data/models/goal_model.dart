class GoalModel {
  final String id;
  final String title;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String category;
  final String priority;
  final String status;
  final String icon;
  final String color;
  final double monthlyContribution;
  final DateTime createdAt;

  GoalModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
    this.category = 'Other',
    this.priority = 'medium',
    this.status = 'active',
    this.icon = 'savings',
    this.color = '#4CAF50',
    this.monthlyContribution = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
  double get remaining => targetAmount - currentAmount;
  DateTime? get estimatedCompletionDate {
    if (monthlyContribution <= 0 || currentAmount >= targetAmount) return null;
    final monthsNeeded = (remaining / monthlyContribution).ceil();
    return DateTime.now().add(Duration(days: monthsNeeded * 30));
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      targetAmount: (json['targetAmount'] ?? 0).toDouble(),
      currentAmount: (json['currentAmount'] ?? 0).toDouble(),
      targetDate: json['targetDate'] != null ? DateTime.parse(json['targetDate']) : null,
      category: json['category'] ?? 'Other',
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'active',
      icon: json['icon'] ?? 'savings',
      color: json['color'] ?? '#4CAF50',
      monthlyContribution: (json['monthlyContribution'] ?? 0).toDouble(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'targetAmount': targetAmount,
    'targetDate': targetDate?.toIso8601String(),
    'category': category,
    'priority': priority,
    'icon': icon,
    'color': color,
    'monthlyContribution': monthlyContribution,
  };
}
