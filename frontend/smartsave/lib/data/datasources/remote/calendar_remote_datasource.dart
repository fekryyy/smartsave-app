import '../../../core/network/api_client.dart';

class CalendarRemoteDataSource {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getCalendarData(int year, int month) async {
    return _apiClient.get('/calendar?year=$year&month=$month');
  }
}
