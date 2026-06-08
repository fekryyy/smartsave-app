import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class TransactionRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getTransactions({int page = 1, int limit = 20, String? type, String? category, String? paymentMethod, String? startDate, String? endDate}) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (type != null) params['type'] = type;
    if (category != null) params['category'] = category;
    if (paymentMethod != null) params['paymentMethod'] = paymentMethod;
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;

    final response = await _apiClient.get(ApiConstants.transactions, queryParameters: params);
    return response['data'];
  }

  Future<Map<String, dynamic>> getRecentTransactions() async {
    final response = await _apiClient.get(ApiConstants.recentTransactions);
    return response;
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiConstants.transactions, data: data);
    return response['data'];
  }

  Future<Map<String, dynamic>> updateTransaction(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('${ApiConstants.transactions}/$id', data: data);
    return response['data'];
  }

  Future<void> deleteTransaction(String id) async {
    await _apiClient.delete('${ApiConstants.transactions}/$id');
  }
}
