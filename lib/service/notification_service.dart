import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';
import 'alarm_service.dart';
import 'dart:async';
import 'caregiver_service.dart';

/// NotificationService - Direct Alarm System
/// 
/// This service schedules silent notifications that immediately trigger 
/// full-screen alarms when the reminder time arrives. No user interaction
/// with notifications is needed - the alarm appears automatically.
///
/// Key features:
/// - Silent notification triggers that are hidden from the user
/// - Immediate full-screen alarm display with sound and vibration
/// - No notification tapping required - works like a real alarm clock
/// - Uses exact alarm scheduling for precise timing
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static BuildContext? _context;
  static final List<Timer> _activeTimers = []; // Track active timers
  static bool _isStoppingActivities = false; // Guard against recursive stopping
  static final Set<int> _scheduledNotificationIds = {}; // Track scheduled notification IDs
  static final Set<String> _currentlyDisplayedAlarms = {}; // Track currently displayed alarms
  static final Set<String> _handledAlarms = {}; // Track alarms that have been handled (taken/skipped/snoozed)

  static void setContext(BuildContext context) {
    _context = context;
  }

  static Future<void> initialize(BuildContext context) async {
    print('🔔 Initializing NotificationService...');
    _context = context;
    
    // Timezone initialization
    tz.initializeTimeZones();
    
    // Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    // Initialize with automatic tap handler and background handler
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotification,
    );
    
    // Request permissions
    await _requestPermissions();
    
    print('✅ NotificationService initialized successfully');
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'medicine_reminders',
      'Medicine Reminders',
      description: 'Alarm-style reminders for medications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF00F5FF),
      showBadge: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
      print('Alarm notification channel created successfully');
    }
  }

  static void _handleNotificationTap(NotificationResponse response) {
    print('🚨 ===== NOTIFICATION RECEIVED =====');
    print('Response ID: ${response.id}');
    print('Response actionId: ${response.actionId}');
    print('Response input: ${response.input}');
    print('Payload: ${response.payload}');
    print('Current time: ${DateTime.now()}');
    
    // Determine if this is a backup notification or silent trigger
    final isBackupNotification = (response.id != null && response.id! > 10000);
    print('Is backup notification: $isBackupNotification');
    
    // IMMEDIATELY cancel ALL related notifications
    if (response.id != null) {
      final baseId = response.id! > 10000 ? response.id! - 10000 : response.id!;
      cancelNotification(baseId); // Cancel silent trigger
      cancelNotification(baseId + 10000); // Cancel backup notification
      print('Cancelled notifications for base ID: $baseId');
    }
    
    // Parse medication data
    String medicineName = 'Medicine Reminder';
    String instructions = 'Take your medicine as prescribed';
    String time = _formatCurrentTime();
    String medicationId = 'alarm_${DateTime.now().millisecondsSinceEpoch}';

    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final medicationData = json.decode(response.payload!);
        print('📋 Parsed medication data: $medicationData');
        
        medicineName = medicationData['name'] ?? medicineName;
        instructions = medicationData['instructions'] ?? instructions;
        time = medicationData['time'] ?? time;
        medicationId = medicationData['id'] ?? medicationId;
      } catch (parseError) {
        print('⚠️ Error parsing payload, using defaults: $parseError');
      }
    }

    print('🚨 TRIGGERING ALARM: $medicineName at $time');

    // Show the alarm once (with duplicate prevention)
    _showAlarmOnce(
      medicineName: medicineName,
      instructions: instructions,
      time: time,
      medicationId: medicationId,
    );
    
    print('🚨 ===== NOTIFICATION PROCESSED =====');
  }

  // Enhanced background notification handler
  @pragma('vm:entry-point')
  static void _handleBackgroundNotification(NotificationResponse response) {
    print('🌙 ===== BACKGROUND NOTIFICATION RECEIVED =====');
    print('Background Response ID: ${response.id}');
    print('Background Payload: ${response.payload}');
    
    // Use the same aggressive handling as foreground
    _handleNotificationTap(response);
    
    print('🌙 ===== BACKGROUND PROCESSED =====');
  }

  // Smart alarm display with duplicate prevention
  static void _showAlarmOnce({
    required String medicineName,
    required String instructions,
    required String time,
    required String medicationId,
  }) {
    print('🎯 SMART ALARM DISPLAY');
    print('Medicine: $medicineName');
    print('Instructions: $instructions');
    print('Time: $time');
    print('ID: $medicationId');
    
    // Check if this alarm is already displayed or handled
    if (_currentlyDisplayedAlarms.contains(medicationId)) {
      print('⚠️ Alarm already displayed for: $medicationId');
      return;
    }
    
    if (_handledAlarms.contains(medicationId)) {
      print('⚠️ Alarm already handled for: $medicationId');
      return;
    }
    
    // Mark this alarm as currently being displayed
    _currentlyDisplayedAlarms.add(medicationId);
    print('✅ Marked alarm as displayed: $medicationId');
    
    // Try to show the alarm with a single reliable strategy
    _tryShowAlarmSafely(
              medicineName: medicineName,
              instructions: instructions,
              time: time,
              medicationId: medicationId,
            );
  }
  
  // Try to show alarm with fallback strategies (but only one instance)
  static void _tryShowAlarmSafely({
    required String medicineName,
    required String instructions,
    required String time,
    required String medicationId,
  }) {
    print('🛡️ Trying to show alarm safely...');
    
    // Strategy 1: Immediate display
    try {
      if (_context != null && _context!.mounted && !_handledAlarms.contains(medicationId)) {
        print('🔄 Strategy 1: Immediate display...');
              AlarmService.setContext(_context!);
              AlarmService.showRealAlarm(
                medicineName: medicineName,
                instructions: instructions,
                time: time,
                medicationId: medicationId,
              );
        print('✅ Strategy 1: SUCCESS - No fallbacks needed');
        return; // Success, no need for fallbacks
            } else {
        print('⚠️ Strategy 1: Context invalid or alarm already handled');
            }
          } catch (e) {
      print('❌ Strategy 1 failed: $e');
    }
    
    // Strategy 2: Post-frame callback (only if Strategy 1 failed)
    print('🔄 Strategy 1 failed, trying Strategy 2: Post-frame callback...');
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double-check alarm wasn't handled while waiting for post-frame
        if (_context != null && _context!.mounted && !_handledAlarms.contains(medicationId) && _currentlyDisplayedAlarms.contains(medicationId)) {
          print('🔄 Strategy 2: Executing post-frame callback...');
          try {
            AlarmService.setContext(_context!);
            AlarmService.showRealAlarm(
              medicineName: medicineName,
              instructions: instructions,
              time: time,
              medicationId: medicationId,
            );
            print('✅ Strategy 2: SUCCESS');
        } catch (e) {
            print('❌ Strategy 2 execution failed: $e');
            // Try delayed fallback
            _tryDelayedFallback(medicineName, instructions, time, medicationId);
          }
        } else {
          print('⚠️ Strategy 2: Context invalid or alarm handled during post-frame wait');
        }
      });
      print('✅ Strategy 2: Post-frame callback scheduled');
    } catch (e) {
      print('❌ Strategy 2 failed to schedule: $e');
      // Try delayed fallback immediately
      _tryDelayedFallback(medicineName, instructions, time, medicationId);
    }
  }
  
  // Delayed fallback strategy (separated for clarity)
  static void _tryDelayedFallback(String medicineName, String instructions, String time, String medicationId) {
    print('🔄 Trying Strategy 3: Delayed fallback...');
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        if (_context != null && _context!.mounted && !_handledAlarms.contains(medicationId) && _currentlyDisplayedAlarms.contains(medicationId)) {
          print('🔄 Strategy 3: Executing delayed fallback...');
          AlarmService.setContext(_context!);
          AlarmService.showRealAlarm(
            medicineName: medicineName,
            instructions: instructions,
            time: time,
            medicationId: medicationId,
          );
          print('✅ Strategy 3: SUCCESS');
        } else {
          print('⚠️ Strategy 3: Context invalid or alarm handled during delay');
        }
      } catch (e) {
        print('❌ Strategy 3 failed: $e');
        print('💀 ALL STRATEGIES EXHAUSTED for: $medicationId');
        // Clean up the failed alarm from tracking
        _currentlyDisplayedAlarms.remove(medicationId);
      }
    });
  }

  // Safe time formatting without context dependency
  static String _formatCurrentTime() {
    final now = DateTime.now();
    final timeOfDay = TimeOfDay(hour: now.hour, minute: now.minute);
    
    // Format time without context dependency
    final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
    
    return '$hour:$minute $period';
  }

  // Safely show alarm with context validation
  static void _showAlarmSafely({
    required String medicineName,
    required String instructions,
    required String time,
    required String medicationId,
  }) {
    print('🛡️ _showAlarmSafely called with:');
    print('Medicine: $medicineName');
    print('Instructions: $instructions');
    print('Time: $time');
    print('ID: $medicationId');
    
    // Validate context
    if (_context == null) {
      print('❌ Context is null');
      return;
    }
    
    if (!_context!.mounted) {
      print('❌ Context is not mounted');
      return;
    }
    
    print('✅ Context validation passed');
    
    try {
      // Set the context in AlarmService
      AlarmService.setContext(_context!);
      print('✅ AlarmService context set');
      
      // Show the alarm
      AlarmService.showRealAlarm(
        medicineName: medicineName,
        instructions: instructions,
        time: time,
        medicationId: medicationId,
      );
      
      print('✅ AlarmService.showRealAlarm called successfully');
      
    } catch (e) {
      print('❌ Error in _showAlarmSafely: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      
      // Last resort: try to show a simple dialog instead
      try {
        showDialog(
          context: _context!,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Medicine Reminder'),
            content: Text('$medicineName\n$instructions\nTime: $time'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
        print('✅ Fallback dialog shown');
      } catch (dialogError) {
        print('❌ Even fallback dialog failed: $dialogError');
      }
    }
  }

  static Future<void> _updateReminderStatus(String medicationId, String status) async {
    try {
      if (medicationId.isNotEmpty) {
        // Get effective user ID for the status record
        final effectiveUserId = CaregiverService.getEffectiveUserId();
        
        await FirebaseFirestore.instance
            .collection('MedicationStatus')
            .add({
          'medicationId': medicationId,
          'status': status,
          'userId': effectiveUserId, // Add userId for charts query
          'timestamp': FieldValue.serverTimestamp(),
        });
        print('Updated medication status: $status for $medicationId');
      }
    } catch (e) {
      print('Error updating reminder status: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // Request basic notification permission
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        print('Notification permission granted: $granted');
        
        // Request exact alarm permission (critical for Android 12+)
        final bool? exactAlarmGranted = await androidImplementation.requestExactAlarmsPermission();
        print('Exact alarm permission granted: $exactAlarmGranted');
        
        // Check if exact alarms are allowed
        final bool? canScheduleExactAlarms = await androidImplementation.canScheduleExactNotifications();
        print('Can schedule exact alarms: $canScheduleExactAlarms');

        if (canScheduleExactAlarms == false) {
          print('⚠️ WARNING: Exact alarms not permitted. Medication reminders may not work reliably!');
          print('User needs to manually enable exact alarms in system settings.');
        }
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  /// Show notification with ALARM category - uses system alarm ringtone
  static Future<void> showAlarmCategoryNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      print('🚨 Showing ALARM category notification (system alarm ringtone)');
      
      await _notificationsPlugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'system_alarm_channel',
            'System Alarm Notifications',
            channelDescription: 'Uses the system alarm ringtone for medication reminders',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            autoCancel: false,
            category: AndroidNotificationCategory.alarm, // This uses ALARM category
            visibility: NotificationVisibility.public,
            fullScreenIntent: true,
            ongoing: false,
            // Use default alarm sound (system alarm ringtone)
            sound: null, // null = use default system alarm sound for alarm category
            ticker: '🚨 Medicine Reminder Alert',
            timeoutAfter: 30000, // 30 seconds timeout
          ),
        ),
      );
      
      print('✅ System alarm category notification shown');
    } catch (e) {
      print('❌ Error showing alarm category notification: $e');
    }
  }

  static Future<void> scheduleDirectAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    Map<String, dynamic>? medicationData,
    String? targetPatientId, // NEW: Target specific patient's device
  }) async {
    try {
      print('🚨 Scheduling HYBRID alarm system:');
      print('ID: $id');
      print('Title: $title');
      print('Body: $body');
      print('Scheduled time: $scheduledTime');
      
      // Track this notification ID
      _scheduledNotificationIds.add(id);
      
      // Ensure the scheduled time is in the future
      final now = DateTime.now();
      final finalScheduledTime = scheduledTime.isBefore(now) 
          ? scheduledTime.add(Duration(days: 1))
          : scheduledTime;

      print('Final scheduled time: $finalScheduledTime');
      print('Time difference: ${finalScheduledTime.difference(now).inSeconds} seconds');

      // Convert to TZDateTime
      final tzScheduledTime = tz.TZDateTime.from(finalScheduledTime, tz.local);
      print('TZ Scheduled time: $tzScheduledTime');

      // Strategy 1: Silent trigger notification
      await _notificationsPlugin.zonedSchedule(
        id,
        '', // Empty title - silent
        '', // Empty body - silent
        tzScheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'silent_triggers',
            'Silent Alarm Triggers',
            channelDescription: 'Silent triggers for medication alarms',
            importance: Importance.min,
            priority: Priority.min,
            showWhen: false,
            enableVibration: false,
            playSound: false,
            autoCancel: true,
            category: AndroidNotificationCategory.service,
            visibility: NotificationVisibility.secret,
            fullScreenIntent: false,
            ongoing: false,
            silent: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: medicationData != null ? json.encode(medicationData) : null,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      
      // Strategy 2: Backup visible notification (in case silent fails)
      await _notificationsPlugin.zonedSchedule(
        id + 10000, // Different ID for backup
        title,
        body,
        tzScheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'backup_alarms',
            'Backup Alarm Notifications',
            channelDescription: 'Backup visible notifications for alarms',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            autoCancel: false,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            fullScreenIntent: true,
            ongoing: false,
            sound: const RawResourceAndroidNotificationSound('reminder'),
            actions: [
              AndroidNotificationAction(
                'show_alarm',
                'Show Alarm',
                showsUserInterface: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: medicationData != null ? json.encode(medicationData) : null,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // Strategy 3: Schedule a timer-based alarm as ultimate fallback
      final delay = finalScheduledTime.difference(now);
      if (delay.inSeconds > 0 && delay.inSeconds < 86400) { // Only for delays up to 24 hours
        final timer = Timer(delay, () {
          print('⏰ TIMER-BASED ALARM TRIGGERED!');
          _triggerTimerAlarm(
            medicineName: medicationData?['name'] ?? title,
            instructions: medicationData?['instructions'] ?? body,
            time: medicationData?['time'] ?? _formatCurrentTime(),
            medicationId: medicationData?['id'] ?? 'timer_$id',
          );
        });
        _activeTimers.add(timer); // Track the timer
        print('✅ Timer-based fallback scheduled for ${delay.inSeconds} seconds');
      }
      
      print('✅ HYBRID alarm system scheduled (tracking ID: $id)!');
      
    } catch (e) {
      print('❌ Error scheduling hybrid alarm: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
    }
  }

  // Timer-based alarm trigger
  static void _triggerTimerAlarm({
    required String medicineName,
    required String instructions,
    required String time,
    required String medicationId,
  }) {
    print('⏰ Timer alarm triggered for: $medicineName');
    
    // Cancel any related notifications to prevent duplicates
    final baseId = int.tryParse(medicationId.split('_').last) ?? 0;
    cancelNotification(baseId); // Silent trigger
    cancelNotification(baseId + 10000); // Backup notification
    
    // Clean up this timer from active list (if it exists)
    _activeTimers.removeWhere((timer) => !timer.isActive);
    
    // Show alarm immediately
    _showAlarmOnce(
      medicineName: medicineName,
      instructions: instructions,
      time: time,
      medicationId: medicationId,
    );
  }

  static Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_reminders',
            'Medicine Reminders',
            channelDescription: 'Immediate medicine reminders',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            autoCancel: false,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            fullScreenIntent: true,
            ongoing: false,
            // Using system default alarm sound - much more reliable!
            sound: null, // null = use system default alarm sound
          ),
        ),
      );
      print('✅ System alarm notification shown');
    } catch (e) {
      print('❌ Error showing system alarm notification: $e');
    }
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      print('Cancelled notification with ID: $id');
    } catch (e) {
      print('Error canceling notification: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      print('Cancelled all notifications');
    } catch (e) {
      print('Error canceling all notifications: $e');
    }
  }

  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      print('Error getting pending notifications: $e');
      return [];
    }
  }

  // Test notification to verify the system works
  static Future<void> testNotification() async {
    try {
      await showImmediateNotification(
        id: 999999,
        title: "🧪 Test Alarm",
        body: "If you see this, notifications are working! Check your notification settings if medications alerts don't work.",
      );
      print('✅ Test notification sent');
    } catch (e) {
      print('❌ Test notification failed: $e');
    }
  }

  // Test direct alarm scheduling (for debugging)
  static Future<void> testDirectAlarmIn5Seconds() async {
    print('🧪 ===== TESTING DIRECT ALARM SYSTEM =====');
    print('Current time: ${DateTime.now()}');
    
    final testTime = DateTime.now().add(const Duration(seconds: 5));
    final testData = {
      'id': 'test_direct_${DateTime.now().millisecondsSinceEpoch}',
      'name': 'TEST Medicine',
      'instructions': 'This is a 5-second test of the direct alarm system',
      'time': _formatCurrentTime(), // Safe time formatting
    };
    
    print('Test data: $testData');
    print('Scheduling for: $testTime');
    
    // Check current pending notifications
    final currentPending = await getPendingNotifications();
    print('Current pending notifications: ${currentPending.length}');
    for (var notification in currentPending) {
      print('  - ID: ${notification.id}, Title: ${notification.title}');
    }
    
    await scheduleDirectAlarm(
      id: 888888,
      title: '🧪 5-Second Test',
      body: 'Testing direct alarm system',
      scheduledTime: testTime,
      medicationData: testData,
    );
    
    // Check pending notifications after scheduling
    final afterPending = await getPendingNotifications();
    print('Pending notifications after scheduling: ${afterPending.length}');
    for (var notification in afterPending) {
      print('  - ID: ${notification.id}, Title: ${notification.title}');
    }
    
    print('✅ Test direct alarm scheduled for: $testTime');
    print('⏰ You should see the full-screen alarm in 5 seconds!');
    print('🧪 ===== TEST SCHEDULING COMPLETED =====');
  }

  // Test alarm display directly (bypassing notifications entirely)
  static Future<void> testAlarmDisplayDirectly() async {
    print('🚨 ===== TESTING ALARM DISPLAY DIRECTLY =====');
    print('This bypasses notifications and shows the alarm immediately');
    print('Current context: $_context');
    
    if (_context == null) {
      print('❌ CRITICAL: _context is null');
      return;
    }
    
    try {
      print('🔍 Context is available, checking if mounted...');
      final isMounted = _context!.mounted;
      print('🔍 Context mounted: $isMounted');
      
      if (!isMounted) {
        print('❌ CRITICAL: Context is not mounted');
        return;
      }
      
      // Show the alarm once using the smart display method
      print('🔍 Setting AlarmService context...');
      AlarmService.setContext(_context!);
      
      print('🔍 Showing single direct test alarm...');
      _showAlarmOnce(
        medicineName: 'DIRECT TEST Medicine',
        instructions: 'This is a direct test of the alarm display (no notifications)',
        time: _formatCurrentTime(),
        medicationId: 'direct_test_${DateTime.now().millisecondsSinceEpoch}',
      );
      print('✅ Single direct alarm call completed');
      
    } catch (e) {
      print('❌ Direct alarm display test failed: $e');
      print('Error stack trace: ${StackTrace.current}');
    }
    
    print('🚨 ===== DIRECT TEST COMPLETED =====');
  }

  // Stop all alarm activities when user takes action
  static Future<void> stopAllAlarmActivities() async {
    if (_isStoppingActivities) {
      print('⚠️ Already stopping activities, skipping duplicate call');
      return;
    }
    
    _isStoppingActivities = true;
    
    try {
      print('🛑 STOPPING ALL ALARM ACTIVITIES...');
      
      // Cancel all timers that might be running
      _stopAllTimers();
      
      // Cancel only specific notification IDs that we actually use
      final specificIds = [
        9999, 19999, // Test notifications
        999998, 999997, 999999, 999996, 999995, 777777, // System notifications
      ];
      
      // Cancel the specific IDs we know about
      for (int id in specificIds) {
        try {
          await cancelNotification(id);
        } catch (e) {
          // Ignore individual cancellation errors
        }
      }
      
      // Also cancel any tracked medication notifications
      await cancelScheduledMedicationNotifications();
      
      print('✅ All alarm activities stopped (cancelled ${specificIds.length} system + ${_scheduledNotificationIds.length} medication notifications)');
    } catch (e) {
      print('❌ Error stopping alarm activities: $e');
    } finally {
      _isStoppingActivities = false; // Reset the guard
    }
  }

  // Stop any running timers
  static void _stopAllTimers() {
    print('🔄 Stopping ${_activeTimers.length} active timers...');
    
    for (final timer in _activeTimers) {
      if (timer.isActive) {
        timer.cancel();
      }
    }
    
    _activeTimers.clear();
    print('✅ All timers stopped and cleared');
  }

  // Cancel only the notifications we actually scheduled
  static Future<void> cancelScheduledMedicationNotifications() async {
    print('🧹 Cancelling ${_scheduledNotificationIds.length} scheduled medication notifications...');
    
    for (int id in _scheduledNotificationIds) {
      try {
        await cancelNotification(id);
        await cancelNotification(id + 10000); // Cancel backup notification too
      } catch (e) {
        // Ignore individual cancellation errors
      }
    }
    
    _scheduledNotificationIds.clear();
    print('✅ Cancelled all scheduled medication notifications');
  }
  
  // Mark an alarm as handled to prevent duplicate displays
  static void markAlarmAsHandled(String medicationId) {
    print('🏁 Marking alarm as handled: $medicationId');
    _handledAlarms.add(medicationId);
    _currentlyDisplayedAlarms.remove(medicationId);
    print('✅ Alarm marked as handled and removed from displayed set');
  }
  
  // Clean up old handled alarms (call periodically to prevent memory leaks)
  static void cleanupHandledAlarms() {
    print('🧹 Cleaning up handled alarms...');
    // Keep only recent alarms (last hour)
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    
    // Remove old entries (this is a simple cleanup - in production you'd want timestamps)
    if (_handledAlarms.length > 100) {
      print('⚠️ Too many handled alarms (${_handledAlarms.length}), clearing old ones');
      _handledAlarms.clear();
      _currentlyDisplayedAlarms.clear();
    }
    
    print('✅ Cleanup completed');
  }
} 
