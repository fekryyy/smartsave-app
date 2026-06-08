import '../../repositories/transaction_repository.dart';

class AddTransactionUseCase {
  final TransactionRepository repository;
  AddTransactionUseCase(this.repository);

  Future<dynamic> call(Map<String, dynamic> data) {
    return repository.createTransaction(data);
  }
}
