import 'package:flutter/material.dart';
import '../../core/errors/provider_error_handler.dart';
import '../../data/models/calendar_model.dart';
import '../../data/repositories/calendar_repository_impl.dart';

class CalendarProvider extends ChangeNotifier with ProviderErrorHandler {
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
      clearError();
    } catch (e) {
      setError(extractErrorMessage(e));
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Resets all state to initial values.
  /// Called when the authenticated user changes to prevent data leakage
  /// between user sessions.
  void resetState() {
    _calendarData = null;
    _isLoading = false;
    clearError();
    notifyListeners();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }
}
