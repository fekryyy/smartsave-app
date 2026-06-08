import '../../data/datasources/remote/net_worth_remote_datasource.dart';
import '../../data/models/net_worth_model.dart';

class NetWorthRepositoryImpl {
  final NetWorthRemoteDataSource _remoteDataSource = NetWorthRemoteDataSource();

  Future<NetWorthModel> getNetWorth() async {
    final response = await _remoteDataSource.getNetWorth();
    return NetWorthModel.fromJson(response['data']);
  }

  Future<NetWorthModel> addEntry(Map<String, dynamic> data) async {
    final response = await _remoteDataSource.addEntry(data);
    return NetWorthModel.fromJson(response['data']);
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final response = await _remoteDataSource.getHistory();
    final history = (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return history;
  }
}
