import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class AuthRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _apiClient.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    }).dataOrThrow;
    return response['data'];
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await _apiClient.post(ApiConstants.register, data: {
      'name': name,
      'email': email,
      'password': password,
    }).dataOrThrow;
    return response['data'];
  }

  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    final response = await _apiClient.post(ApiConstants.googleLogin, data: {
      'idToken': idToken,
    }).dataOrThrow;
    return response['data'];
  }

  Future<void> forgotPassword(String email) async {
    await _apiClient.post(ApiConstants.forgotPassword, data: {
      'email': email,
    }).dataOrThrow;
  }

  Future<void> resetPassword(String token, String password) async {
    await _apiClient.post(ApiConstants.resetPassword, data: {
      'token': token,
      'password': password,
    }).dataOrThrow;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _apiClient.get(ApiConstants.profile).dataOrThrow;
    return response['data'];
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _apiClient.put(ApiConstants.profile, data: data).dataOrThrow;
    return response['data'];
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _apiClient.put(ApiConstants.changePassword, data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    }).dataOrThrow;
  }
}
