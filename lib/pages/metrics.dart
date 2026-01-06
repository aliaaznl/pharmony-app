import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/twilio_service.dart';
import '../service/alarm_service.dart';
import '../service/caregiver_service.dart';
import '../pages/noti_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Metrics extends StatefulWidget {
  const Metrics({super.key});

  @override
  State<Metrics> createState() => _MetricsState();
}

class _MetricsState extends State<Metrics> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Form controllers
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  final TextEditingController _pulseController = TextEditingController();
  
  DateTime _selectedDateTime = DateTime.now();
  bool _reminderEnabled = false;
  bool _isLoading = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  String _reminderFrequency = 'Daily'; // Daily, Weekly, Custom
  final List<String> _reminderFrequencies = ['Daily', 'Weekly', 'Custom'];

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
    // Set context for alarm service
    AlarmService.setContext(context);
    // Initialize NotiService
    _initializeNotiService();
  }

  Future<void> _initializeNotiService() async {
    try {
      final notiService = NotiService();
      await notiService.initNotification();
      print('✅ NotiService initialized successfully');
    } catch (e) {
      print('❌ Error initializing NotiService: $e');
    }
  }

  Future<void> _loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final reminderHour = prefs.getInt('bp_reminder_hour') ?? 9;
    final reminderMinute = prefs.getInt('bp_reminder_minute') ?? 0;
    
    print('🔍 Loading reminder settings:');
    print('  - Hour: $reminderHour');
    print('  - Minute: $reminderMinute');
    print('  - Time: ${reminderHour.toString().padLeft(2, '0')}:${reminderMinute.toString().padLeft(2, '0')}');
    
    setState(() {
      _reminderEnabled = prefs.getBool('bp_reminder_enabled') ?? false;
      _reminderTime = TimeOfDay(hour: reminderHour, minute: reminderMinute);
      _reminderFrequency = prefs.getString('bp_reminder_frequency') ?? 'Daily';
    });
    
    print('✅ Reminder time loaded: ${_reminderTime.format(context)}');
  }

  Future<void> _saveReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    print('💾 Saving reminder settings:');
    print('  - Enabled: $_reminderEnabled');
    print('  - Hour: ${_reminderTime.hour}');
    print('  - Minute: ${_reminderTime.minute}');
    print('  - Time: ${_reminderTime.format(context)}');
    print('  - Frequency: $_reminderFrequency');
    
    await prefs.setBool('bp_reminder_enabled', _reminderEnabled);
    await prefs.setInt('bp_reminder_hour', _reminderTime.hour);
    await prefs.setInt('bp_reminder_minute', _reminderTime.minute);
    await prefs.setString('bp_reminder_frequency', _reminderFrequency);
    
    print('✅ Reminder settings saved successfully');
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _saveReading() async {
    final user = _auth.currentUser;
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    
    // Allow if user is authenticated OR if caregiver access has effective user ID
    if (effectiveUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save readings'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_systolicController.text.isEmpty || 
        _diastolicController.text.isEmpty || 
        _pulseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final systolic = double.tryParse(_systolicController.text);
      final diastolic = double.tryParse(_diastolicController.text);
      final pulse = double.tryParse(_pulseController.text);

      if (systolic == null || diastolic == null || pulse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid numbers'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      await _firestore.collection('BloodPressure').add({
        'userId': effectiveUserId, // Use effective user ID (patient if in caregiver mode)
        'systolic': systolic,
        'diastolic': diastolic,
        'pulse': pulse,
        'timestamp': Timestamp.fromDate(_selectedDateTime),
        'category': _getBloodPressureCategory(systolic, diastolic),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Check for hypertensive crisis and send SMS alert if needed
      await _checkAndSendHypertensiveCrisisAlert(systolic, diastolic);

      // Clear form
      _systolicController.clear();
      _diastolicController.clear();
      _pulseController.clear();
      setState(() {
        _selectedDateTime = DateTime.now();
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blood pressure reading saved successfully!'),
          backgroundColor: Color(0xFF0d6b5c),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving reading: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getBloodPressureCategory(double systolic, double diastolic) {
    if (systolic < 120 && diastolic < 80) {
      return 'Normal';
    } else if (systolic >= 120 && systolic <= 129 && diastolic < 80) {
      return 'Elevated';
    } else if ((systolic >= 130 && systolic <= 139) || (diastolic >= 80 && diastolic <= 89)) {
      return 'Hypertension Stage 1';
    } else if (systolic > 180 || diastolic > 120) {
      return 'Hypertensive Crisis';
    } else if (systolic >= 140 || diastolic >= 90) {
      return 'Hypertension Stage 2';
    } else {
      return 'Unknown';
    }
  }

  Color _getBloodPressureColor(double systolic, double diastolic) {
    if (systolic < 120 && diastolic < 80) {
      return Colors.green; // Normal
    } else if (systolic >= 120 && systolic <= 129 && diastolic < 80) {
      return Colors.yellow; // Elevated
    } else if ((systolic >= 130 && systolic <= 139) || (diastolic >= 80 && diastolic <= 89)) {
      return Colors.amber; // Hypertension Stage 1 (darker yellow)
    } else if (systolic > 180 || diastolic > 120) {
      return Colors.red; // Hypertensive Crisis
    } else if (systolic >= 140 || diastolic >= 90) {
      return Colors.orange; // Hypertension Stage 2
    } else {
      return Colors.grey;
    }
  }

  /// Check for hypertensive crisis and send SMS alert if needed
  Future<void> _checkAndSendHypertensiveCrisisAlert(double systolic, double diastolic) async {
    try {
      // Check if current reading is hypertensive crisis
      if (systolic > 180 || diastolic > 120) {
        // Check consecutive high readings
        final consecutiveCount = await TwilioService.checkConsecutiveHighReadings();
        
        // Send alert if minimum consecutive high readings reached
        if (consecutiveCount >= 3) {
          final caregiverInfo = await TwilioService.getCaregiverInfo();
          
          if (caregiverInfo != null) {
            final success = await TwilioService.sendHypertensiveCrisisAlert(
              caregiverPhone: caregiverInfo['caregiverPhone'],
              patientName: caregiverInfo['patientName'],
              systolic: systolic,
              diastolic: diastolic,
              consecutiveCount: consecutiveCount,
            );
            
            if (success && mounted) {
              // Show confirmation that alert was sent
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.sms, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Emergency SMS sent to caregiver ($consecutiveCount consecutive high readings)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            } else if (!success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to send emergency SMS. Please contact your caregiver manually.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          } else if (mounted) {
            // No caregiver phone configured
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('HYPERTENSIVE CRISIS detected! Please add caregiver phone in Profile for emergency alerts.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Set Up',
                  textColor: Colors.white,
                  onPressed: () {
                    // Navigate to profile page
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
              ),
            );
          }
        } else if (consecutiveCount > 1 && mounted) {
          // Warning for multiple high readings (but less than 3)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('WARNING: $consecutiveCount consecutive high readings detected. Monitor closely.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking hypertensive crisis: $e');
    }
  }

  Future<void> _scheduleReminders() async {
    try {
      // Cancel existing reminders first
      await _cancelReminders();

      if (!_reminderEnabled) return;

      final now = DateTime.now();
      final scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        _reminderTime.hour,
        _reminderTime.minute,
      );

      // If the time has passed today, schedule for tomorrow
      final finalScheduledTime = scheduledTime.isBefore(now)
          ? scheduledTime.add(const Duration(days: 1))
          : scheduledTime;

      print('📅 Scheduling blood pressure notification for: ${_reminderTime.format(context)}');
      print('   Final scheduled time: $finalScheduledTime');

      // Schedule the reminder using NotiService for simple notifications
      final notiService = NotiService();
      
      // Ensure NotiService is initialized
      if (!notiService.isInitialized) {
        await notiService.initNotification();
      }
      
      await notiService.scheduleNotification(
        id: 2000 + DateTime.now().millisecondsSinceEpoch % 1000, // Unique ID
        title: 'Blood Pressure Check',
        body: 'Time to check your blood pressure reading',
        hour: finalScheduledTime.hour,
        minute: finalScheduledTime.minute,
      );

      // Schedule recurring reminders based on frequency
      if (_reminderFrequency == 'Daily') {
        // Schedule for next 7 days
        for (int i = 1; i <= 7; i++) {
          final nextScheduledTime = finalScheduledTime.add(Duration(days: i));
          await notiService.scheduleNotification(
            id: 2000 + i + (DateTime.now().millisecondsSinceEpoch % 1000),
            title: 'Blood Pressure Check',
            body: 'Time to check your blood pressure reading',
            hour: nextScheduledTime.hour,
            minute: nextScheduledTime.minute,
          );
        }
      } else if (_reminderFrequency == 'Weekly') {
        // Schedule for next 4 weeks
        for (int i = 1; i <= 4; i++) {
          final nextScheduledTime = finalScheduledTime.add(Duration(days: i * 7));
          await notiService.scheduleNotification(
            id: 2000 + i + (DateTime.now().millisecondsSinceEpoch % 1000),
            title: 'Blood Pressure Check',
            body: 'Time to check your blood pressure reading',
            hour: nextScheduledTime.hour,
            minute: nextScheduledTime.minute,
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Blood pressure notifications scheduled for ${_reminderTime.format(context)}'),
          backgroundColor: const Color(0xFF0d6b5c),
        ),
      );
    } catch (e) {
      print('❌ Error scheduling blood pressure reminders: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scheduling reminders: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelReminders() async {
    try {
      // Cancel all blood pressure reminders by canceling all notifications
      final notiService = NotiService();
      
      // Ensure NotiService is initialized
      if (!notiService.isInitialized) {
        await notiService.initNotification();
      }
      
      await notiService.cancelALLNotifications();
      
      print('✅ Blood pressure notifications cancelled');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blood pressure notifications cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error cancelling blood pressure reminders: $e');
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String unit,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0d6b5c),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: unit,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0d6b5c), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  // Show reminder setup popup
  Future<void> _showReminderSetupDialog() async {
    TimeOfDay tempReminderTime = _reminderTime;
    String tempReminderFrequency = _reminderFrequency;
    bool tempReminderEnabled = _reminderEnabled;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              title: Row(
                children: [
                  Icon(
                    Icons.alarm,
                    color: const Color(0xFF0d6b5c),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'BP Reminders',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Enable/Disable Switch
                  SwitchListTile(
                    title: const Text('Enable Reminders'),
                    subtitle: const Text('Get notified to check your blood pressure'),
                    value: tempReminderEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        tempReminderEnabled = value;
                      });
                    },
                    activeColor: const Color(0xFF0d6b5c),
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  if (tempReminderEnabled) ...[
                    const SizedBox(height: 16),
                    
                    // Time Selection
                    InkWell(
                      onTap: () async {
                        print('🕐 Opening time picker with initial time: ${tempReminderTime.format(context)}');
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: tempReminderTime,
                        );
                        if (pickedTime != null) {
                          print('✅ Time picked: ${pickedTime.format(context)} (${pickedTime.hour}:${pickedTime.minute})');
                          setState(() {
                            tempReminderTime = pickedTime;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: const Color(0xFF0d6b5c),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reminder Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  tempReminderTime.format(context),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.edit),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Frequency Selection
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.repeat,
                            color: const Color(0xFF0d6b5c),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reminder Frequency',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  tempReminderFrequency,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownButton<String>(
                            value: tempReminderFrequency,
                            items: _reminderFrequencies.map((String frequency) {
                              return DropdownMenuItem<String>(
                                value: frequency,
                                child: Text(frequency),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  tempReminderFrequency = newValue;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Status Preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0d6b5c).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF0d6b5c).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: const Color(0xFF0d6b5c),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reminders will be scheduled for ${tempReminderTime.format(context)} ${tempReminderFrequency.toLowerCase()}',
                              style: TextStyle(
                                color: const Color(0xFF0d6b5c),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Enable reminders to schedule blood pressure checks',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
                ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Update the main state
                    setState(() {
                      _reminderEnabled = tempReminderEnabled;
                      _reminderTime = tempReminderTime;
                      _reminderFrequency = tempReminderFrequency;
                    });
                    
                    // Save settings
                    await _saveReminderSettings();
                    
                    // Schedule or cancel reminders
                    if (tempReminderEnabled) {
                      await _scheduleReminders();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Blood pressure reminders enabled for ${tempReminderTime.format(context)}'),
                          backgroundColor: const Color(0xFF0d6b5c),
                        ),
                      );
                    } else {
                      await _cancelReminders();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Blood pressure reminders disabled'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0d6b5c),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Blood Pressure Monitor',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0d6b5c),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Container
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.monitor_heart,
                          color: Color(0xFF0d6b5c),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'New Reading',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0d6b5c),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Date and Time
                    const Text(
                      'Date & Time',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0d6b5c),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDateTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF0d6b5c)),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy - HH:mm').format(_selectedDateTime),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Blood Pressure Inputs
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _systolicController,
                            label: 'Systolic',
                            unit: 'mmHg',
                            hint: '120',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInputField(
                            controller: _diastolicController,
                            label: 'Diastolic',
                            unit: 'mmHg',
                            hint: '80',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Pulse Input
                    _buildInputField(
                      controller: _pulseController,
                      label: 'Pulse',
                      unit: 'bpm',
                      hint: '72',
                    ),
                    const SizedBox(height: 20),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveReading,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0d6b5c),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save Reading',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Reminder Setup Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              child: InkWell(
                onTap: _showReminderSetupDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0d6b5c).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _reminderEnabled ? Icons.alarm_on : Icons.alarm_off,
                          color: const Color(0xFF0d6b5c),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _reminderEnabled ? 'Reminders Active' : 'Set Up Reminders',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0d6b5c),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _reminderEnabled 
                                ? '${_reminderTime.format(context)} - $_reminderFrequency'
                                : 'Get notified to check your blood pressure',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // History Section
            Text(
              'Reading History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0d6b5c),
              ),
            ),
            const SizedBox(height: 12),
            
            StreamBuilder<QuerySnapshot>(
              stream: CaregiverService.getEffectiveUserId() != null
                  ? _firestore
                      .collection('BloodPressure')
                      .where('userId', isEqualTo: CaregiverService.getEffectiveUserId()!)
                      .orderBy('timestamp', descending: true)
                      .snapshots()
                  : Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('Error loading history')),
                    ),
                  );
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF0d6b5c))),
                    ),
                  );
                }
                
                final readings = snapshot.data?.docs ?? [];
                
                if (readings.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.monitor_heart_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No readings recorded yet',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first blood pressure reading above',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: readings.length,
                  itemBuilder: (context, index) {
                    final reading = readings[index].data() as Map<String, dynamic>;
                    final timestamp = (reading['timestamp'] as Timestamp).toDate();
                    final systolic = (reading['systolic'] as num).toDouble();
                    final diastolic = (reading['diastolic'] as num).toDouble();
                    final pulse = (reading['pulse'] as num).toDouble();
                    final category = reading['category'] as String? ?? _getBloodPressureCategory(systolic, diastolic);
                    final statusColor = _getBloodPressureColor(systolic, diastolic);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        height: 110, // Increased height to prevent overflow
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12), // Reduced padding slightly
                          child: Row(
                            children: [
                              // Leading Icon
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(color: statusColor, width: 2),
                                ),
                                child: Icon(
                                  Icons.monitor_heart,
                                  color: statusColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Main Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min, // Prevent Column from expanding
                                  children: [
                                    Text(
                                      '${systolic.toInt()}/${diastolic.toInt()} mmHg',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17, // Slightly reduced font size
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2), // Reduced spacing
                                    Text(
                                      'Pulse: ${pulse.toInt()} bpm',
                                      style: const TextStyle(fontSize: 13), // Slightly reduced font size
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2), // Reduced spacing
                                    Text(
                                      DateFormat('dd/MM/yyyy - HH:mm').format(timestamp),
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Trailing Badge
                              Container(
                                width: 85, // Slightly reduced width
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9, // Reduced font size
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
} 
