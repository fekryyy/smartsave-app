import '../../data/models/gamification_model.dart';
import '../datasources/remote/challenge_remote_datasource.dart';

class ChallengeRepositoryImpl {
  final ChallengeRemoteDataSource _remote = ChallengeRemoteDataSource();

  Future<List<ChallengeModel>> getChallenges() async {
    final resp = await _remote.getAll();
    final list = (resp['data']['challenges'] as List?) ?? [];
    return list.map((e) => ChallengeModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UserStreakModel?> getStreak() async {
    final resp = await _remote.getAll();
    final data = resp['data']['streak'];
    return data != null ? UserStreakModel.fromJson(data as Map<String, dynamic>) : null;
  }

  Future<List<AchievementModel>> getAchievements() async {
    final resp = await _remote.getAll();
    final list = (resp['data']['achievements'] as List?) ?? [];
    return list.map((e) => AchievementModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChallengeModel> joinChallenge(Map<String, dynamic> data) async {
    final resp = await _remote.joinChallenge(data);
    return ChallengeModel.fromJson(resp['data']);
  }

  Future<ChallengeModel> updateProgress(String id, double progress) async {
    final resp = await _remote.updateProgress(id, progress);
    return ChallengeModel.fromJson(resp['data']);
  }

  Future<void> recordLogin() async => _remote.recordLogin();
  Future<void> recordSpend() async => _remote.recordSpend();
}
