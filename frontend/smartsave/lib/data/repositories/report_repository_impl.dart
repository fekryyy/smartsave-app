import '../../data/datasources/remote/report_remote_datasource.dart';
import '../../data/models/report_model.dart';
import '../../data/models/heatmap_model.dart';

class ReportRepositoryImpl {
  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSource();

  Future<MonthlyReport> getMonthlyReport(int year, int month) async {
    final response = await _remoteDataSource.getMonthlyReport(year, month);
    return MonthlyReport.fromJson(response['data']);
  }

  Future<List<ComparisonItem>> getComparison(int year, int month) async {
    final response = await _remoteDataSource.getComparison(year, month);
    final items = (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return items.map((j) => ComparisonItem.fromJson(j)).toList();
  }

  Future<TrendData> getTrends() async {
    final response = await _remoteDataSource.getTrends();
    return TrendData.fromJson(response['data']);
  }

  Future<HeatmapData> getHeatmap(int year) async {
    final response = await _remoteDataSource.getHeatmap(year);
    return HeatmapData.fromJson(response['data']);
  }
}
