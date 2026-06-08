import '../../repositories/transaction_repository.dart';

class GetTransactionsUseCase {
  final TransactionRepository repository;
  GetTransactionsUseCase(this.repository);

  Future<dynamic> call({int page = 1, int limit = 20, String? type, String? category}) {
    return repository.getTransactions(page: page, limit: limit, type: type, category: category);
  }
}
