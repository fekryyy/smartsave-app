import '../../../core/network/api_client.dart';

class AutoSaveRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getAll() async {
    return _apiClient.get('/autosave').dataOrThrow;
  }

  Future<Map<String, dynamic>> getById(String id) async {
    return _apiClient.get('/autosave/$id').dataOrThrow;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    return _apiClient.post('/autosave', data: data).dataOrThrow;
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    return _apiClient.put('/autosave/$id', data: data).dataOrThrow;
  }

  Future<Map<String, dynamic>> delete(String id) async {
    return _apiClient.delete('/autosave/$id').dataOrThrow;
  }

  Future<Map<String, dynamic>> triggerContribution(String id) async {
    return _apiClient.post('/autosave/$id/trigger').dataOrThrow;
  }
}
