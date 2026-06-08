import '../../data/datasources/remote/subscription_remote_datasource.dart';
import '../../data/models/subscription_model.dart';

class SubscriptionRepositoryImpl {
  final SubscriptionRemoteDataSource _remoteDataSource = SubscriptionRemoteDataSource();

  Future<List<SubscriptionModel>> getSubscriptions() async {
    final response = await _remoteDataSource.getAll();
    final data = response['data'];
    final subscriptions = (data['subscriptions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return subscriptions.map((j) => SubscriptionModel.fromJson(j)).toList();
  }

  Future<double> getMonthlyTotal() async {
    final response = await _remoteDataSource.getAll();
    final total = response['data']['monthlyTotal'];
    return (total as num).toDouble();
  }

  Future<double> getYearlyTotal() async {
    final response = await _remoteDataSource.getAll();
    final total = response['data']['yearlyTotal'];
    return (total as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getUpcoming() async {
    final response = await _remoteDataSource.getAll();
    final upcoming = (response['data']['upcoming'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return upcoming;
  }

  Future<SubscriptionModel> createSubscription(Map<String, dynamic> data) async {
    final response = await _remoteDataSource.create(data);
    return SubscriptionModel.fromJson(response['data']);
  }

  Future<void> updateSubscription(String id, Map<String, dynamic> data) async {
    await _remoteDataSource.update(id, data);
  }

  Future<void> deleteSubscription(String id) async {
    await _remoteDataSource.delete(id);
  }
}
