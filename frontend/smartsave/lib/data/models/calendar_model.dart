class CalendarData {
  final int year;
  final int month;
  final Map<String, Map<String, dynamic>> daily;
  final List<Map<String, dynamic>> upcomingRecurring;
  final List<Map<String, dynamic>> budgetDeadlines;
  final List<Map<String, dynamic>> goalMilestones;

  CalendarData({
    required this.year,
    required this.month,
    this.daily = const {},
    this.upcomingRecurring = const [],
    this.budgetDeadlines = const [],
    this.goalMilestones = const [],
  });

  factory CalendarData.fromJson(Map<String, dynamic> json) {
    return CalendarData(
      year: json['year'] ?? DateTime.now().year,
      month: json['month'] ?? DateTime.now().month,
      daily: json['daily'] != null
          ? (json['daily'] as Map).map(
              (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v)))
          : {},
      upcomingRecurring: json['upcomingRecurring'] != null
          ? List<Map<String, dynamic>>.from(json['upcomingRecurring'])
          : [],
      budgetDeadlines: json['budgetDeadlines'] != null
          ? List<Map<String, dynamic>>.from(json['budgetDeadlines'])
          : [],
      goalMilestones: json['goalMilestones'] != null
          ? List<Map<String, dynamic>>.from(json['goalMilestones'])
          : [],
    );
  }
}
