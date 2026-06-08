import '../../../core/network/api_client.dart';

class AutoSaveRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getAll() async {
    return _apiClient.get('/autosave');
  }

  Future<Map<String, dynamic>> getById(String id) async {
    return _apiClient.get('/autosave/$id');
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    return _apiClient.post('/autosave', data: data);
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    return _apiClient.put('/autosave/$id', data: data);
  }

  Future<Map<String, dynamic>> delete(String id) async {
    return _apiClient.delete('/autosave/$id');
  }

  Future<Map<String, dynamic>> triggerContribution(String id) async {
    return _apiClient.post('/autosave/$id/trigger');
  }
}
