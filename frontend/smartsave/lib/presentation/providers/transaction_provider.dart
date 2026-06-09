import 'package:flutter/material.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/analytics_model.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../data/datasources/remote/challenge_remote_datasource.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRepositoryImpl _transactionRepository = TransactionRepositoryImpl();
  final AnalyticsRepositoryImpl _analyticsRepository = AnalyticsRepositoryImpl();
  final ChallengeRemoteDataSource _challengeRemote = ChallengeRemoteDataSource();

  List<TransactionModel> _transactions = [];
  List<TransactionModel> _recentTransactions = [];
  DashboardData? _dashboardData;
  bool _isLoading = false;
  String? _errorMessage;

  List<TransactionModel> get transactions => _transactions;
  List<TransactionModel> get recentTransactions => _recentTransactions;
  DashboardData? get dashboardData => _dashboardData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadTransactions({String? type, String? category, String? paymentMethod, String? startDate, String? endDate}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await _transactionRepository.getTransactions(type: type, category: category, paymentMethod: paymentMethod, startDate: startDate, endDate: endDate);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load transactions';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadRecentTransactions() async {
    try {
      _recentTransactions = await _transactionRepository.getRecentTransactions();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadDashboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      _dashboardData = await _analyticsRepository.getDashboard();
      _recentTransactions = await _transactionRepository.getRecentTransactions();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load dashboard';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addTransaction(Map<String, dynamic> data) async {
    try {
      await _transactionRepository.createTransaction(data);
      await loadTransactions();
      await loadDashboard();
      if (data['type'] == 'expense') _challengeRemote.recordSpend();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add transaction';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTransaction(String id, Map<String, dynamic> data) async {
    try {
      await _transactionRepository.updateTransaction(id, data);
      await loadTransactions();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update transaction';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      await _transactionRepository.deleteTransaction(id);
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete transaction';
      notifyListeners();
      return false;
    }
  }

  /// Resets all state to initial values.
  /// Called when the authenticated user changes to prevent data leakage
  /// between user sessions.
  void resetState() {
    _transactions = [];
    _recentTransactions = [];
    _dashboardData = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
