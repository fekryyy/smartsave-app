import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../data/models/budget_model.dart';
import '../../data/repositories/budget_repository_impl.dart';

class BudgetProvider extends ChangeNotifier {
  final BudgetRepositoryImpl _budgetRepository = BudgetRepositoryImpl();

  List<BudgetModel> _budgets = [];
  Map<String, dynamic>? _overview;
  bool _isLoading = false;
  String? _errorMessage;

  List<BudgetModel> get budgets => _budgets;
  Map<String, dynamic>? get overview => _overview;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadBudgets({int? month, int? year}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _budgets = await _budgetRepository.getBudgets(month: month, year: year);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load budgets';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadOverview() async {
    _isLoading = true;
    notifyListeners();

    try {
      _overview = await _budgetRepository.getBudgetOverview();
      if (_overview != null && _overview!['budgets'] != null) {
        _budgets = (_overview!['budgets'] as List).map((e) => BudgetModel.fromJson(e)).toList();
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load budget overview';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createBudget(Map<String, dynamic> data) async {
    try {
      await _budgetRepository.createBudget(data);
      await loadOverview();
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBudget(String id, Map<String, dynamic> data) async {
    try {
      await _budgetRepository.updateBudget(id, data);
      await loadOverview();
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBudget(String id) async {
    try {
      await _budgetRepository.deleteBudget(id);
      await loadOverview();
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  String _extractError(Object e) {
    if (e is DioException && e.response?.data is Map) {
      return (e.response!.data as Map)['message'] ?? 'Request failed';
    }
    return 'Failed to complete operation';
  }

  /// Resets all state to initial values.
  /// Called when the authenticated user changes to prevent data leakage
  /// between user sessions.
  void resetState() {
    _budgets = [];
    _overview = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
