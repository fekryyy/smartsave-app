class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final String currency;
  final double monthlyBudget;
  final bool emailVerified;
  final bool onboardingCompleted;
  final Map<String, bool> notificationPreferences;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.currency = 'USD',
    this.monthlyBudget = 0,
    this.emailVerified = false,
    this.onboardingCompleted = false,
    Map<String, bool>? notificationPreferences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : notificationPreferences = notificationPreferences ?? {
    'budgetWarnings': true,
    'goalReminders': true,
    'weeklySummary': true,
    'savingSuggestions': true,
  }, createdAt = createdAt ?? DateTime.now(), updatedAt = updatedAt ?? DateTime.now();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'],
      currency: json['currency'] ?? 'USD',
      monthlyBudget: (json['monthlyBudget'] ?? 0).toDouble(),
      emailVerified: json['emailVerified'] ?? false,
      onboardingCompleted: json['onboardingCompleted'] ?? false,
      notificationPreferences: json['notificationPreferences'] != null
          ? Map<String, bool>.from(json['notificationPreferences'])
          : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'currency': currency,
    'monthlyBudget': monthlyBudget,
    'notificationPreferences': notificationPreferences,
  };
}
