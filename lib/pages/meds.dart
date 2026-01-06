import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:phnew11/pages/noti_service.dart';
import '../home.dart';
import 'reminder_alarm_screen.dart';
import '../service/notification_service.dart';
import '../service/alarm_service.dart';
import 'medication_search.dart';
import '../service/caregiver_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  //init notifications
  NotiService().initNotification();
}

class MedicationPage extends StatefulWidget {
  final DateTime selectedDate;

  const MedicationPage({super.key, required this.selectedDate});

  @override
  _MedicationPageState createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  final TextEditingController _medicationNameController =
      TextEditingController();
  final TextEditingController _doseAmountController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedDoseType = 'pill';
  String _selectedMedicationType = 'tablets';
  String _selectedIntakeTime = 'before meals';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 7));

  final List<Map<String, dynamic>> _doses = [
    {'dose': '', 'time': TimeOfDay.now()},
  ];

  @override
  void initState() {
    super.initState();
    // Set context for notification handling
    NotificationService.setContext(context);
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _doses[index]['time'],
    );
    if (picked != null) {
      setState(() {
        _doses[index]['time'] = picked;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _addDose() {
    setState(() {
      _doses.add({'dose': '', 'time': TimeOfDay.now()});
    });
  }

  void _removeDose(int index) {
    setState(() {
      _doses.removeAt(index);
    });
  }

  Future<void> _saveMedication() async {
    final user = _auth.currentUser;
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    
    // Allow if user is authenticated OR if caregiver access has effective user ID
    if (effectiveUserId == null) return;

    // Validate input fields
    if (_medicationNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter medication name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_doseAmountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter dose amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final docRef = await _firestore.collection('Medications').add({
        'userId': effectiveUserId, // Use effective user ID (patient if in caregiver mode)
        'medicationName': _medicationNameController.text.trim(),
        'doseAmount': _doseAmountController.text.trim(),
        'doseType': _selectedDoseType,
        'medicationType': _selectedMedicationType,
        'intakeTime': _selectedIntakeTime,
        'doses':
            _doses
                .map(
                  (dose) => {
                    'time': '${dose['time'].hour}:${dose['time'].minute}',
                  },
                )
                .toList(),
        'startDate': DateFormat('dd/MM/yyyy').format(_startDate),
        'endDate': DateFormat('dd/MM/yyyy').format(_endDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Schedule notifications for each dose
      for (var i = 0; i < _doses.length; i++) {
        try {
          final dose = _doses[i];
          final time = dose['time'] as TimeOfDay;
          
          // Create a DateTime for today with the specified time
          final now = DateTime.now();
          final scheduledTime = DateTime(
            now.year,
            now.month,
            now.day,
            time.hour,
            time.minute,
          );
          
          // If the time has already passed today, schedule for tomorrow
          final finalScheduledTime = scheduledTime.isBefore(now) 
              ? scheduledTime.add(Duration(days: 1))
              : scheduledTime;

          // Create medication data for the notification
          final medicationData = {
            'id': '${docRef.id}_dose_$i',
            'name': _medicationNameController.text.trim(),
            'instructions': 'Take ${_doseAmountController.text.trim()} $_selectedDoseType $_selectedIntakeTime',
            'time': time.format(context),
            'doseAmount': _doseAmountController.text.trim(),
            'doseType': _selectedDoseType,
            'intakeTime': _selectedIntakeTime,
            'doseIndex': i,
          };

          // Generate unique notification ID
          final notificationId = '${docRef.id}_$i'.hashCode.abs() % 2147483647;

          // Use the new full-screen alarm system
          await AlarmService.scheduleAlarm(
            scheduledTime: finalScheduledTime,
            medicineName: _medicationNameController.text.trim(),
            instructions: "Take ${_doseAmountController.text.trim()} $_selectedDoseType $_selectedIntakeTime",
            medicationId: '${docRef.id}_dose_$i',
          );

          print('Scheduled notification for dose ${i + 1} at ${time.format(context)} with ID: $notificationId');
        } catch (notificationError) {
          print('Error scheduling notification for dose $i: $notificationError');
          // Continue with other doses even if one fails
        }
      }

      // Verify scheduled notifications
      final pendingNotifications = await NotificationService.getPendingNotifications();
      print('Total pending notifications after scheduling: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        print('Pending: ID ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medication saved and reminders scheduled!'),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate to Home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
        (route) => false,
      );
    } catch (e) {
      print('Error saving medication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving medication: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _medicationNameController.dispose();
    _doseAmountController.dispose();
    super.dispose();
  }

  Widget _buildMedicationTypeOption({
    required String imagePath,
    required String label,
    required String value,
  }) {
    final isSelected = _selectedMedicationType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMedicationType = value;
        });
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.black : Colors.grey[200],
                border: Border.all(
                  color:
                      isSelected ? Colors.black : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  imagePath,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.grey[600],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> updateReminderStatus({
    required String reminderId,
    required String status, // "Taken", "Skipped", "Snoozed"
    required DateTime time,
  }) async {
    await FirebaseFirestore.instance
        .collection('Reminders')
        .doc(reminderId)
        .update({
      'status': status,
      'actionTime': time,
    });
  }

  void showReminderAlarmScreen(BuildContext context, {
    required String reminderId,
    required String medicineName,
    required String instructions,
    required String time,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReminderAlarmScreen(
          medicineName: medicineName,
          instructions: instructions,
          time: time,
          onTaken: () async {
            await updateReminderStatus(reminderId: reminderId, status: 'Taken', time: DateTime.now());
            Navigator.pop(context);
          },
          onSkipped: () async {
            await updateReminderStatus(reminderId: reminderId, status: 'Skipped', time: DateTime.now());
            Navigator.pop(context);
          },
          onSnoozed: () async {
            await updateReminderStatus(reminderId: reminderId, status: 'Snoozed', time: DateTime.now());
            // Use the new full-screen alarm system for snooze
            await AlarmService.scheduleAlarm(
              scheduledTime: DateTime.now().add(Duration(minutes: 10)),
              medicineName: 'Snoozed: $medicineName',
              instructions: instructions,
              medicationId: '${reminderId}_snoozed',
            );
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  //display
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Medication',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medication Name',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            MedicationSearchWidget(
              controller: _medicationNameController,
              onMedicationSelected: (selectedMedication) {
                print('Selected medication: $selectedMedication');
              },
            ),
            const SizedBox(height: 16),

            const Text(
              'Dose',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _doseAmountController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Amount',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedDoseType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items:
                        ['Pills', 'Mg', 'Ml'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedDoseType = newValue!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Type',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildMedicationTypeOption(
                    imagePath: 'lib/images/syrup.png',
                    label: 'Liquid',
                    value: 'liquid',
                  ),
                  _buildMedicationTypeOption(
                    imagePath: 'lib/images/tablet.png',
                    label: 'Tablets',
                    value: 'tablets',
                  ),
                  _buildMedicationTypeOption(
                    imagePath: 'lib/images/medicine.png',
                    label: 'Capsules',
                    value: 'capsule',
                  ),
                  _buildMedicationTypeOption(
                    imagePath: 'lib/images/syringe.png',
                    label: 'Injection',
                    value: 'injection',
                  ),
                  _buildMedicationTypeOption(
                    imagePath: 'lib/images/drops.png',
                    label: 'Drops',
                    value: 'drops',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Intake Time',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedIntakeTime,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items:
                  ['Before Meals', 'After Meals', 'With Food'].map((
                    String value,
                  ) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedIntakeTime = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),

            const Text(
              'Doses and Times',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._doses.asMap().entries.map((entry) {
              final index = entry.key;
              final dose = entry.value;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Dose ${index + 1}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, index),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              '${dose['time'].format(context)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      if (index > 0)
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeDose(index),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }),
            ElevatedButton.icon(
              onPressed: _addDose,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add More Doses',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Start Date',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context, true),
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_startDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'End Date',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context, false),
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_endDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _saveMedication,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'Save Medication',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
