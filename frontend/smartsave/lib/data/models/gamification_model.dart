class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final String type;
  final double goal;
  final double progress;
  final int points;
  final DateTime startDate;
  final DateTime? endDate;
  final String status;
  final DateTime? completedAt;

  ChallengeModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    required this.goal,
    this.progress = 0,
    this.points = 0,
    DateTime? startDate,
    this.endDate,
    this.status = 'active',
    this.completedAt,
  }) : startDate = startDate ?? DateTime.now();

  double get progressPct => goal > 0 ? (progress / goal).clamp(0, 1) : 0;

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? '',
      goal: (json['goal'] ?? 0).toDouble(),
      progress: (json['progress'] ?? 0).toDouble(),
      points: json['points'] ?? 0,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      status: json['status'] ?? 'active',
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    );
  }
}

class AchievementModel {
  final String id;
  final String badge;
  final String title;
  final String description;
  final DateTime unlockedAt;

  AchievementModel({
    required this.id,
    required this.badge,
    required this.title,
    this.description = '',
    DateTime? unlockedAt,
  }) : unlockedAt = unlockedAt ?? DateTime.now();

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['_id'] ?? '',
      badge: json['badge'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : DateTime.now(),
    );
  }
}

class UserStreakModel {
  final int loginStreak;
  final int noSpendStreak;
  final int bestLoginStreak;
  final int bestNoSpendStreak;
  final int totalPoints;
  final DateTime? lastLoginDate;

  UserStreakModel({
    this.loginStreak = 0,
    this.noSpendStreak = 0,
    this.bestLoginStreak = 0,
    this.bestNoSpendStreak = 0,
    this.totalPoints = 0,
    this.lastLoginDate,
  });

  factory UserStreakModel.fromJson(Map<String, dynamic> json) {
    return UserStreakModel(
      loginStreak: json['loginStreak'] ?? 0,
      noSpendStreak: json['noSpendStreak'] ?? 0,
      bestLoginStreak: json['bestLoginStreak'] ?? 0,
      bestNoSpendStreak: json['bestNoSpendStreak'] ?? 0,
      totalPoints: json['totalPoints'] ?? 0,
      lastLoginDate: json['lastLoginDate'] != null ? DateTime.parse(json['lastLoginDate']) : null,
    );
  }
}
