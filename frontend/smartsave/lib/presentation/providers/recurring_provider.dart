import 'package:flutter/material.dart';
import '../../data/models/recurring_transaction_model.dart';
import '../../data/repositories/recurring_repository_impl.dart';

class RecurringProvider extends ChangeNotifier {
  final RecurringRepositoryImpl _repository = RecurringRepositoryImpl();

  List<RecurringTransactionModel> _recurring = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<RecurringTransactionModel> get recurring => _recurring;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadRecurring() async {
    _isLoading = true;
    notifyListeners();
    try {
      _recurring = await _repository.getRecurringTransactions();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load recurring';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createRecurring(Map<String, dynamic> data) async {
    try {
      await _repository.createRecurringTransaction(data);
      await loadRecurring();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create recurring';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRecurring(String id) async {
    try {
      await _repository.deleteRecurringTransaction(id);
      _recurring.removeWhere((r) => r.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to cancel recurring';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
