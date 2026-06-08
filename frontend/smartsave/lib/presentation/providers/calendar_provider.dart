import 'package:flutter/material.dart';
import '../../data/models/calendar_model.dart';
import '../../data/repositories/calendar_repository_impl.dart';

class CalendarProvider extends ChangeNotifier {
  final CalendarRepositoryImpl _repository = CalendarRepositoryImpl();
  CalendarData? _calendarData;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  CalendarData? get calendarData => _calendarData;
  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;

  Future<void> loadData(int year, int month) async {
    _isLoading = true;
    notifyListeners();
    try {
      _calendarData = await _repository.getCalendarData(year, month);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }
}
