import '../../data/datasources/remote/auto_save_remote_datasource.dart';
import '../../data/models/auto_save_model.dart';

class AutoSaveRepositoryImpl {
  final AutoSaveRemoteDataSource _remoteDataSource = AutoSaveRemoteDataSource();

  Future<List<AutoSaveRule>> getRules() async {
    final response = await _remoteDataSource.getAll();
    final rules = (response['data']['rules'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return rules.map((j) => AutoSaveRule.fromJson(j)).toList();
  }

  Future<double> getTotalProjected() async {
    final response = await _remoteDataSource.getAll();
    final total = response['data']['totalProjected'];
    return (total as num).toDouble();
  }

  Future<AutoSaveRule> createRule(Map<String, dynamic> data) async {
    final response = await _remoteDataSource.create(data);
    return AutoSaveRule.fromJson(response['data']);
  }

  Future<void> updateRule(String id, Map<String, dynamic> data) async {
    await _remoteDataSource.update(id, data);
  }

  Future<void> deleteRule(String id) async {
    await _remoteDataSource.delete(id);
  }

  Future<void> triggerContribution(String id) async {
    await _remoteDataSource.triggerContribution(id);
  }
}
