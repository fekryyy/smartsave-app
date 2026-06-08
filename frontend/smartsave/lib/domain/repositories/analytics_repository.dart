import '../../data/models/analytics_model.dart';

abstract class AnalyticsRepository {
  Future<DashboardData> getDashboard();
  Future<List<CategoryBreakdown>> getCategoryBreakdown({String period});
  Future<List<MonthlyTrend>> getMonthlyTrend({int months});
  Future<Map<String, dynamic>> getIncomeVsExpenses({String period});
  Future<Map<String, dynamic>> getSavingsGrowth({int months});
  Future<List<Recommendation>> getRecommendations();
}
