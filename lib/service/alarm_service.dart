import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/reminder_alarm_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../service/caregiver_service.dart'; // Added import for CaregiverService

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  static BuildContext? _context;
  static int _currentAlarmId = 1000;
  static bool _isAlarmActive = false;
  static bool _isAlarmScreenOpen = false; // Prevent multiple alarm screens
  static final List<int> _scheduledAlarmIds = []; // Track scheduled alarms
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Store medication data for each alarm
  static final Map<int, Map<String, dynamic>> _alarmData = {};

  static void setContext(BuildContext context) {
    _context = context;
    tz.initializeTimeZones();
    _initializeNotifications();
  }

  // Initialize notifications for background alarms
  static Future<void> _initializeNotifications() async {
    try {
      // Android settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // iOS settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      print('✅ Notifications initialized for background alarms');
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped: ${response.payload}');
    // Only handle notification tap if no alarm is currently active
    if (_context != null && _context!.mounted && !_isAlarmActive) {
      // Parse payload and show alarm screen
      _showAlarmFromNotification(response.payload ?? '');
    }
  }

  // Show alarm from notification
  static void _showAlarmFromNotification(String payload) {
    try {
      // Check if alarm is already active to prevent duplicates
      if (_isAlarmActive) {
        print('⚠️ Alarm already active, ignoring notification tap');
        return;
      }
      
      final parts = payload.split('|');
      if (parts.length >= 4) {
        final medicineName = parts[0];
        final instructions = parts[1];
        final time = parts[2];
        final medicationId = parts[3];
        
        _showAlarmScreen(
          medicineName: medicineName,
          instructions: instructions,
          time: time,
          medicationId: medicationId,
          alarmId: _currentAlarmId,
        );
      }
    } catch (e) {
      print('❌ Error showing alarm from notification: $e');
    }
  }

  // NEW: Schedule alarm for specific future time with background support
  static Future<void> scheduleAlarm({
    required DateTime scheduledTime,
    required String medicineName,
    required String instructions,
    required String medicationId,
  }) async {
    print('📅 ===== SCHEDULING BACKGROUND ALARM =====');
    print('  - Medicine: $medicineName');
    print('  - Scheduled time: $scheduledTime');
    print('  - Current time: ${DateTime.now()}');
    
    // Check if scheduled time is in the future
    final now = DateTime.now();
    DateTime finalScheduledTime = scheduledTime;
    if (scheduledTime.millisecondsSinceEpoch < now.millisecondsSinceEpoch) {
      print('⚠️ Scheduled time is in the past! Adding 1 day...');
      finalScheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    
    final timeDifference = scheduledTime.difference(now);
    print('  - Time until alarm: ${timeDifference.inMinutes} minutes');

    try {
      _currentAlarmId++;
      final alarmId = _currentAlarmId;
      
      // Store medication data for this alarm FIRST
      _alarmData[alarmId] = {
        'medicineName': medicineName,
        'instructions': instructions,
        'medicationId': medicationId,
        'scheduledTime': finalScheduledTime,
      };
      
      // Method 1: Use alarm package with enhanced settings
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: finalScheduledTime,
        assetAudioPath: 'assets/audio/reminder.wav',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          fadeDuration: const Duration(seconds: 1),
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: '🚨 MEDICINE ALARM',
          body: 'Time to take $medicineName',
          stopButton: 'Stop',
        ),
        warningNotificationOnKill: true,
        androidFullScreenIntent: true,
      );

      await Alarm.set(alarmSettings: alarmSettings);
      _scheduledAlarmIds.add(alarmId);
      
      print('✅ Background alarm scheduled successfully with ID: $alarmId');
      print('   Will trigger at: $finalScheduledTime');
      print('   Stored data: ${_alarmData[alarmId]}');
      
      return;
    } catch (e) {
      print('❌ Error scheduling background alarm: $e');
      rethrow;
    }
  }

  // Schedule backup notification (only if main alarm fails)
  static Future<void> _scheduleBackupNotification({
    required DateTime scheduledTime,
    required String medicineName,
    required String instructions,
    required String medicationId,
    required int alarmId,
  }) async {
    try {
      // Only schedule backup if main alarm is not active
      if (_isAlarmActive) {
        print('⚠️ Main alarm is active, skipping backup notification');
        return;
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'medicine_alarms_backup',
        'Medicine Alarms Backup',
        channelDescription: 'Backup medicine reminder alarms',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('reminder'),
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: false, // Don't show full screen for backup
        showWhen: true,
        autoCancel: true, // Auto cancel when tapped
        ongoing: false, // Not ongoing
        silent: false,
        enableLights: true,
        ledColor: Color(0xFF0d6b5c),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: 'Medicine reminder backup',
        visibility: NotificationVisibility.public,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      final payload = '$medicineName|$instructions|${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}|$medicationId';

      // Convert DateTime to TZDateTime
      final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);

      await _notifications.zonedSchedule(
        alarmId + 10000, // Different ID to avoid conflicts
        '🚨 MEDICINE ALARM (Backup)',
        'Time to take $medicineName',
        tzDateTime,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      print('✅ Backup notification scheduled for: $scheduledTime');
    } catch (e) {
      print('❌ Error scheduling backup notification: $e');
    }
  }

  // Enhanced: Show real alarm with better scheduling support
  static Future<void> showRealAlarm({
    required String medicineName,
    required String instructions,
    required String time,
    required String medicationId,
  }) async {
    print('⏰ ===== SHOWING IMMEDIATE ALARM =====');
    print('  - Medicine: $medicineName');
    print('  - Time: $time');
    
    if (_context == null || !_context!.mounted) {
      print('❌ Cannot show alarm: Context unavailable');
      return;
    }

    try {
      _isAlarmActive = true;
      _currentAlarmId++;
      
      // Set up the real alarm with actual alarm sound
      final alarmSettings = AlarmSettings(
        id: _currentAlarmId,
        dateTime: DateTime.now(), // Trigger immediately
        assetAudioPath: 'assets/audio/reminder.wav',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: const Duration(seconds: 2),
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: '🚨 MEDICINE ALARM',
          body: 'Time to take $medicineName',
          stopButton: 'Stop Alarm',
        ),
        warningNotificationOnKill: false,
        androidFullScreenIntent: true,
      );

      // Start the alarm
      await Alarm.set(alarmSettings: alarmSettings);
      print('✅ Real alarm started with ID: $_currentAlarmId');

      // Show the alarm screen immediately (don't wait for alarm package)
      _showAlarmScreen(
        medicineName: medicineName,
        instructions: instructions,
        time: time,
        medicationId: medicationId,
        alarmId: _currentAlarmId,
      );

    } catch (e) {
      print('❌ Error showing real alarm: $e');
      _isAlarmActive = false;
    }
  }

  // Show the alarm screen
  static Future<void> _showAlarmScreen({
    required String medicineName,
    required String instructions,
    required String time,
    required String medicationId,
    required int alarmId,
  }) async {
    if (_context == null || !_context!.mounted) return;
    
    // Prevent multiple alarm screens from opening
    if (_isAlarmScreenOpen) {
      print('⚠️ Alarm screen already open, ignoring duplicate request');
      return;
    }

    _isAlarmScreenOpen = true;

    final route = MaterialPageRoute(
      builder: (context) => ReminderAlarmScreen(
        medicineName: medicineName,
        instructions: instructions,
        time: time,
        onTaken: () => _handleTaken(medicationId, alarmId),
        onSkipped: () => _handleSkipped(medicationId, alarmId),
        onSnoozed: () => _handleSnoozed(medicineName, instructions, time, medicationId, alarmId),
      ),
      fullscreenDialog: true,
    );

    Navigator.of(_context!).push(route);
  }

  // Handle when medicine is taken
  static Future<void> _handleTaken(String medicationId, int alarmId) async {
    print('✅ Medicine taken - stopping alarm');
    
    await _stopAlarm(alarmId);
    await _updateMedicationStatus(medicationId, 'Taken');
    _closeAlarmScreen();
    
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        const SnackBar(content: Text('Medicine taken! ✅')),
      );
    }
  }

  // Handle when medicine is skipped
  static Future<void> _handleSkipped(String medicationId, int alarmId) async {
    print('⏭️ Medicine skipped - stopping alarm');
    
    await _stopAlarm(alarmId);
    await _updateMedicationStatus(medicationId, 'Skipped');
    _closeAlarmScreen();
    
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        const SnackBar(content: Text('Medicine skipped ⏭️')),
      );
    }
  }

  // Handle when medicine is snoozed
  static Future<void> _handleSnoozed(
    String medicineName,
    String instructions,
    String time,
    String medicationId,
    int alarmId,
  ) async {
    print('😴 Medicine snoozed - stopping current alarm');
    
    await _stopAlarm(alarmId);
    await _updateMedicationStatus(medicationId, 'Snoozed');
    _closeAlarmScreen();
    
    // Schedule snooze alarm for 10 minutes later
    _scheduleSnoozeAlarm(medicineName, instructions, time, medicationId);
    
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        const SnackBar(content: Text('Snoozed for 10 minutes 😴')),
      );
    }
  }

  // Stop the alarm
  static Future<void> _stopAlarm(int alarmId) async {
    try {
      print('🛑 Stopping alarm with ID: $alarmId');
      
      await Alarm.stop(alarmId);
      _isAlarmActive = false;
      
      // Cancel backup notification
      await _notifications.cancel(alarmId + 10000);
      
      // Clean up stored alarm data
      _alarmData.remove(alarmId);
      
      // Add haptic feedback
      HapticFeedback.mediumImpact();
      
      print('✅ Alarm stopped successfully');
    } catch (e) {
      print('❌ Error stopping alarm: $e');
    }
  }

  // Close the alarm screen
  static void _closeAlarmScreen() {
    if (_context != null && _context!.mounted) {
      Navigator.of(_context!).pop();
    }
    _isAlarmScreenOpen = false; // Reset flag when screen is closed
  }

  // Update medication status in database (correct collection for dashboard)
  static Future<void> _updateMedicationStatus(String medicationId, String status) async {
    try {
      // Get effective user ID for the status record
      final effectiveUserId = CaregiverService.getEffectiveUserId();
      
      // Add status record to MedicationStatus collection (what dashboard reads)
      await FirebaseFirestore.instance
          .collection('MedicationStatus')
          .add({
         'medicationId': medicationId,
        'status': status,
        'userId': effectiveUserId, // Add userId for charts query
        'timestamp': FieldValue.serverTimestamp(),
        'actionTime': DateTime.now(),
      });
      print('✅ Medication status updated to: $status for $medicationId');
    } catch (e) {
      print('❌ Error updating medication status: $e');
    }
  }

  // Schedule snooze alarm
  static void _scheduleSnoozeAlarm(
    String medicineName,
    String instructions,
    String time,
    String medicationId,
  ) {
    Timer(const Duration(minutes: 10), () {
      showRealAlarm(
        medicineName: medicineName,
        instructions: instructions,
        time: 'Snoozed - $time',
        medicationId: medicationId,
      );
    });
  }

  // Test immediate alarm function for dashboard
  static Future<void> testAlarm() async {
    await showRealAlarm(
      medicineName: 'Test Medicine',
      instructions: 'This is a test alarm',
      time: DateTime.now().toString().substring(11, 16),
      medicationId: 'test_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // NEW: Test scheduled alarm (will ring in 30 seconds)
  static Future<void> testScheduledAlarm() async {
    final scheduledTime = DateTime.now().add(const Duration(seconds: 30));
    
    await scheduleAlarm(
      scheduledTime: scheduledTime,
      medicineName: 'Test Scheduled Alarm',
      instructions: 'This alarm was scheduled 30 seconds ago!',
      medicationId: 'scheduled_test_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    print('🧪 Test alarm scheduled for: $scheduledTime');
    print('⏰ It will ring in 30 seconds!');
  }

  // NEW: Schedule alarm for a specific time today
  static Future<void> scheduleAlarmForTimeToday({
    required int hour,
    required int minute,
    required String medicineName,
    required String instructions,
    required String medicationId,
  }) async {
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
    
    // If the time has passed today, schedule for tomorrow
    if (scheduledTime.millisecondsSinceEpoch < now.millisecondsSinceEpoch) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
      print('⏰ Time has passed today, scheduling for tomorrow: $scheduledTime');
    }
    
    await scheduleAlarm(
      scheduledTime: scheduledTime,
      medicineName: medicineName,
      instructions: instructions,
      medicationId: medicationId,
    );
  }

  // NEW: Get list of scheduled alarm IDs
  static List<int> getScheduledAlarmIds() {
    print('📋 Currently tracking ${_scheduledAlarmIds.length} scheduled alarms');
    return List.from(_scheduledAlarmIds);
  }

  // NEW: Cancel specific scheduled alarm
  static Future<void> cancelScheduledAlarm(int alarmId) async {
    try {
      await Alarm.stop(alarmId);
      await _notifications.cancel(alarmId + 10000);
      _scheduledAlarmIds.remove(alarmId);
      print('✅ Cancelled scheduled alarm with ID: $alarmId');
    } catch (e) {
      print('❌ Error cancelling alarm: $e');
    }
  }

  // NEW: Quick schedule alarm for next few minutes (for testing)
  static Future<void> scheduleTestAlarmInMinutes(int minutes) async {
    final scheduledTime = DateTime.now().add(Duration(minutes: minutes));
    
    await scheduleAlarm(
      scheduledTime: scheduledTime,
      medicineName: 'Test Alarm ($minutes min)',
      instructions: 'This alarm was scheduled $minutes minutes ago for testing!',
      medicationId: 'test_${minutes}min_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    print('🧪 Test alarm scheduled for $minutes minutes from now');
    print('⏰ Will ring at: $scheduledTime');
  }

  // Stop all alarms
  static Future<void> stopAllAlarms() async {
    try {
      await Alarm.stopAll();
      await _notifications.cancelAll();
      _isAlarmActive = false;
      _scheduledAlarmIds.clear();
      print('✅ All alarms stopped');
    } catch (e) {
      print('❌ Error stopping all alarms: $e');
    }
  }

  // NEW: Request battery optimization exemption
  static Future<void> requestBatteryOptimizationExemption() async {
    try {
      // This would typically be done through platform channels
      // For now, we'll just log the request
      print('🔋 Requesting battery optimization exemption...');
      print('📱 Please manually disable battery optimization for this app in Settings > Apps > PHarmony > Battery > Unrestricted');
    } catch (e) {
      print('❌ Error requesting battery optimization exemption: $e');
    }
  }

  // NEW: Test single alarm (no duplicates)
  static Future<void> testSingleAlarm() async {
    print('🧪 Testing single alarm (no duplicates)...');
    await showRealAlarm(
      medicineName: 'Single Test Medicine',
      instructions: 'This should show only ONE alarm screen',
      time: DateTime.now().toString().substring(11, 16),
      medicationId: 'single_test_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // NEW: Test direct alarm screen (bypass notification system)
  static Future<void> testDirectAlarmScreen() async {
    print('🧪 Testing direct alarm screen (bypass notifications)...');
    
    if (_context == null || !_context!.mounted) {
      print('❌ Context not available for direct alarm test');
      return;
    }

    try {
      _isAlarmActive = true;
      _isAlarmScreenOpen = true;
      
      // Show alarm screen directly without alarm package
      final route = MaterialPageRoute(
        builder: (context) => ReminderAlarmScreen(
          medicineName: 'Direct Test Medicine',
          instructions: 'This is a direct alarm screen test',
          time: DateTime.now().toString().substring(11, 16),
          onTaken: () {
            print('✅ Direct alarm - Medicine taken');
            _isAlarmActive = false;
            _isAlarmScreenOpen = false;
            Navigator.of(context).pop();
          },
          onSkipped: () {
            print('⏭️ Direct alarm - Medicine skipped');
            _isAlarmActive = false;
            _isAlarmScreenOpen = false;
            Navigator.of(context).pop();
          },
          onSnoozed: () {
            print('😴 Direct alarm - Medicine snoozed');
            _isAlarmActive = false;
            _isAlarmScreenOpen = false;
            Navigator.of(context).pop();
          },
        ),
        fullscreenDialog: true,
      );

      Navigator.of(_context!).push(route);
      print('✅ Direct alarm screen opened');
      
    } catch (e) {
      print('❌ Error showing direct alarm screen: $e');
      _isAlarmActive = false;
      _isAlarmScreenOpen = false;
    }
  }

  // NEW: Get stored medication data for an alarm
  static Map<String, dynamic>? getAlarmData(int alarmId) {
    final data = _alarmData[alarmId];
    print('🔍 Getting alarm data for ID: $alarmId');
    print('  - Found data: $data');
    return data;
  }

  // NEW: Debug function to show all stored alarm data
  static void debugShowAllAlarmData() {
    print('🔍 ===== DEBUG: ALL STORED ALARM DATA =====');
    print('Total stored alarms: ${_alarmData.length}');
    _alarmData.forEach((alarmId, data) {
      print('  Alarm ID: $alarmId');
      print('    - Medicine: ${data['medicineName']}');
      print('    - Instructions: ${data['instructions']}');
      print('    - Medication ID: ${data['medicationId']}');
      print('    - Scheduled Time: ${data['scheduledTime']}');
    });
    print('==========================================');
  }

  // NEW: Check specific alarm data
  static void debugCheckSpecificAlarm(int alarmId) {
    print('🔍 ===== DEBUG: CHECKING ALARM ID $alarmId =====');
    final data = _alarmData[alarmId];
    if (data != null) {
      print('✅ Found data for alarm ID: $alarmId');
      print('  - Medicine: ${data['medicineName']}');
      print('  - Instructions: ${data['instructions']}');
      print('  - Medication ID: ${data['medicationId']}');
      print('  - Scheduled Time: ${data['scheduledTime']}');
    } else {
      print('❌ No data found for alarm ID: $alarmId');
      print('Available alarm IDs: ${_alarmData.keys.toList()}');
    }
    print('==========================================');
  }

  // NEW: Test alarm with specific medication data
  static Future<void> testAlarmWithData({
    required String medicineName,
    required String instructions,
  }) async {
    print('🧪 Testing alarm with specific data: $medicineName');
    print('📝 Instructions: $instructions');
    
    if (_context == null || !_context!.mounted) {
      print('❌ Context not available for alarm test');
      return;
    }

    try {
      _isAlarmActive = true;
      _isAlarmScreenOpen = true;
      
      // Show alarm screen with specific medication data
      final route = MaterialPageRoute(
        builder: (context) => ReminderAlarmScreen(
          medicineName: medicineName,
          instructions: instructions,
          time: DateTime.now().toString().substring(11, 16),
          onTaken: () {
            print('✅ Test alarm - Medicine taken: $medicineName');
            _isAlarmActive = false;
            _isAlarmScreenOpen = false;
            Navigator.of(context).pop();
          },
          onSkipped: () {
            print('⏭️ Test alarm - Medicine skipped: $medicineName');
            _isAlarmActive = false;
            _isAlarmScreenOpen = false;
            Navigator.of(context).pop();
          },
          onSnoozed: () {
            print('😴 Test alarm - Medicine snoozed: $medicineName');
            _isAlarmActive = false;
            _isAlarmScreenOpen = false;
            Navigator.of(context).pop();
          },
        ),
        fullscreenDialog: true,
      );

      Navigator.of(_context!).push(route);
      print('✅ Test alarm screen opened with data: $medicineName');
      
    } catch (e) {
      print('❌ Error showing test alarm screen: $e');
      _isAlarmActive = false;
      _isAlarmScreenOpen = false;
    }
  }

  // NEW: Test with real medication data
  static Future<void> testRealMedicationAlarm() async {
    await testAlarmWithData(
      medicineName: 'Ascomp',
      instructions: 'Take 1 tablet with food',
    );
  }

  // NEW: Test scheduled alarm with correct data (30 seconds)
  static Future<void> testScheduledAlarmWithData() async {
    print('🧪 Testing scheduled alarm with correct data (30 seconds)...');
    
    final scheduledTime = DateTime.now().add(const Duration(seconds: 30));
    
    await scheduleAlarm(
      scheduledTime: scheduledTime,
      medicineName: 'Durlaza',
      instructions: 'Take 1 pill before meals',
      medicationId: 'test_durlaza_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    print('🧪 Test alarm scheduled for: $scheduledTime');
    print('⏰ It will ring in 30 seconds with correct medication data!');
    
    // Show debug information
    debugShowAllAlarmData();
  }

  // NEW: Test alarm scheduling and immediate verification
  static Future<void> testAlarmSchedulingAndVerification() async {
    print('🧪 ===== TESTING ALARM SCHEDULING AND VERIFICATION =====');
    
    final scheduledTime = DateTime.now().add(const Duration(seconds: 10));
    final testAlarmId = _currentAlarmId + 1;
    
    print('📅 Scheduling test alarm with ID: $testAlarmId');
    print('⏰ Scheduled time: $scheduledTime');
    
    await scheduleAlarm(
      scheduledTime: scheduledTime,
      medicineName: 'Test Verification Medicine',
      instructions: 'Take 2 tablets with water',
      medicationId: 'test_verification_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    print('✅ Alarm scheduled, now verifying stored data...');
    
    // Immediately check if data was stored
    debugCheckSpecificAlarm(testAlarmId);
    
    // Also show all stored data
    debugShowAllAlarmData();
    
    print('🧪 Test alarm will ring in 10 seconds!');
  }

  // NEW: Test immediate alarm with specific data
  static Future<void> testImmediateAlarmWithData() async {
    print('🧪 Testing immediate alarm with specific data...');
    
    if (_context == null || !_context!.mounted) {
      print('❌ Context not available for immediate alarm test');
      return;
    }

    try {
      _isAlarmActive = true;
      _currentAlarmId++;
      final alarmId = _currentAlarmId;
      
      // Store medication data for this alarm
      _alarmData[alarmId] = {
        'medicineName': 'Test Medicine - Immediate',
        'instructions': 'Take 2 tablets with water',
        'medicationId': 'test_immediate_${DateTime.now().millisecondsSinceEpoch}',
        'scheduledTime': DateTime.now(),
      };
      
      print('✅ Stored alarm data for immediate test:');
      print('  - Alarm ID: $alarmId');
      print('  - Stored data: ${_alarmData[alarmId]}');
      
      // Show alarm screen immediately
      _showAlarmScreen(
        medicineName: 'Test Medicine - Immediate',
        instructions: 'Take 2 tablets with water',
        time: DateTime.now().toString().substring(11, 16),
        medicationId: 'test_immediate_${DateTime.now().millisecondsSinceEpoch}',
        alarmId: alarmId,
      );
      
    } catch (e) {
      print('❌ Error showing immediate test alarm: $e');
      _isAlarmActive = false;
    }
  }

  // NEW: Test blood pressure reminder
  static Future<void> testBloodPressureReminder() async {
    print('🧪 Testing blood pressure reminder (30 seconds)...');
    
    final scheduledTime = DateTime.now().add(const Duration(seconds: 30));
    
    await scheduleAlarm(
      scheduledTime: scheduledTime,
      medicineName: 'Blood Pressure Check',
      instructions: 'Time to check your blood pressure reading',
      medicationId: 'test_bp_reminder_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    print('🧪 Blood pressure reminder scheduled for: $scheduledTime');
    print('⏰ It will ring in 30 seconds!');
    
    // Show debug information
    debugShowAllAlarmData();
  }
} 
