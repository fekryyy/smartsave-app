import '../../data/models/transaction_model.dart';

abstract class TransactionRepository {
  Future<List<TransactionModel>> getTransactions({int page, int limit, String? type, String? category, String? paymentMethod, String? startDate, String? endDate});
  Future<List<TransactionModel>> getRecentTransactions();
  Future<TransactionModel> createTransaction(Map<String, dynamic> data);
  Future<TransactionModel> updateTransaction(String id, Map<String, dynamic> data);
  Future<void> deleteTransaction(String id);
}
