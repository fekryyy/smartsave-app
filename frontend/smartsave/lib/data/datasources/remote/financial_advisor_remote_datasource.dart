import '../../../core/network/api_client.dart';

class FinancialAdvisorRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  /// Cancel any in-flight requests.
  void cancelRequests() {
    _apiClient.cancelRequests('financial-advisor');
  }

  Future<Map<String, dynamic>> getFullAnalysis() async {
    return _apiClient.get(
      '/financial-advisor/analysis',
      cancelPrevious: true,
    ).dataOrThrow;
  }

  Future<Map<String, dynamic>> getScore() async {
    return _apiClient.get(
      '/financial-advisor/score',
      cancelPrevious: true,
    ).dataOrThrow;
  }

  Future<Map<String, dynamic>> getInsights() async {
    return _apiClient.get(
      '/financial-advisor/insights',
      cancelPrevious: true,
    ).dataOrThrow;
  }

  Future<Map<String, dynamic>> getActionPlan() async {
    return _apiClient.get(
      '/financial-advisor/action-plan',
      cancelPrevious: true,
    ).dataOrThrow;
  }

  Future<Map<String, dynamic>> getPredictions() async {
    return _apiClient.get(
      '/financial-advisor/predictions',
      cancelPrevious: true,
    ).dataOrThrow;
  }

  Future<Map<String, dynamic>> askQuestion(String question) async {
    return _apiClient.post(
      '/financial-advisor/ask',
      data: {'question': question},
    ).dataOrThrow;
  }
}
