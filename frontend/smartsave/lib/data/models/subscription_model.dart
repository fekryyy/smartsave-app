class SubscriptionModel {
  final String id;
  final String name;
  final String description;
  final double amount;
  final String currency;
  final int billingDate;
  final String renewalFrequency;
  final String category;
  final String? logo;
  final String? website;
  final bool isActive;
  final DateTime? nextBillingDate;
  final DateTime? lastBilledDate;
  final int missedPayments;
  final bool reminderEnabled;
  final double monthlyAmount;
  final double yearlyAmount;
  final DateTime createdAt;

  SubscriptionModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.amount,
    this.currency = 'USD',
    required this.billingDate,
    required this.renewalFrequency,
    this.category = 'Other',
    this.logo,
    this.website,
    this.isActive = true,
    this.nextBillingDate,
    this.lastBilledDate,
    this.missedPayments = 0,
    this.reminderEnabled = true,
    this.monthlyAmount = 0,
    this.yearlyAmount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] ?? 0).toDouble();
    final frequency = json['renewalFrequency'] ?? 'monthly';
    double monthlyAmount;
    double yearlyAmount;
    switch (frequency) {
      case 'yearly':
        monthlyAmount = amount / 12;
        yearlyAmount = amount;
        break;
      case 'quarterly':
        monthlyAmount = amount / 3;
        yearlyAmount = amount * 4;
        break;
      case 'weekly':
        monthlyAmount = amount * 4.33;
        yearlyAmount = amount * 52;
        break;
      case 'daily':
        monthlyAmount = amount * 30;
        yearlyAmount = amount * 365;
        break;
      default:
        monthlyAmount = amount;
        yearlyAmount = amount * 12;
    }
    return SubscriptionModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      amount: amount,
      currency: json['currency'] ?? 'USD',
      billingDate: json['billingDate'] ?? 1,
      renewalFrequency: frequency,
      category: json['category'] ?? 'Other',
      logo: json['logo'],
      website: json['website'],
      isActive: json['isActive'] ?? true,
      nextBillingDate: json['nextBillingDate'] != null ? DateTime.parse(json['nextBillingDate']) : null,
      lastBilledDate: json['lastBilledDate'] != null ? DateTime.parse(json['lastBilledDate']) : null,
      missedPayments: json['missedPayments'] ?? 0,
      reminderEnabled: json['reminderEnabled'] ?? true,
      monthlyAmount: monthlyAmount,
      yearlyAmount: yearlyAmount,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'amount': amount,
    'currency': currency,
    'billingDate': billingDate,
    'renewalFrequency': renewalFrequency,
    'category': category,
    'logo': logo,
    'website': website,
    'isActive': isActive,
    'nextBillingDate': nextBillingDate?.toIso8601String(),
    'lastBilledDate': lastBilledDate?.toIso8601String(),
    'missedPayments': missedPayments,
    'reminderEnabled': reminderEnabled,
  };
}
