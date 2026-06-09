import '../../core/errors/failures.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/local/local_database.dart';
import '../datasources/remote/transaction_remote_datasource.dart';
import '../models/transaction_model.dart';
import 'cacheable_repository.dart';
import 'dart:convert';

class TransactionRepositoryImpl with CacheableRepository implements TransactionRepository {
  final TransactionRemoteDataSource _remoteDataSource = TransactionRemoteDataSource();
  final LocalDatabase _localDb = LocalDatabase.instance;

  @override
  Future<List<TransactionModel>> getTransactions({int page = 1, int limit = 20, String? type, String? category, String? paymentMethod, String? startDate, String? endDate}) async {
    final cacheKey = 'transactions:list:$page:$limit:${type ?? ""}:${category ?? ""}';

    try {
      final data = await cacheFirst(
        cacheKey: cacheKey,
        ttlSeconds: 30, // Shorter TTL for transactions (30s)
        fetcher: () async {
          final result = await _remoteDataSource.getTransactions(
            page: page, limit: limit,
            type: type, category: category,
            paymentMethod: paymentMethod,
            startDate: startDate, endDate: endDate,
          );
          return {'transactions': result['transactions'], 'pagination': result['pagination']};
        },
      );

      final transactions = (data['transactions'] as List).map((e) => TransactionModel.fromJson(e)).toList();

      // Also cache in local SQLite for offline fallback
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
      // Try local cache as last resort
      final cached = await _localDb.query('transactions', orderBy: 'date DESC');
      if (cached.isNotEmpty) {
        return cached.map((e) => TransactionModel.fromJson(e)).toList();
      }
      throw const ServerFailure(message: 'Failed to load transactions');
    }
  }

  @override
  Future<List<TransactionModel>> getRecentTransactions() async {
    const cacheKey = 'transactions:recent';
    final response = await cacheFirst(
      cacheKey: cacheKey,
      ttlSeconds: 30,
      fetcher: () => _remoteDataSource.getRecentTransactions(),
    );
    final transactions = (response['data'] as List).map((e) => TransactionModel.fromJson(e)).toList();
    return transactions;
  }

  @override
  Future<TransactionModel> createTransaction(Map<String, dynamic> data) async {
    try {
      final result = await _remoteDataSource.createTransaction(data);
      await invalidateCache('transactions:');
      await invalidateCache('analytics:');
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
    await invalidateCache('transactions:');
    await invalidateCache('analytics:');
    return TransactionModel.fromJson(result);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _remoteDataSource.deleteTransaction(id);
    await _localDb.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await invalidateCache('transactions:');
    await invalidateCache('analytics:');
  }
}
