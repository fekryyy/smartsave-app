import 'package:flutter/material.dart';
import '../../core/errors/provider_error_handler.dart';
import '../../data/models/net_worth_model.dart';
import '../../data/repositories/net_worth_repository_impl.dart';

class NetWorthProvider extends ChangeNotifier with ProviderErrorHandler {
  final NetWorthRepositoryImpl _repository = NetWorthRepositoryImpl();
  NetWorthModel? _netWorth;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;

  NetWorthModel? get netWorth => _netWorth;
  List<Map<String, dynamic>> get history => _history;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _netWorth = await _repository.getNetWorth();
      _history = await _repository.getHistory();
      clearError();
    } catch (e) {
      setError(extractErrorMessage(e));
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addEntry(Map<String, dynamic> data) async {
    try {
      _netWorth = await _repository.addEntry(data);
      _history = await _repository.getHistory();
      clearError();
      notifyListeners();
      return true;
    } catch (e) {
      setError(extractErrorMessage(e));
      return false;
    }
  }
}
