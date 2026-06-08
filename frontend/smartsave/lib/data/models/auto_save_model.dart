class AutoSaveRule {
  final String id;
  final String name;
  final String type;
  final double amount;
  final double percentage;
  final String targetAccount;
  final bool isActive;
  final String frequency;
  final int? paydayDay;
  final DateTime? lastContribution;
  final double totalContributed;
  final int contributionCount;
  final List<Map<String, dynamic>> history;
  final DateTime createdAt;

  AutoSaveRule({
    required this.id,
    required this.name,
    required this.type,
    this.amount = 0,
    this.percentage = 0,
    this.targetAccount = 'savings',
    this.isActive = true,
    this.frequency = 'monthly',
    this.paydayDay,
    this.lastContribution,
    this.totalContributed = 0,
    this.contributionCount = 0,
    this.history = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AutoSaveRule.fromJson(Map<String, dynamic> json) {
    return AutoSaveRule(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
      targetAccount: json['targetAccount'] ?? 'savings',
      isActive: json['isActive'] ?? true,
      frequency: json['frequency'] ?? 'monthly',
      paydayDay: json['paydayDay'],
      lastContribution: json['lastContribution'] != null ? DateTime.parse(json['lastContribution']) : null,
      totalContributed: (json['totalContributed'] ?? 0).toDouble(),
      contributionCount: json['contributionCount'] ?? 0,
      history: json['history'] != null ? List<Map<String, dynamic>>.from(json['history']) : [],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'amount': amount,
    'percentage': percentage,
    'targetAccount': targetAccount,
    'isActive': isActive,
    'frequency': frequency,
    'paydayDay': paydayDay,
    'lastContribution': lastContribution?.toIso8601String(),
    'totalContributed': totalContributed,
    'contributionCount': contributionCount,
    'history': history,
  };
}
