import '../../data/models/budget_model.dart';

abstract class BudgetRepository {
  Future<List<BudgetModel>> getBudgets({int? month, int? year});
  Future<Map<String, dynamic>> getBudgetOverview();
  Future<BudgetModel> createBudget(Map<String, dynamic> data);
  Future<BudgetModel> updateBudget(String id, Map<String, dynamic> data);
  Future<void> deleteBudget(String id);
}
