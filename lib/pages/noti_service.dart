import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotiService {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  //initialize
  Future<void> initNotification() async {
    if (_isInitialized) return; // pre re-initialization

    //init timezone handling
    await _initializeTimeZones();

    //prepare android init settings
    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    //init settings
    const initSettings = InitializationSettings(android: initSettingsAndroid);

    //initialize plugin
    await notificationsPlugin.initialize(initSettings);
    _isInitialized = true;
  }

  // Initialize timezone
  Future<void> _initializeTimeZones() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  // noti detail setup
  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
      'daily_channel_id',
      'Daily Notifications',
      channelDescription: 'Daily Notification Channel',
      importance: Importance.max,
      priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      ),
    );
  }

  // show noti
  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    if (!_isInitialized) {
      await initNotification();
    }

    return notificationsPlugin.show(id, title, body, notificationDetails());
  }

  // scheduled notifications
  Future<void> scheduleNotification({
    int id = 1,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_isInitialized) {
      await initNotification();
    }

    //get current date/time in device's local timezone
    final now = tz.TZDateTime.now(tz.local);

    //create a date/time for today at specified hour/min
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    //scheduled
    await notificationsPlugin.zonedSchedule(
      id, 
      title, 
      body, 
      scheduledDate,
      notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    print("Notification Scheduled for ${scheduledDate.toString()}");
  }

  //cancel noti
  Future<void> cancelALLNotifications() async {
    await notificationsPlugin.cancelAll();
  }
}
