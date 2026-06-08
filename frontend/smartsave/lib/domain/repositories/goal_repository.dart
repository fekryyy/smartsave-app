import '../../data/models/goal_model.dart';

abstract class GoalRepository {
  Future<List<GoalModel>> getGoals({String? status});
  Future<GoalModel> createGoal(Map<String, dynamic> data);
  Future<GoalModel> updateGoal(String id, Map<String, dynamic> data);
  Future<void> deleteGoal(String id);
  Future<GoalModel> addContribution(String id, double amount);
  Future<List<Map<String, dynamic>>> getGoalProgress();
}
