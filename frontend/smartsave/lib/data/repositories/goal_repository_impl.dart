import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../domain/repositories/goal_repository.dart';
import '../models/goal_model.dart';
import 'cacheable_repository.dart';

class GoalRepositoryImpl with CacheableRepository implements GoalRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<List<GoalModel>> getGoals({String? status}) async {
    final cacheKey = 'goals:list:${status ?? "all"}';
    final response = await cacheFirst(
      cacheKey: cacheKey,
      fetcher: () async {
        final params = <String, dynamic>{};
        if (status != null) params['status'] = status;
        return _apiClient.get(ApiConstants.goals, queryParameters: params).dataOrThrow;
      },
    );
    return (response['data'] as List).map((e) => GoalModel.fromJson(e)).toList();
  }

  @override
  Future<GoalModel> createGoal(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiConstants.goals, data: data).dataOrThrow;
    await invalidateCache('goals:');
    await invalidateCache('analytics:');
    return GoalModel.fromJson(response['data']);
  }

  @override
  Future<GoalModel> updateGoal(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('${ApiConstants.goals}/$id', data: data).dataOrThrow;
    await invalidateCache('goals:');
    await invalidateCache('analytics:');
    return GoalModel.fromJson(response['data']);
  }

  @override
  Future<void> deleteGoal(String id) async {
    await _apiClient.delete('${ApiConstants.goals}/$id').dataOrThrow;
    await invalidateCache('goals:');
    await invalidateCache('analytics:');
  }

  @override
  Future<GoalModel> addContribution(String id, double amount) async {
    final response = await _apiClient.post('${ApiConstants.goals}/$id/contribute', data: {
      'amount': amount,
    }).dataOrThrow;
    await invalidateCache('goals:');
    await invalidateCache('analytics:');
    return GoalModel.fromJson(response['data']);
  }

  @override
  Future<List<Map<String, dynamic>>> getGoalProgress() async {
    final response = await _apiClient.get(ApiConstants.goalProgress).dataOrThrow;
    return List<Map<String, dynamic>>.from(response['data']);
  }
}
