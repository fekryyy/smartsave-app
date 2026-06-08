import '../../../core/network/api_client.dart';

class NetWorthRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getNetWorth() async {
    return _apiClient.get('/networth');
  }

  Future<Map<String, dynamic>> addEntry(Map<String, dynamic> data) async {
    return _apiClient.post('/networth/entry', data: data);
  }

  Future<Map<String, dynamic>> getHistory() async {
    return _apiClient.get('/networth/history');
  }
}
