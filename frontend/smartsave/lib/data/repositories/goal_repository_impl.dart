import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../domain/repositories/goal_repository.dart';
import '../models/goal_model.dart';

class GoalRepositoryImpl implements GoalRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<List<GoalModel>> getGoals({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;

    final response = await _apiClient.get(ApiConstants.goals, queryParameters: params);
    final goals = (response['data'] as List).map((e) => GoalModel.fromJson(e)).toList();
    return goals;
  }

  @override
  Future<GoalModel> createGoal(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiConstants.goals, data: data);
    return GoalModel.fromJson(response['data']);
  }

  @override
  Future<GoalModel> updateGoal(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('${ApiConstants.goals}/$id', data: data);
    return GoalModel.fromJson(response['data']);
  }

  @override
  Future<void> deleteGoal(String id) async {
    await _apiClient.delete('${ApiConstants.goals}/$id');
  }

  @override
  Future<GoalModel> addContribution(String id, double amount) async {
    final response = await _apiClient.post('${ApiConstants.goals}/$id/contribute', data: {
      'amount': amount,
    });
    return GoalModel.fromJson(response['data']);
  }

  @override
  Future<List<Map<String, dynamic>>> getGoalProgress() async {
    final response = await _apiClient.get(ApiConstants.goalProgress);
    return List<Map<String, dynamic>>.from(response['data']);
  }
}
