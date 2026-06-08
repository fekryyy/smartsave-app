import 'package:flutter/material.dart';
import '../../data/models/gamification_model.dart';
import '../../data/repositories/challenge_repository_impl.dart';

class ChallengeProvider extends ChangeNotifier {
  final ChallengeRepositoryImpl _repository = ChallengeRepositoryImpl();

  List<ChallengeModel> _challenges = [];
  List<AchievementModel> _achievements = [];
  UserStreakModel? _streak;
  bool _isLoading = false;

  List<ChallengeModel> get challenges => _challenges;
  List<AchievementModel> get achievements => _achievements;
  UserStreakModel? get streak => _streak;
  bool get isLoading => _isLoading;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      _challenges = await _repository.getChallenges();
      _achievements = await _repository.getAchievements();
      _streak = await _repository.getStreak();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> joinChallenge(Map<String, dynamic> data) async {
    try {
      await _repository.joinChallenge(data);
      await loadAll();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> updateProgress(String id, double progress) async {
    try {
      await _repository.updateProgress(id, progress);
      await loadAll();
      return true;
    } catch (_) { return false; }
  }

  Future<void> recordLogin() async {
    try { await _repository.recordLogin(); } catch (_) {}
  }

  Future<void> recordSpend() async {
    try { await _repository.recordSpend(); } catch (_) {}
  }
}
