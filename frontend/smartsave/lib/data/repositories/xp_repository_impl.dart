import '../../data/datasources/remote/xp_remote_datasource.dart';

class XpRepositoryImpl {
  final XpRemoteDataSource _remoteDataSource = XpRemoteDataSource();

  Future<Map<String, dynamic>> getProgress() async {
    final response = await _remoteDataSource.getProgress();
    return response['data'] as Map<String, dynamic>;
  }

  Future<void> addXp(int amount, {String? reason}) async {
    await _remoteDataSource.addXp(amount, reason: reason);
  }
}
