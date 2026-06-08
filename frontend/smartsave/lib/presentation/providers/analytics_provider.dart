import 'package:flutter/material.dart';
import '../../data/models/analytics_model.dart';
import '../../data/repositories/analytics_repository_impl.dart';

class AnalyticsProvider extends ChangeNotifier {
  final AnalyticsRepositoryImpl _analyticsRepository = AnalyticsRepositoryImpl();

  DashboardData? _dashboardData;
  List<CategoryBreakdown> _categoryBreakdown = [];
  List<MonthlyTrend> _monthlyTrend = [];
  Map<String, dynamic>? _incomeVsExpenses;
  Map<String, dynamic>? _savingsGrowth;
  List<Recommendation> _recommendations = [];
  bool _isLoading = false;
  String? _errorMessage;

  DashboardData? get dashboardData => _dashboardData;
  List<CategoryBreakdown> get categoryBreakdown => _categoryBreakdown;
  List<MonthlyTrend> get monthlyTrend => _monthlyTrend;
  Map<String, dynamic>? get incomeVsExpenses => _incomeVsExpenses;
  Map<String, dynamic>? get savingsGrowth => _savingsGrowth;
  List<Recommendation> get recommendations => _recommendations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadDashboard() async {
    try {
      _dashboardData = await _analyticsRepository.getDashboard();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load analytics';
    }
  }

  Future<void> loadCategoryBreakdown({String period = 'monthly'}) async {
    try {
      _categoryBreakdown = await _analyticsRepository.getCategoryBreakdown(period: period);
    } catch (_) {
      _errorMessage = _errorMessage ?? 'Failed to load category breakdown';
    }
  }

  Future<void> loadMonthlyTrend({int months = 6}) async {
    try {
      _monthlyTrend = await _analyticsRepository.getMonthlyTrend(months: months);
    } catch (_) {
      _errorMessage = _errorMessage ?? 'Failed to load trends';
    }
  }

  Future<void> loadIncomeVsExpenses({String period = 'monthly'}) async {
    try {
      _incomeVsExpenses = await _analyticsRepository.getIncomeVsExpenses(period: period);
    } catch (_) {
      _errorMessage = _errorMessage ?? 'Failed to load income vs expenses';
    }
  }

  Future<void> loadSavingsGrowth({int months = 6}) async {
    try {
      _savingsGrowth = await _analyticsRepository.getSavingsGrowth(months: months);
    } catch (_) {
      _errorMessage = _errorMessage ?? 'Failed to load savings growth';
    }
  }

  Future<void> loadRecommendations() async {
    try {
      _recommendations = await _analyticsRepository.getRecommendations();
    } catch (_) {
      _errorMessage = _errorMessage ?? 'Failed to load recommendations';
    }
  }

  Future<void> loadAllAnalytics() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.wait([
      loadDashboard(),
      loadCategoryBreakdown(),
      loadMonthlyTrend(),
      loadIncomeVsExpenses(),
      loadSavingsGrowth(),
      loadRecommendations(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
