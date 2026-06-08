import '../../../core/network/api_client.dart';

class ChallengeRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getAll() async {
    return _apiClient.get('/challenges');
  }

  Future<Map<String, dynamic>> joinChallenge(Map<String, dynamic> data) async {
    return _apiClient.post('/challenges/join', data: data);
  }

  Future<Map<String, dynamic>> updateProgress(String id, double progress) async {
    return _apiClient.put('/challenges/progress/$id', data: {'progress': progress});
  }

  Future<Map<String, dynamic>> recordLogin() async {
    return _apiClient.post('/challenges/login');
  }

  Future<Map<String, dynamic>> recordSpend() async {
    return _apiClient.post('/challenges/spend');
  }
}
