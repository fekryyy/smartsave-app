import 'package:flutter/material.dart';
import '../../data/models/report_model.dart';
import '../../data/models/heatmap_model.dart';
import '../../data/repositories/report_repository_impl.dart';

class ReportProvider extends ChangeNotifier {
  final ReportRepositoryImpl _reportRepository = ReportRepositoryImpl();
  MonthlyReport? _currentReport;
  List<ComparisonItem> _comparison = [];
  TrendData? _trends;
  HeatmapData? _heatmap;
  bool _isLoading = false;

  MonthlyReport? get currentReport => _currentReport;
  List<ComparisonItem> get comparison => _comparison;
  TrendData? get trends => _trends;
  HeatmapData? get heatmap => _heatmap;
  bool get isLoading => _isLoading;

  Future<void> loadReport(int year, int month) async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentReport = await _reportRepository.getMonthlyReport(year, month);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadComparison(int year, int month) async {
    _isLoading = true;
    notifyListeners();
    try {
      _comparison = await _reportRepository.getComparison(year, month);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTrends() async {
    _isLoading = true;
    notifyListeners();
    try {
      _trends = await _reportRepository.getTrends();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadHeatmap(int year) async {
    _isLoading = true;
    notifyListeners();
    try {
      _heatmap = await _reportRepository.getHeatmap(year);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }
}
