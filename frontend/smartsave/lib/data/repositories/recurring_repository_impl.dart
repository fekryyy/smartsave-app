import '../../domain/repositories/recurring_repository.dart';
import '../datasources/remote/recurring_remote_datasource.dart';
import '../models/recurring_transaction_model.dart';

class RecurringRepositoryImpl implements RecurringRepository {
  final RecurringRemoteDataSource _remoteDataSource = RecurringRemoteDataSource();

  @override
  Future<List<RecurringTransactionModel>> getRecurringTransactions() async {
    final data = await _remoteDataSource.getRecurringTransactions();
    return data.map((e) => RecurringTransactionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<RecurringTransactionModel> createRecurringTransaction(Map<String, dynamic> data) async {
    final result = await _remoteDataSource.createRecurringTransaction(data);
    return RecurringTransactionModel.fromJson(result);
  }

  @override
  Future<RecurringTransactionModel> updateRecurringTransaction(String id, Map<String, dynamic> data) async {
    final result = await _remoteDataSource.updateRecurringTransaction(id, data);
    return RecurringTransactionModel.fromJson(result);
  }

  @override
  Future<void> deleteRecurringTransaction(String id) async {
    await _remoteDataSource.deleteRecurringTransaction(id);
  }
}
