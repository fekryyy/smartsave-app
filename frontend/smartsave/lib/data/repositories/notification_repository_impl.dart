import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationRepositoryImpl {
  final ApiClient _apiClient = ApiClient();

  Future<List<NotificationModel>> getNotifications({bool unreadOnly = false}) async {
    final queryParams = <String, dynamic>{};
    if (unreadOnly) queryParams['unreadOnly'] = 'true';
    final response = await _apiClient.get(ApiConstants.notifications, queryParameters: queryParams);
    final data = response['data'];
    return (data['notifications'] as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _apiClient.get(ApiConstants.notifications, queryParameters: {'limit': '1'});
    return response['data']['unreadCount'] ?? 0;
  }

  Future<void> markAsRead(String id) async {
    await _apiClient.put('${ApiConstants.notifications}/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _apiClient.put('${ApiConstants.notifications}/read-all');
  }

  Future<void> deleteNotification(String id) async {
    await _apiClient.delete('${ApiConstants.notifications}/$id');
  }
}
