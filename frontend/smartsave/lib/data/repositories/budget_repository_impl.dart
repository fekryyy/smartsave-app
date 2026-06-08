import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../domain/repositories/budget_repository.dart';
import '../models/budget_model.dart';
import 'cacheable_repository.dart';

class BudgetRepositoryImpl with CacheableRepository implements BudgetRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<List<BudgetModel>> getBudgets({int? month, int? year}) async {
    final cacheKey = 'budgets:list:${month ?? "all"}:${year ?? "all"}';
    final response = await cacheFirst(
      cacheKey: cacheKey,
      fetcher: () async {
        final params = <String, dynamic>{};
        if (month != null) params['month'] = month;
        if (year != null) params['year'] = year;
        return _apiClient.get(ApiConstants.budgets, queryParameters: params).dataOrThrow;
      },
    );
    return (response['data'] as List).map((e) => BudgetModel.fromJson(e)).toList();
  }

  @override
  Future<Map<String, dynamic>> getBudgetOverview() async {
    final response = await cacheFirst(
      cacheKey: 'budgets:overview',
      fetcher: () => _apiClient.get(ApiConstants.budgetOverview).dataOrThrow,
    );
    return response['data'];
  }

  @override
  Future<BudgetModel> createBudget(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiConstants.budgets, data: data).dataOrThrow;
    await invalidateCache('budgets:');
    return BudgetModel.fromJson(response['data']);
  }

  @override
  Future<BudgetModel> updateBudget(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('${ApiConstants.budgets}/$id', data: data).dataOrThrow;
    await invalidateCache('budgets:');
    return BudgetModel.fromJson(response['data']);
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _apiClient.delete('${ApiConstants.budgets}/$id').dataOrThrow;
    await invalidateCache('budgets:');
  }
}
