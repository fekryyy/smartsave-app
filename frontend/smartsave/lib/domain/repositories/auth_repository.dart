import '../../data/models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> login(String email, String password);
  Future<UserModel> register(String name, String email, String password);
  Future<UserModel> googleLogin(String idToken);
  Future<void> logout();
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String token, String password);
  Future<UserModel> getProfile();
  Future<UserModel> updateProfile(Map<String, dynamic> data);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<bool> isLoggedIn();
  Future<String?> getToken();
}
