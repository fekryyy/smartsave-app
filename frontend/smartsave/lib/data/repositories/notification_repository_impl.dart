import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/notification_model.dart';
import 'cacheable_repository.dart';

class NotificationRepositoryImpl with CacheableRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<NotificationModel>> getNotifications({bool unreadOnly = false}) async {
    final cacheKey = 'notifications:list:$unreadOnly';
    final response = await cacheFirst(
      cacheKey: cacheKey,
      fetcher: () async {
        final queryParams = <String, dynamic>{};
        if (unreadOnly) queryParams['unreadOnly'] = 'true';
        return _apiClient.get(ApiConstants.notifications, queryParameters: queryParams).dataOrThrow;
      },
    );
    final data = response['data'];
    return (data['notifications'] as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<int> getUnreadCount() async {
    final response = await cacheFirst(
      cacheKey: 'notifications:unreadcount',
      fetcher: () => _apiClient.get(ApiConstants.notifications, queryParameters: {'limit': '1'}).dataOrThrow,
    );
    return response['data']['unreadCount'] ?? 0;
  }

  Future<void> markAsRead(String id) async {
    await _apiClient.put('${ApiConstants.notifications}/$id/read').dataOrThrow;
    await invalidateCache('notifications:');
  }

  Future<void> markAllAsRead() async {
    await _apiClient.put('${ApiConstants.notifications}/read-all').dataOrThrow;
    await invalidateCache('notifications:');
  }

  Future<void> deleteNotification(String id) async {
    await _apiClient.delete('${ApiConstants.notifications}/$id').dataOrThrow;
    await invalidateCache('notifications:');
  }
}
