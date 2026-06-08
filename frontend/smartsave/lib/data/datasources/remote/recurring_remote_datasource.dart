import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class RecurringRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getRecurringTransactions() async {
    final response = await _apiClient.get(ApiConstants.recurringTransactions);
    return response['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createRecurringTransaction(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiConstants.recurringTransactions, data: data);
    return response['data'];
  }

  Future<Map<String, dynamic>> updateRecurringTransaction(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('${ApiConstants.recurringTransactions}/$id', data: data);
    return response['data'];
  }

  Future<void> deleteRecurringTransaction(String id) async {
    await _apiClient.delete('${ApiConstants.recurringTransactions}/$id');
  }
}
