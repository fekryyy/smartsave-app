import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap
      },
    );

    _initialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'smartsave_channel',
      'SmartSave Notifications',
      channelDescription: 'SmartSave financial notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  Future<void> showBudgetWarning(String category, double percentage) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Budget Warning',
      body: 'You have used ${percentage.toStringAsFixed(0)}% of your $category budget.',
      payload: 'budget',
    );
  }

  Future<void> showGoalReminder(String goalName, double remaining) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Goal Reminder',
      body: 'You are \$${remaining.toStringAsFixed(0)} away from your "$goalName" goal.',
      payload: 'goal',
    );
  }

  Future<void> showWeeklySummary(double income, double expenses, double net) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Weekly Summary',
      body: 'Income: \$${income.toStringAsFixed(0)} | Expenses: \$${expenses.toStringAsFixed(0)} | Net: \$${net.toStringAsFixed(0)}',
      payload: 'summary',
    );
  }
}
