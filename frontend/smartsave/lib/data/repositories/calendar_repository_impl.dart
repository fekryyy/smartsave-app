import '../../data/datasources/remote/calendar_remote_datasource.dart';
import '../../data/models/calendar_model.dart';

class CalendarRepositoryImpl {
  final CalendarRemoteDataSource _remoteDataSource = CalendarRemoteDataSource();

  Future<CalendarData> getCalendarData(int year, int month) async {
    final response = await _remoteDataSource.getCalendarData(year, month);
    return CalendarData.fromJson(response['data']);
  }
}
