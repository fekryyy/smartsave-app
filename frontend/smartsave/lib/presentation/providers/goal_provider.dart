import 'package:flutter/material.dart';
import '../../data/models/goal_model.dart';
import '../../data/repositories/goal_repository_impl.dart';

class GoalProvider extends ChangeNotifier {
  final GoalRepositoryImpl _goalRepository = GoalRepositoryImpl();

  List<GoalModel> _goals = [];
  List<Map<String, dynamic>> _goalProgress = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<GoalModel> get goals => _goals;
  List<Map<String, dynamic>> get goalProgress => _goalProgress;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get totalProgress {
    if (_goals.isEmpty) return 0;
    final totalTarget = _goals.fold(0.0, (sum, g) => sum + g.targetAmount);
    final totalCurrent = _goals.fold(0.0, (sum, g) => sum + g.currentAmount);
    return totalTarget > 0 ? (totalCurrent / totalTarget) * 100 : 0;
  }

  Future<void> loadGoals({String? status}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _goals = await _goalRepository.getGoals(status: status);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load goals';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadGoalProgress() async {
    try {
      _goalProgress = await _goalRepository.getGoalProgress();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> createGoal(Map<String, dynamic> data) async {
    try {
      await _goalRepository.createGoal(data);
      await loadGoals();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create goal';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGoal(String id, Map<String, dynamic> data) async {
    try {
      await _goalRepository.updateGoal(id, data);
      await loadGoals();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update goal';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGoal(String id) async {
    try {
      await _goalRepository.deleteGoal(id);
      await loadGoals();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete goal';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addContribution(String id, double amount) async {
    try {
      await _goalRepository.addContribution(id, amount);
      await loadGoals();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add contribution';
      notifyListeners();
      return false;
    }
  }

  /// Resets all state to initial values.
  /// Called when the authenticated user changes to prevent data leakage
  /// between user sessions.
  void resetState() {
    _goals = [];
    _goalProgress = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
