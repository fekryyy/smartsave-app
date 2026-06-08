import '../../../core/network/api_client.dart';

class ReportRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getMonthlyReport(int year, int month) async {
    return _apiClient.get('/reports/monthly?year=$year&month=$month');
  }

  Future<Map<String, dynamic>> getComparison(int year, int month) async {
    return _apiClient.get('/reports/comparison?year=$year&month=$month');
  }

  Future<Map<String, dynamic>> getTrends() async {
    return _apiClient.get('/reports/trends');
  }

  Future<Map<String, dynamic>> getHeatmap(int year) async {
    return _apiClient.get('/reports/heatmap?year=$year');
  }
}
