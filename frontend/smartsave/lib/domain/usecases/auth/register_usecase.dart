import '../../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;
  RegisterUseCase(this.repository);

  Future<dynamic> call(String name, String email, String password) {
    return repository.register(name, email, password);
  }
}
