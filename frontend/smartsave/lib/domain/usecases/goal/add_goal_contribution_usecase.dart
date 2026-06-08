import '../../repositories/goal_repository.dart';

class AddGoalContributionUseCase {
  final GoalRepository repository;
  AddGoalContributionUseCase(this.repository);

  Future<dynamic> call(String goalId, double amount) {
    return repository.addContribution(goalId, amount);
  }
}
