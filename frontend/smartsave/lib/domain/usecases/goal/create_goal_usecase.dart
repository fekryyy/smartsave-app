import '../../repositories/goal_repository.dart';

class CreateGoalUseCase {
  final GoalRepository repository;
  CreateGoalUseCase(this.repository);

  Future<dynamic> call(Map<String, dynamic> data) {
    return repository.createGoal(data);
  }
}
