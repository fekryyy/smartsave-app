import '../../../core/network/api_client.dart';

class XpRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getProgress() async {
    return _apiClient.get('/xp').dataOrThrow;
  }

  Future<Map<String, dynamic>> addXp(int amount, {String? reason}) async {
    return _apiClient.post('/xp/add', data: {'amount': amount, 'reason': reason}).dataOrThrow;
  }
}
