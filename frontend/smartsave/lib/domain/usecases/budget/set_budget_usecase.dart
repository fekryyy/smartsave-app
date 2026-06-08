import '../../repositories/budget_repository.dart';

class SetBudgetUseCase {
  final BudgetRepository repository;
  SetBudgetUseCase(this.repository);

  Future<dynamic> call(Map<String, dynamic> data) {
    return repository.createBudget(data);
  }
}
