import 'package:flutter/material.dart';
import '../../data/repositories/xp_repository_impl.dart';

class XpProvider extends ChangeNotifier {
  final XpRepositoryImpl _repository = XpRepositoryImpl();
  int _level = 1;
  String _levelName = 'Beginner Saver';
  int _xp = 0;
  int _currentThreshold = 0;
  int _nextThreshold = 0;
  double _progress = 0;
  int _totalTransactions = 0;
  bool _isLoading = false;

  int get level => _level;
  String get levelName => _levelName;
  int get xp => _xp;
  int get currentThreshold => _currentThreshold;
  int get nextThreshold => _nextThreshold;
  double get progress => _progress;
  int get totalTransactions => _totalTransactions;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _repository.getProgress();
      _level = data['level'] ?? 1;
      _levelName = data['name'] ?? data['levelName'] ?? 'Beginner Saver';
      _xp = data['xp'] ?? 0;
      _currentThreshold = data['currentThreshold'] ?? 0;
      _nextThreshold = data['nextThreshold'] ?? 0;
      _progress = (data['progress'] ?? 0).toDouble();
      _totalTransactions = data['totalTransactions'] ?? 0;
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }
}
