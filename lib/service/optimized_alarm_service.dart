import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/reminder_alarm_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:alarm/alarm.dart';
import '../service/caregiver_service.dart';

class OptimizedAlarmService {
  static final OptimizedAlarmService _instance = OptimizedAlarmService._internal();
  factory OptimizedAlarmService() => _instance;
  OptimizedAlarmService._internal();

  static BuildContext? _context;
  static int _currentAlarmId = 1000;
  static bool _isAlarmActive = false;
  static bool _isAlarmScreenOpen = false;
  static final Map<int, Map<String, dynamic>> _alarmData = {};

  static void setContext(BuildContext context) {
    _context = context;
  }

  /// Schedule alarm with precise timing - single system approach
  static Future<void> scheduleAlarm({
    required DateTime scheduledTime,
    required String medicineName,
    required String instructions,
    required String medicationId,
  }) async {
    print('📅 ===== SCHEDULING PRECISE ALARM =====');
    print('  - Medicine: $medicineName');
    print('  - Scheduled time: $scheduledTime');
    print('  - Current time: ${DateTime.now()}');
    
    // Ensure scheduled time is in the future
    final now = DateTime.now();
    DateTime finalScheduledTime = scheduledTime;
    if (scheduledTime.millisecondsSinceEpoch <= now.millisecondsSinceEpoch) {
      print('⚠️ Scheduled time is in the past! Adding 1 day...');
      finalScheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    
    final timeDifference = finalScheduledTime.difference(now);
    print('  - Time until alarm: ${timeDifference.inMinutes} minutes and ${timeDifference.inSeconds % 60} seconds');

    try {
      _currentAlarmId++;
      final alarmId = _currentAlarmId;
      
      // Store medication data for this alarm
      _alarmData[alarmId] = {
        'medicineName': medicineName,
        'instructions': instructions,
        'medicationId': medicationId,
        'scheduledTime': finalScheduledTime,
      };
      
      // Use alarm package with optimized settings for precise timing
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: finalScheduledTime,
        assetAudioPath: 'assets/audio/reminder.wav',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          fadeDuration: const Duration(milliseconds: 500), // Faster fade
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
      
      print('✅ Precise alarm scheduled successfully with ID: $alarmId');
      print('   Will trigger at: $finalScheduledTime');
      print('   Stored data: ${_alarmData[alarmId]}');
      
      return;
    } catch (e) {
      print('❌ Error scheduling precise alarm: $e');
      rethrow;
    }
  }

  /// Show alarm immediately with minimal overhead
  static Future<void> showAlarm({
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

    // Prevent duplicate alarms
    if (_isAlarmActive) {
      print('⚠️ Alarm already active, ignoring duplicate request');
      return;
    }

    try {
      _isAlarmActive = true;
      _currentAlarmId++;
      final alarmId = _currentAlarmId;
      
      // Store medication data
      _alarmData[alarmId] = {
        'medicineName': medicineName,
        'instructions': instructions,
        'medicationId': medicationId,
        'scheduledTime': DateTime.now(),
      };
      
      // Set up immediate alarm with optimized settings
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: DateTime.now(), // Trigger immediately
        assetAudioPath: 'assets/audio/reminder.wav',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          fadeDuration: const Duration(milliseconds: 500), // Faster fade
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

      // Start the alarm immediately
      await Alarm.set(alarmSettings: alarmSettings);
      print('✅ Immediate alarm started with ID: $alarmId');

      // Show alarm screen immediately (no delays)
      _showAlarmScreen(
        medicineName: medicineName,
        instructions: instructions,
        time: time,
        medicationId: medicationId,
        alarmId: alarmId,
      );

    } catch (e) {
      print('❌ Error showing immediate alarm: $e');
      _isAlarmActive = false;
    }
  }

  /// Show alarm screen with minimal overhead
  static Future<void> _showAlarmScreen({
    required String medicineName,
    required String instructions,
    required String time,
    required String medicationId,
    required int alarmId,
  }) async {
    if (_context == null || !_context!.mounted) return;
    
    // Prevent multiple alarm screens
    if (_isAlarmScreenOpen) {
      print('⚠️ Alarm screen already open, ignoring duplicate request');
      return;
    }

    _isAlarmScreenOpen = true;

    // Show alarm screen immediately without additional checks
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

  /// Handle medicine taken
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

  /// Handle medicine skipped
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

  /// Handle medicine snoozed
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

  /// Stop alarm with minimal overhead
  static Future<void> _stopAlarm(int alarmId) async {
    try {
      print('🛑 Stopping alarm with ID: $alarmId');
      
      await Alarm.stop(alarmId);
      _isAlarmActive = false;
      
      // Clean up stored alarm data
      _alarmData.remove(alarmId);
      
      // Add haptic feedback
      HapticFeedback.mediumImpact();
      
      print('✅ Alarm stopped successfully');
    } catch (e) {
      print('❌ Error stopping alarm: $e');
    }
  }

  /// Close alarm screen
  static void _closeAlarmScreen() {
    if (_context != null && _context!.mounted) {
      Navigator.of(_context!).pop();
    }
    _isAlarmScreenOpen = false;
  }

  /// Update medication status
  static Future<void> _updateMedicationStatus(String medicationId, String status) async {
    try {
      final effectiveUserId = CaregiverService.getEffectiveUserId();
      
      await FirebaseFirestore.instance
          .collection('MedicationStatus')
          .add({
        'medicationId': medicationId,
        'status': status,
        'userId': effectiveUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'actionTime': DateTime.now(),
      });
      print('✅ Medication status updated to: $status for $medicationId');
    } catch (e) {
      print('❌ Error updating medication status: $e');
    }
  }

  /// Schedule snooze alarm
  static void _scheduleSnoozeAlarm(
    String medicineName,
    String instructions,
    String time,
    String medicationId,
  ) {
    Timer(const Duration(minutes: 10), () {
      showAlarm(
        medicineName: 'Snoozed: $medicineName',
        instructions: instructions,
        time: 'Snoozed - $time',
        medicationId: '${medicationId}_snoozed',
      );
    });
  }

  /// Test immediate alarm
  static Future<void> testAlarm() async {
    await showAlarm(
      medicineName: 'Test Medicine',
      instructions: 'This is a test alarm',
      time: DateTime.now().toString().substring(11, 16),
      medicationId: 'test_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Test scheduled alarm (will ring in 30 seconds)
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

  /// Stop all alarms
  static Future<void> stopAllAlarms() async {
    try {
      await Alarm.stopAll();
      _isAlarmActive = false;
      _alarmData.clear();
      print('✅ All alarms stopped');
    } catch (e) {
      print('❌ Error stopping all alarms: $e');
    }
  }

  /// Get stored medication data for an alarm
  static Map<String, dynamic>? getAlarmData(int alarmId) {
    final data = _alarmData[alarmId];
    print('🔍 Getting alarm data for ID: $alarmId');
    print('  - Found data: $data');
    return data;
  }

  /// Debug function to show all stored alarm data
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
} 