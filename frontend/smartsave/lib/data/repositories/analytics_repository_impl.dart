import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../models/analytics_model.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<DashboardData> getDashboard() async {
    final response = await _apiClient.get(ApiConstants.dashboard);
    return DashboardData.fromJson(response['data']);
  }

  @override
  Future<List<CategoryBreakdown>> getCategoryBreakdown({String period = 'monthly'}) async {
    final response = await _apiClient.get(ApiConstants.categoryBreakdown, queryParameters: {'period': period});
    final breakdown = (response['data']['breakdown'] as List).map((e) => CategoryBreakdown.fromJson(e)).toList();
    return breakdown;
  }

  @override
  Future<List<MonthlyTrend>> getMonthlyTrend({int months = 6}) async {
    final response = await _apiClient.get(ApiConstants.monthlyTrend, queryParameters: {'months': months});
    final trends = (response['data'] as List).map((e) => MonthlyTrend.fromJson(e)).toList();
    return trends;
  }

  @override
  Future<Map<String, dynamic>> getIncomeVsExpenses({String period = 'monthly'}) async {
    final response = await _apiClient.get(ApiConstants.incomeVsExpenses, queryParameters: {'period': period});
    return response['data'];
  }

  @override
  Future<Map<String, dynamic>> getSavingsGrowth({int months = 6}) async {
    final response = await _apiClient.get(ApiConstants.savingsGrowth, queryParameters: {'months': months});
    return response['data'];
  }

  @override
  Future<List<Recommendation>> getRecommendations() async {
    final response = await _apiClient.get(ApiConstants.recommendations);
    final recommendations = (response['data'] as List).map((e) => Recommendation.fromJson(e)).toList();
    return recommendations;
  }
}
