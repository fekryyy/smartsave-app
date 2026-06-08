import '../../core/errors/failures.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/local/local_database.dart';
import '../datasources/remote/transaction_remote_datasource.dart';
import '../models/transaction_model.dart';
import 'dart:convert';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource _remoteDataSource = TransactionRemoteDataSource();
  final LocalDatabase _localDb = LocalDatabase.instance;

  @override
  Future<List<TransactionModel>> getTransactions({int page = 1, int limit = 20, String? type, String? category, String? paymentMethod, String? startDate, String? endDate}) async {
    try {
      final data = await _remoteDataSource.getTransactions(page: page, limit: limit, type: type, category: category, paymentMethod: paymentMethod, startDate: startDate, endDate: endDate);
      final transactions = (data['transactions'] as List).map((e) => TransactionModel.fromJson(e)).toList();

      // Cache locally
      for (final tx in transactions) {
        await _localDb.insert('transactions', {
          'id': tx.id,
          'type': tx.type,
          'amount': tx.amount,
          'category': tx.category,
          'description': tx.description,
          'date': tx.date.toIso8601String(),
          'paymentMethod': tx.paymentMethod,
          'currency': tx.currency,
          'isSynced': 1,
          'createdAt': tx.date.toIso8601String(),
        });
      }

      return transactions;
    } catch (e) {
      // Try local cache
      final cached = await _localDb.query('transactions', orderBy: 'date DESC');
      if (cached.isNotEmpty) {
        return cached.map((e) => TransactionModel.fromJson(e)).toList();
      }
      throw const ServerFailure(message: 'Failed to load transactions');
    }
  }

  @override
  Future<List<TransactionModel>> getRecentTransactions() async {
    final response = await _remoteDataSource.getRecentTransactions();
    final transactions = (response['data'] as List).map((e) => TransactionModel.fromJson(e)).toList();
    return transactions;
  }

  @override
  Future<TransactionModel> createTransaction(Map<String, dynamic> data) async {
    try {
      final result = await _remoteDataSource.createTransaction(data);
      return TransactionModel.fromJson(result);
    } catch (e) {
      // Queue for sync
      await _localDb.addPendingOperation('POST', '/transactions', jsonEncode(data));
      rethrow;
    }
  }

  @override
  Future<TransactionModel> updateTransaction(String id, Map<String, dynamic> data) async {
    final result = await _remoteDataSource.updateTransaction(id, data);
    return TransactionModel.fromJson(result);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _remoteDataSource.deleteTransaction(id);
    await _localDb.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
}
