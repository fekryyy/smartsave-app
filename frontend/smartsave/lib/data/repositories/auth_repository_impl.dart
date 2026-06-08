import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_client.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource = AuthRemoteDataSource();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiClient _apiClient = ApiClient();

  @override
  Future<UserModel> login(String email, String password) async {
    final data = await _remoteDataSource.login(email, password);
    await _apiClient.setToken(data['token']);
    await _storage.write(key: 'refresh_token', value: data['refreshToken']);
    return UserModel.fromJson(data['user']);
  }

  @override
  Future<UserModel> register(String name, String email, String password) async {
    final data = await _remoteDataSource.register(name, email, password);
    await _apiClient.setToken(data['token']);
    await _storage.write(key: 'refresh_token', value: data['refreshToken']);
    return UserModel.fromJson(data['user']);
  }

  @override
  Future<UserModel> googleLogin(String idToken) async {
    final data = await _remoteDataSource.googleLogin(idToken);
    await _apiClient.setToken(data['token']);
    await _storage.write(key: 'refresh_token', value: data['refreshToken']);
    return UserModel.fromJson(data['user']);
  }

  @override
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _remoteDataSource.forgotPassword(email);
  }

  @override
  Future<void> resetPassword(String token, String password) async {
    await _remoteDataSource.resetPassword(token, password);
  }

  @override
  Future<UserModel> getProfile() async {
    final data = await _remoteDataSource.getProfile();
    return UserModel.fromJson(data);
  }

  @override
  Future<UserModel> updateProfile(Map<String, dynamic> data) async {
    final result = await _remoteDataSource.updateProfile(data);
    return UserModel.fromJson(result);
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _remoteDataSource.changePassword(currentPassword, newPassword);
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }
}
