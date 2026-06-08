import '../../../core/network/api_client.dart';

class SubscriptionRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getAll() async {
    return _apiClient.get('/subscriptions');
  }

  Future<Map<String, dynamic>> getById(String id) async {
    return _apiClient.get('/subscriptions/$id');
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    return _apiClient.post('/subscriptions', data: data);
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    return _apiClient.put('/subscriptions/$id', data: data);
  }

  Future<Map<String, dynamic>> delete(String id) async {
    return _apiClient.delete('/subscriptions/$id');
  }
}
