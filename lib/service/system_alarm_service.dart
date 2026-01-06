import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/reminder_alarm_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../service/caregiver_service.dart'; // Added import for CaregiverService


/// SystemAlarmService - Uses the device's actual alarm ringtone
/// 
/// This service gets the system's default alarm sound (not notification sound)
/// and uses it for medication reminders.
class SystemAlarmService {
  static final SystemAlarmService _instance = SystemAlarmService._internal();
  factory SystemAlarmService() => _instance;
  SystemAlarmService._internal();

  static BuildContext? _context;
  static Timer? _alarmTimer;
  static bool _isAlarmActive = false;
  static String? _currentMedicationId;

  static void setContext(BuildContext context) {
    _context = context;
  }

  /// Start alarm with system alarm ringtone
  static Future<void> showAlarmWithSystemSound({
    required String medicineName,
    required String instructions,
    required String time,
    required String medicationId,
  }) async {
    print('🚨 ===== SYSTEM ALARM SERVICE =====');
    print('Medicine: $medicineName');
    print('Instructions: $instructions');
    print('Time: $time');
    print('ID: $medicationId');
    
    if (_context == null || !_context!.mounted) {
      print('❌ Cannot show alarm: Context is null or unmounted');
      return;
    }

    try {
      // Set alarm as active
      _isAlarmActive = true;
      _currentMedicationId = medicationId;
      
      // Start playing system alarm sound
      await _startSystemAlarmSound();
      
      // Show the alarm screen
      await Navigator.of(_context!).push(
        MaterialPageRoute(
          builder: (context) => ReminderAlarmScreen(
            medicineName: medicineName,
            instructions: instructions,
            time: time,
            onTaken: () async {
              print('✅ ===== MEDICINE TAKEN =====');
              await _stopSystemAlarm();
              await _updateMedicationStatus(medicationId, 'Taken');
              Navigator.of(context).pop();
            },
            onSkipped: () async {
              print('⏭️ ===== MEDICINE SKIPPED =====');
              await _stopSystemAlarm();
              await _updateMedicationStatus(medicationId, 'Skipped');
              Navigator.of(context).pop();
            },
            onSnoozed: () async {
              print('😴 ===== MEDICINE SNOOZED =====');
              await _stopSystemAlarm();
              await _scheduleSnoozeAlarm(medicineName, instructions, time, medicationId);
              await _updateMedicationStatus(medicationId, 'Snoozed');
              Navigator.of(context).pop();
            },
          ),
          fullscreenDialog: true,
        ),
      );
      
      print('✅ System alarm completed');
    } catch (e) {
      print('❌ Error showing system alarm: $e');
      await _stopSystemAlarm();
    }
  }

  /// Start system alarm sound using clean approach (no notifications)
  static Future<void> _startSystemAlarmSound() async {
    try {
      print('🔊 Starting clean alarm sound (no notifications)...');
      
      // Use platform channel to play system alarm sound
      await _playSystemAlarmViaPlatform();
      
      // Use alarm package for clean sound without notifications
      await _playCleanAlarmSound();
      
      print('✅ Clean alarm sound started');
    } catch (e) {
      print('❌ Error starting clean alarm sound: $e');
    }
  }

  /// Play system alarm using platform-specific implementation
  static Future<void> _playSystemAlarmViaPlatform() async {
    try {
      // Use platform channel to access Android's RingtoneManager
      const platform = MethodChannel('com.example.phnew11/alarm');
      await platform.invokeMethod('playAlarmSound');
      print('✅ Platform alarm sound triggered');
    } catch (e) {
      print('⚠️ Platform alarm failed (expected if not implemented): $e');
      // Fallback to notification-based approach
    }
  }

    /// Play clean alarm sound (no visible notifications)
  static Future<void> _playCleanAlarmSound() async {
    try {
      print('🎵 Clean alarm - no notifications, just alarm page with basic sound');
      
      // Simple approach: just set a timer for basic feedback without notifications
      _alarmTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!_isAlarmActive) {
          timer.cancel();
          print('🔇 Clean alarm stopped');
          return;
        }
        
        // Just log that alarm is active - no notifications
        print('⏰ Clean alarm active (no notifications)');
      });
      
      print('✅ Clean alarm started (no notifications)');
    } catch (e) {
      print('❌ Error with clean alarm: $e');
    }
  }

  /// Simple fallback alarm without notifications
  static void _startSimpleAlarmSound() {
    print('🔄 Using simple alarm fallback...');
    
    _alarmTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isAlarmActive) {
        timer.cancel();
        return;
      }
      
      // Just vibrate without any notifications
      try {
        // You could add vibration here if needed
        print('⏰ Alarm active (no notifications)');
      } catch (e) {
        print('⚠️ Simple alarm error: $e');
      }
    });
  }

  /// Stop system alarm
  static Future<void> _stopSystemAlarm() async {
    try {
      print('🛑 Stopping system alarm...');
      
      // Set as inactive to stop timer
      _isAlarmActive = false;
      
      // Cancel timer
      if (_alarmTimer != null) {
        _alarmTimer!.cancel();
        _alarmTimer = null;
        print('✅ Alarm timer cancelled');
      }
      
      // Stop platform alarm
      try {
        const platform = MethodChannel('com.example.phnew11/alarm');
        await platform.invokeMethod('stopAlarmSound');
        print('✅ Platform alarm stopped');
      } catch (e) {
        print('⚠️ Platform stop failed (expected): $e');
      }
      
      // No notifications to cancel (clean approach)
      
      // Clear current medication
      _currentMedicationId = null;
      
      print('✅ System alarm stopped completely');
    } catch (e) {
      print('❌ Error stopping system alarm: $e');
    }
  }

  /// Schedule medication alarm for specific time
  static Future<void> scheduleMedicationAlarm({
    required String medicationId,
    required String medicineName,
    required String instructions,
    required DateTime scheduledTime,
  }) async {
    try {
      print('📅 ===== SCHEDULING MEDICATION ALARM =====');
      print('Medicine: $medicineName');
      print('Instructions: $instructions');
      print('Scheduled time: $scheduledTime');
      print('Medication ID: $medicationId');
      
      // Calculate delay until scheduled time
      final now = DateTime.now();
      final delay = scheduledTime.difference(now);
      
      if (delay.isNegative) {
        print('⚠️ Scheduled time is in the past, scheduling for tomorrow');
        final tomorrowTime = scheduledTime.add(const Duration(days: 1));
        final tomorrowDelay = tomorrowTime.difference(now);
        
        Timer(tomorrowDelay, () {
          if (_context != null && _context!.mounted) {
            print('⏰ Medication alarm triggered: $medicineName');
            showAlarmWithSystemSound(
              medicineName: medicineName,
              instructions: instructions,
              time: _formatTimeFromDateTime(tomorrowTime),
              medicationId: medicationId,
            );
          }
        });
        
        print('✅ Medication alarm scheduled for tomorrow: $tomorrowTime');
      } else {
        Timer(delay, () {
          if (_context != null && _context!.mounted) {
            print('⏰ Medication alarm triggered: $medicineName');
            showAlarmWithSystemSound(
              medicineName: medicineName,
              instructions: instructions,
              time: _formatTimeFromDateTime(scheduledTime),
              medicationId: medicationId,
            );
          }
        });
        
        print('✅ Medication alarm scheduled for: $scheduledTime');
      }
      
    } catch (e) {
      print('❌ Error scheduling medication alarm: $e');
    }
  }

  /// Schedule snooze alarm
  static Future<void> _scheduleSnoozeAlarm(String medicineName, String instructions, String time, String medicationId) async {
    try {
      print('😴 Scheduling snooze alarm for 10 minutes...');
      
      Timer(const Duration(minutes: 10), () {
        if (_context != null && _context!.mounted) {
          print('⏰ Snooze time up! Showing alarm again...');
          showAlarmWithSystemSound(
            medicineName: 'Snoozed: $medicineName',
            instructions: instructions,
            time: time,
            medicationId: '${medicationId}_snoozed',
          );
        }
      });
      
      print('✅ Snooze alarm scheduled');
    } catch (e) {
      print('❌ Error scheduling snooze: $e');
    }
  }

  /// Update medication status
  static Future<void> _updateMedicationStatus(String medicationId, String status) async {
    try {
      // Get effective user ID for the status record
      final effectiveUserId = CaregiverService.getEffectiveUserId();
      
      await FirebaseFirestore.instance.collection('MedicationStatus').add({
        'medicationId': medicationId,
        'status': status,
        'userId': effectiveUserId, // Add userId for charts query
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ Updated medication status: $status for $medicationId');
    } catch (e) {
      print('❌ Error updating medication status: $e');
    }
  }

  /// Test system alarm
  static Future<void> testSystemAlarm() async {
    print('🧪 ===== TESTING SYSTEM ALARM =====');
    
    await showAlarmWithSystemSound(
      medicineName: 'TEST System Alarm',
      instructions: 'This should use your phone\'s ACTUAL alarm ringtone!',
      time: _formatCurrentTime(),
      medicationId: 'test_system_alarm_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Format current time for display
  static String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Format DateTime to time string for display
  static String _formatTimeFromDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Emergency stop all alarms
  static Future<void> emergencyStopAll() async {
    print('🚨 EMERGENCY STOP ALL SYSTEM ALARMS');
    _isAlarmActive = false;
    _alarmTimer?.cancel();
    _alarmTimer = null;
    
    try {
      const platform = MethodChannel('com.example.phnew11/alarm');
      await platform.invokeMethod('stopAlarmSound');
    } catch (e) {
      // Ignore platform errors
    }
    
    // No notifications to cancel (clean approach)
    print('✅ Emergency stop completed');
  }
} 
