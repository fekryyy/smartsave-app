import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../domain/repositories/budget_repository.dart';
import '../models/budget_model.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<List<BudgetModel>> getBudgets({int? month, int? year}) async {
    final params = <String, dynamic>{};
    if (month != null) params['month'] = month;
    if (year != null) params['year'] = year;

    final response = await _apiClient.get(ApiConstants.budgets, queryParameters: params);
    final budgets = (response['data'] as List).map((e) => BudgetModel.fromJson(e)).toList();
    return budgets;
  }

  @override
  Future<Map<String, dynamic>> getBudgetOverview() async {
    final response = await _apiClient.get(ApiConstants.budgetOverview);
    return response['data'];
  }

  @override
  Future<BudgetModel> createBudget(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiConstants.budgets, data: data);
    return BudgetModel.fromJson(response['data']);
  }

  @override
  Future<BudgetModel> updateBudget(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('${ApiConstants.budgets}/$id', data: data);
    return BudgetModel.fromJson(response['data']);
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _apiClient.delete('${ApiConstants.budgets}/$id');
  }
}
