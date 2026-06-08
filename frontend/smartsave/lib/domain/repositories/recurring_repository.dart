import '../../data/models/recurring_transaction_model.dart';

abstract class RecurringRepository {
  Future<List<RecurringTransactionModel>> getRecurringTransactions();
  Future<RecurringTransactionModel> createRecurringTransaction(Map<String, dynamic> data);
  Future<RecurringTransactionModel> updateRecurringTransaction(String id, Map<String, dynamic> data);
  Future<void> deleteRecurringTransaction(String id);
}
