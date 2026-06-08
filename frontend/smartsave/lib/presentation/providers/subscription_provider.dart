import 'package:flutter/material.dart';
import '../../data/models/subscription_model.dart';
import '../../data/repositories/subscription_repository_impl.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionRepositoryImpl _repository = SubscriptionRepositoryImpl();
  List<SubscriptionModel> _subscriptions = [];
  double _monthlyTotal = 0;
  double _yearlyTotal = 0;
  List<Map<String, dynamic>> _upcoming = [];
  bool _isLoading = false;

  List<SubscriptionModel> get subscriptions => _subscriptions;
  double get monthlyTotal => _monthlyTotal;
  double get yearlyTotal => _yearlyTotal;
  List<Map<String, dynamic>> get upcoming => _upcoming;
  bool get isLoading => _isLoading;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      _subscriptions = await _repository.getSubscriptions();
      // Compute totals locally from subscription data for reliability
      _monthlyTotal = _subscriptions.fold(0, (sum, s) => sum + s.monthlyAmount);
      _yearlyTotal = _subscriptions.fold(0, (sum, s) => sum + s.yearlyAmount);
      try {
        _upcoming = await _repository.getUpcoming();
      } catch (_) {
        _upcoming = [];
      }
    } catch (_) {
      _subscriptions = [];
      _monthlyTotal = 0;
      _yearlyTotal = 0;
      _upcoming = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      final subscription = await _repository.createSubscription(data);
      _subscriptions.add(subscription);
      _monthlyTotal = _subscriptions.fold(0, (sum, s) => sum + s.monthlyAmount);
      _yearlyTotal = _subscriptions.fold(0, (sum, s) => sum + s.yearlyAmount);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    try {
      await _repository.updateSubscription(id, data);
      final index = _subscriptions.indexWhere((s) => s.id == id);
      if (index != -1) {
        // Merge updates into existing subscription to preserve all fields
        final existing = _subscriptions[index];
        final mergedJson = {
          '_id': existing.id,
          'name': existing.name,
          'description': existing.description,
          'amount': existing.amount,
          'currency': existing.currency,
          'billingDate': existing.billingDate,
          'renewalFrequency': existing.renewalFrequency,
          'category': existing.category,
          'logo': existing.logo,
          'website': existing.website,
          'isActive': existing.isActive,
          'nextBillingDate': existing.nextBillingDate?.toIso8601String(),
          'lastBilledDate': existing.lastBilledDate?.toIso8601String(),
          'missedPayments': existing.missedPayments,
          'reminderEnabled': existing.reminderEnabled,
          'createdAt': existing.createdAt.toIso8601String(),
          ...data,
        };
        _subscriptions[index] = SubscriptionModel.fromJson(mergedJson);
        _monthlyTotal = _subscriptions.fold(0, (sum, s) => sum + s.monthlyAmount);
        _yearlyTotal = _subscriptions.fold(0, (sum, s) => sum + s.yearlyAmount);
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _repository.deleteSubscription(id);
      _subscriptions.removeWhere((s) => s.id == id);
      _monthlyTotal = _subscriptions.fold(0, (sum, s) => sum + s.monthlyAmount);
      _yearlyTotal = _subscriptions.fold(0, (sum, s) => sum + s.yearlyAmount);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
