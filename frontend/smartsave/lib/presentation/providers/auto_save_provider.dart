import 'package:flutter/material.dart';
import '../../core/errors/provider_error_handler.dart';
import '../../data/models/auto_save_model.dart';
import '../../data/repositories/auto_save_repository_impl.dart';

class AutoSaveProvider extends ChangeNotifier with ProviderErrorHandler {
  final AutoSaveRepositoryImpl _repository = AutoSaveRepositoryImpl();
  List<AutoSaveRule> _rules = [];
  double _totalProjected = 0;
  bool _isLoading = false;

  List<AutoSaveRule> get rules => _rules;
  double get totalProjected => _totalProjected;
  bool get isLoading => _isLoading;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      _rules = await _repository.getRules();
      _totalProjected = await _repository.getTotalProjected();
      clearError();
    } catch (e) {
      setError(extractErrorMessage(e));
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      final rule = await _repository.createRule(data);
      _rules.add(rule);
      clearError();
      notifyListeners();
      return true;
    } catch (e) {
      setError(extractErrorMessage(e));
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    try {
      await _repository.updateRule(id, data);
      final index = _rules.indexWhere((r) => r.id == id);
      if (index != -1) {
        _rules[index] = AutoSaveRule.fromJson({...data, '_id': id});
      }
      clearError();
      notifyListeners();
      return true;
    } catch (e) {
      setError(extractErrorMessage(e));
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _repository.deleteRule(id);
      _rules.removeWhere((r) => r.id == id);
      clearError();
      notifyListeners();
      return true;
    } catch (e) {
      setError(extractErrorMessage(e));
      return false;
    }
  }

  /// Resets all state to initial values.
  /// Called when the authenticated user changes to prevent data leakage
  /// between user sessions.
  void resetState() {
    _rules = [];
    _totalProjected = 0;
    _isLoading = false;
    clearError();
    notifyListeners();
  }

  Future<bool> triggerContribution(String id) async {
    try {
      await _repository.triggerContribution(id);
      await loadAll();
      return true;
    } catch (e) {
      setError(extractErrorMessage(e));
      return false;
    }
  }
}
