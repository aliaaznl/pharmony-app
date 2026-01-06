import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'medication_wizard.dart';
import 'edit_medication_wizard.dart';
import '../service/alarm_service.dart';
import '../service/system_alarm_service.dart';
import '../service/caregiver_service.dart';
import 'metrics.dart';
import 'charts_page.dart';
import 'symptoms.dart';
import 'settings.dart' as app_settings;
import 'appointments.dart';

import 'profile.dart';
import '../login.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  DateTime _currentDate = DateTime.now();
  final PageController _pageController = PageController(initialPage: 1000);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final TextEditingController _medicationNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  
  bool _isRightSidebarOpen = false;
  String? _patientName;

  @override
  void initState() {
    super.initState();
    // Ensure current date is set to today
    setState(() {
      _currentDate = DateTime.now();
    });
    // Set context for alarm services
    AlarmService.setContext(context);
    SystemAlarmService.setContext(context);
    // Register device token for caregiver notifications
    CaregiverService.registerDeviceToken();
    _loadPatientName();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload patient name when dependencies change (like caregiver mode)
    _loadPatientName();
  }

  Future<void> _loadPatientName() async {
    if (CaregiverService.isInCaregiverMode && CaregiverService.currentPatientId != null) {
      try {
        final patientDoc = await _firestore
            .collection('Users')
            .doc(CaregiverService.currentPatientId)
            .get();
        
        if (patientDoc.exists) {
          final patientData = patientDoc.data();
          setState(() {
            _patientName = patientData?['name'] ?? patientData?['displayName'] ?? 'Patient';
          });
        }
      } catch (e) {
        print('Error loading patient name: $e');
      }
    }
  }

  Future<void> _logout() async {
    try {
      // Reset caregiver mode first to prevent stream permission errors
      CaregiverService.resetCaregiverMode();
      print('✅ Caregiver mode reset');
      
      // Sign out from Firebase Auth
      await _auth.signOut();
      
      // Also sign out from Google Sign-In to ensure account chooser appears next time
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      
      print('✅ Successfully signed out from both Firebase and Google');
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LogIn()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('❌ Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToPage(Widget page) {
    setState(() {
      _isRightSidebarOpen = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  List<DateTime> getWeekDays(DateTime date) {
    date ??= DateTime.now();
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  List<List<DateTime>> getMonthWeeks(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final lastDayOfMonth = DateTime(date.year, date.month + 1, 0);
    
    // Find the first Monday of the month view (might be from previous month)
    final startOfFirstWeek = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday - 1));
    
    // Find the last Sunday of the month view (might be from next month)
    final endOfLastWeek = lastDayOfMonth.add(Duration(days: 7 - lastDayOfMonth.weekday));
    
    List<List<DateTime>> weeks = [];
    DateTime currentWeekStart = startOfFirstWeek;
    
    while (currentWeekStart.isBefore(endOfLastWeek) || currentWeekStart.isAtSameMomentAs(endOfLastWeek)) {
      List<DateTime> week = List.generate(7, (index) => currentWeekStart.add(Duration(days: index)));
      weeks.add(week);
      currentWeekStart = currentWeekStart.add(Duration(days: 7));
    }
    
    return weeks;
  }

  void _onPageChanged(int index) {
    setState(() {
      final weeksFromStart = index - 1000;
      final today = DateTime.now();
      final startOfCurrentWeek = today.subtract(Duration(days: today.weekday - 1));
      final targetWeekStart = startOfCurrentWeek.add(Duration(days: weeksFromStart * 7));
      
      // Set current date to the same day of week in the target week
      final dayOfWeek = _currentDate.weekday;
      _currentDate = targetWeekStart.add(Duration(days: dayOfWeek - 1));
    });
  }

  Future<void> _saveMedication(DateTime date) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final effectiveUserId = CaregiverService.getEffectiveUserId();
      if (effectiveUserId == null) return;

      final medicationData = {
        'userId': effectiveUserId, // Use effective user ID (patient if in caregiver mode)
        'medicationName': _medicationNameController.text,
        'dosage': _dosageController.text,
        'time': _timeController.text,
        'date': DateFormat('dd/MM/yyyy').format(date),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add caregiver metadata if in caregiver mode
      if (CaregiverService.isInCaregiverMode) {
        medicationData['createdBy'] = user.uid;
        medicationData['createdByType'] = 'caregiver';
        medicationData['caregiverName'] = user.displayName ?? user.email ?? 'Unknown Caregiver';
      }

      await _firestore.collection('Medications').add(medicationData);
      
      // Clear controllers after successful save
      _medicationNameController.clear();
      _dosageController.clear();
      _timeController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Medication saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving medication: $e')),
      );
    }
  }

  void _showAddMedicationDialog(DateTime date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Medication for ${DateFormat('dd/MM/yyyy').format(date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _medicationNameController,
              decoration: InputDecoration(labelText: 'Medication Name'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _dosageController,
              decoration: InputDecoration(labelText: 'Dosage'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _timeController,
              decoration: InputDecoration(labelText: 'Time'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _medicationNameController.clear();
              _dosageController.clear();
              _timeController.clear();
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _saveMedication(date);
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMedicationDetails(Map<String, dynamic> medication, String docId) async {
    final doses = medication['doses'] as List<dynamic>? ?? [];
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // Sharp square edges with slight corners
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Custom title bar with X close button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    _getMedicationIcon(medication['medicationType'] ?? 'tablets'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        medication['medicationName'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Dose: ${medication['doseAmount']} ${medication['doseType']}',
                          textAlign: TextAlign.left,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Type: ${medication['medicationType']}',
                          textAlign: TextAlign.left,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Intake Time: ${medication['intakeTime']}',
                          textAlign: TextAlign.left,
                        ),
                      ),
                      if (doses.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: const Text(
                            'Scheduled Times:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        ...doses.map((dose) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '• ${dose['time']}',
                            textAlign: TextAlign.left,
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
              // Delete and Edit buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Delete button (left)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showDeleteConfirmation(context, docId, medication['medicationName'] ?? ''),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 224, 224, 224),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12), // Space between buttons
                    // Edit button (right)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          try {
                            Navigator.pop(context);
                            _navigateToEditMedication(medication, docId);
                          } catch (e) {
                            print('Error in edit button: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error opening edit page: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D1B2A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToEditMedication(Map<String, dynamic> medication, String docId) {
    try {
      // Validate the medication data before navigation
      if (medication.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid medication data'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditMedicationWizard(
            selectedDate: _currentDate,
            existingMedication: medication,
            medicationId: docId,
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to edit medication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening edit page: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context, String docId, String medicationName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Medication',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete "$medicationName"? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close confirmation dialog
                        Navigator.pop(context); // Close medication details dialog
                        _deleteMedication(docId, medicationName);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteMedication(String docId, String medicationName) async {
    try {
      // Delete the medication document from Firestore
      await _firestore.collection('Medications').doc(docId).delete();
      
      // Optionally, delete related medication status records
      final statusQuery = await _firestore
          .collection('MedicationStatus')
          .where('medicationId', isGreaterThanOrEqualTo: docId)
          .where('medicationId', isLessThan: '$docId\uf8ff')
          .get();
      
      // Delete all related status records
      for (final doc in statusQuery.docs) {
        await doc.reference.delete();
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$medicationName has been deleted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error deleting medication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting medication: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _getMedicationIcon(String medicationType) {
    String imagePath;
    switch (medicationType.toLowerCase()) {
      case 'tablets':
        imagePath = 'lib/images/tablet.png';
        break;
      case 'liquid':
        imagePath = 'lib/images/syrup.png';
        break;
      case 'capsule':
        imagePath = 'lib/images/medicine.png';
        break;
      case 'injection':
        imagePath = 'lib/images/syringe.png';
        break;
      case 'drops':
        imagePath = 'lib/images/drops.png';
        break;
      default:
        imagePath = 'lib/images/tablet.png'; // Default to tablet
        break;
    }
    
    return SizedBox(
      width: 24,
      height: 24,
      child: Image.asset(
        imagePath,
        width: 24,
        height: 24,
        color: Colors.black,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to Flutter icon if image fails to load
          return const Icon(Icons.medication, color: Colors.black, size: 24);
        },
      ),
    );
  }

  bool _shouldShowMedicationForDate(Map<String, dynamic> medication, DateTime selectedDate) {
    try {
      // Parse start and end dates
      final startDateStr = medication['startDate'] as String?;
      final endDateStr = medication['endDate'] as String?;
      
      if (startDateStr == null || endDateStr == null) {
        print('Medication ${medication['medicationName']} missing start/end date');
        return true; // Show medication if dates are missing (backwards compatibility)
      }
      
      DateTime startDate;
      DateTime endDate;
      
      // Try to parse different date formats
      try {
        // Try dd/MM/yyyy format first (new format)
        startDate = DateFormat('dd/MM/yyyy').parse(startDateStr);
        endDate = DateFormat('dd/MM/yyyy').parse(endDateStr);
      } catch (e) {
        try {
          // Try yyyy-MM-dd format (old format)
          startDate = DateFormat('yyyy-MM-dd').parse(startDateStr);
          endDate = DateFormat('yyyy-MM-dd').parse(endDateStr);
        } catch (e2) {
          // If both fail, try parsing as DateTime directly
          startDate = DateTime.parse(startDateStr);
          endDate = DateTime.parse(endDateStr);
        }
      }
      
      // Check if selected date is within the medication's date range (using only date, not time)
      final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
      final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
      
      if (selectedDateOnly.isBefore(startDateOnly) || selectedDateOnly.isAfter(endDateOnly)) {
        return false;
      }
      
      // Check selected days (Monday = 0, Sunday = 6)
      final selectedDays = medication['selectedDays'] as List<dynamic>?;
      
      if (selectedDays != null && selectedDays.length == 7) {
        // Convert DateTime weekday (Monday = 1, Sunday = 7) to our format (Monday = 0, Sunday = 6)
        final dayIndex = selectedDate.weekday - 1;
        final isSelectedDay = selectedDays[dayIndex] == true;
        return isSelectedDay;
      }
      
      // If no selectedDays field, assume daily (backwards compatibility)
      return true;
    } catch (e) {
      print('Error parsing medication dates for ${medication['medicationName']}: $e');
      return true; // Show medication if there's an error parsing dates
    }
  }

  Widget _buildMedicationCard(Map<String, dynamic> medication, String docId) {
    final doses = medication['doses'] as List<dynamic>? ?? [];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: doses.asMap().entries.map<Widget>((entry) {
          final doseIndex = entry.key;
          final dose = entry.value;
          final time = dose['time'] as String? ?? '';
          final medicationId = '${docId}_dose_$doseIndex';
          
          // Parse dose time
          TimeOfDay? doseTime;
          try {
            final doseParts = time.split(':');
            if (doseParts.length == 2) {
              doseTime = TimeOfDay(
                hour: int.parse(doseParts[0]),
                minute: int.parse(doseParts[1]),
              );
            }
          } catch (e) {
            print('Error parsing dose time: $e');
          }
          
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('MedicationStatus')
                .where('medicationId', isEqualTo: medicationId)
                .where('timestamp', isGreaterThan: Timestamp.fromDate(
                  DateTime(_currentDate.year, _currentDate.month, _currentDate.day)))
                .where('timestamp', isLessThan: Timestamp.fromDate(
                  DateTime(_currentDate.year, _currentDate.month, _currentDate.day + 1)))
                .orderBy('timestamp', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, statusSnapshot) {
              // Determine status and colors
              String statusText = '';
              Color statusBgColor = Colors.grey[100]!;
              Color statusTextColor = Colors.grey[800]!;
              
              if (statusSnapshot.hasData && statusSnapshot.data!.docs.isNotEmpty) {
                // Use actual status from database
                final statusDoc = statusSnapshot.data!.docs.first;
                final status = statusDoc['status'] as String;
                
                switch (status.toLowerCase()) {
                  case 'taken':
                    statusText = 'Taken';
                    statusBgColor = Colors.green[100]!;
                    statusTextColor = Colors.green[800]!;
                    break;
                  case 'skipped':
                    statusText = 'Skipped';
                    statusBgColor = Colors.yellow[100]!;
                    statusTextColor = Colors.yellow[800]!;
                    break;
                  case 'snoozed':
                    statusText = 'Snoozed';
                    statusBgColor = Colors.yellow[100]!;
                    statusTextColor = Colors.yellow[800]!;
                    break;
                  default:
                    statusText = time;
                    statusBgColor = Colors.grey[100]!;
                    statusTextColor = Colors.grey[800]!;
                }
              } else {
                // No status found, determine based on time
                if (doseTime != null) {
                  final now = TimeOfDay.now();
                  final currentMinutes = now.hour * 60 + now.minute;
                  final doseMinutes = doseTime.hour * 60 + doseTime.minute;
                  
                  // Check if it's the selected date and past the dose time
                  final today = DateTime.now();
                  final isToday = _currentDate.year == today.year && 
                                  _currentDate.month == today.month && 
                                  _currentDate.day == today.day;
                  final isPastDate = _currentDate.isBefore(today);
                  final isFutureDate = _currentDate.isAfter(today);
                  
                  // Debug prints for missed status calculation
                  print('🔍 Missed Status Debug:');
                  print('  - Medication: ${medication['medicationName']}');
                  print('  - Dose time: $doseTime');
                  print('  - Current time: $now');
                  print('  - Current minutes: $currentMinutes');
                  print('  - Dose minutes: $doseMinutes');
                  print('  - Selected date: $_currentDate');
                  print('  - Is today: $isToday');
                  print('  - Is past date: $isPastDate');
                  print('  - Is future date: $isFutureDate');
                  print('  - Time difference: ${currentMinutes - doseMinutes} minutes');
                  
                  // Determine if medication should be marked as missed
                  bool shouldBeMissed = false;
                  
                  if (isToday) {
                    // For today: check if current time is more than 30 minutes past dose time
                    shouldBeMissed = currentMinutes > doseMinutes + 30;
                    print('  - Today logic: should be missed = $shouldBeMissed');
                  } else if (isPastDate) {
                    // For past dates: always mark as missed if no status recorded
                    shouldBeMissed = true;
                    print('  - Past date logic: should be missed = $shouldBeMissed');
                  } else if (isFutureDate) {
                    // For future dates: never mark as missed
                    shouldBeMissed = false;
                    print('  - Future date logic: should be missed = $shouldBeMissed');
                  }
                  
                  if (shouldBeMissed) {
                    statusText = 'Missed';
                    statusBgColor = Colors.red[100]!;
                    statusTextColor = Colors.red[800]!;
                    print('✅ Marked as MISSED');
                  } else {
                    // Not missed - show as scheduled or taken
                    if (isFutureDate) {
                      statusText = time;
                      statusBgColor = Colors.grey[50]!;
                      statusTextColor = Colors.grey[800]!;
                      print('⏰ Marked as SCHEDULED (future)');
                    } else if (isToday) {
                      statusText = time;
                      statusBgColor = Colors.grey[50]!;
                      statusTextColor = Colors.grey[800]!;
                      print('⏰ Marked as SCHEDULED (today)');
                    } else {
                      // For past dates with no status, show as scheduled
                      statusText = time;
                      statusBgColor = Colors.grey[50]!;
                      statusTextColor = Colors.grey[800]!;
                      print('⏰ Marked as SCHEDULED (past)');
                    }
                  }
                } else {
                  statusText = time;
                  statusBgColor = Colors.grey[50]!;
                  statusTextColor = Colors.grey[800]!;
                  print('❌ No dose time available');
                }
              }
              
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100], // Keep card background grey as requested
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _getMedicationIcon(medication['medicationType'] ?? 'tablets'),
                  ),
                  title: Text(
                    medication['medicationName'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${medication['doseAmount']} ${medication['doseType']}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                                     trailing: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     constraints: const BoxConstraints(maxWidth: 80),
                     decoration: BoxDecoration(
                       color: statusBgColor,
                       borderRadius: BorderRadius.circular(16),
                       border: statusBgColor == Colors.grey[50] 
                           ? Border.all(color: Colors.grey[300]!, width: 1)
                           : null,
                     ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: statusTextColor,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onTap: () => _showMedicationDetails(medication, docId),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _medicationNameController.dispose();
    _dosageController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = getWeekDays(_currentDate);
    final currentDateStr = DateFormat('dd/MM/yyyy').format(_currentDate);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfileAvatar(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              CaregiverService.isInCaregiverMode ? 'Managing Patient' : 'Hello!',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: CaregiverService.isInCaregiverMode ? Colors.green[800] : Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(height: 0.05),
                          Text(
                            CaregiverService.isInCaregiverMode 
                                ? (CaregiverService.currentPatientData?['patientName'] ?? _patientName ?? 'Patient')
                                : _auth.currentUser?.displayName ?? 'User',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (CaregiverService.isInCaregiverMode)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Caregiver Mode',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Right sidebar menu button
                    IconButton(
                      onPressed: () {
                        print('🔧 Toggle sidebar. Current state: $_isRightSidebarOpen');
                        print('📝 User name: ${_auth.currentUser?.displayName ?? 'User'}');
                        print('📧 User email: ${_auth.currentUser?.email ?? 'No email'}');
                        setState(() {
                          _isRightSidebarOpen = !_isRightSidebarOpen;
                        });
                      },
                      icon: AnimatedRotation(
                        turns: _isRightSidebarOpen ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: const Icon(
                          Icons.menu,
                          color: Color(0xFF0d6b5c),
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Reduced vertical padding from 16 to 8
            child: Column(
              children: [
                // Month navigation header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, _currentDate.day);
                        });
                      },
                      icon: Icon(Icons.chevron_left, color: const Color(0xFF0d6b5c)),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_currentDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, _currentDate.day);
                        });
                      },
                      icon: Icon(Icons.chevron_right, color: const Color(0xFF0d6b5c)),
                    ),
                  ],
                ),
                const SizedBox(height: 8), // Reduced gap from 16 to 8
                // Horizontal scrollable calendar container
                Container(
                  height: 120, // Reduced height from 140 to 120
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Day labels row
                      Padding(
                        padding: const EdgeInsets.all(8.0), // Reduced padding from 12 to 8
                        child: Row(
                          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                              .map((dayLabel) => Expanded(
                                    child: Center(
                                      child: Text(
                                        dayLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      // Horizontal scrollable weeks
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              final weeksFromToday = index - 1000;
                              final today = DateTime.now();
                              final startOfTodaysWeek = today.subtract(Duration(days: today.weekday - 1));
                              final targetWeekStart = startOfTodaysWeek.add(Duration(days: weeksFromToday * 7));
                              final weekDays = getWeekDays(targetWeekStart);
                              
                              // Set current date to the same day of week in the target week
                              final dayOfWeek = _currentDate.weekday;
                              _currentDate = targetWeekStart.add(Duration(days: dayOfWeek - 1));
                            });
                          },
                          itemBuilder: (context, index) {
                            final weeksFromToday = index - 1000;
                            final today = DateTime.now();
                            final startOfTodaysWeek = today.subtract(Duration(days: today.weekday - 1));
                            final targetWeekStart = startOfTodaysWeek.add(Duration(days: weeksFromToday * 7));
                            final weekDays = getWeekDays(targetWeekStart);
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Reduced padding
                              child: Row(
                                children: weekDays.map((date) {
                                  final isSelected = date.day == _currentDate.day && 
                                                  date.month == _currentDate.month && 
                                                  date.year == _currentDate.year;
                                  final isToday = date.day == DateTime.now().day && 
                                                date.month == DateTime.now().month && 
                                                date.year == DateTime.now().year;
                                  final isCurrentMonth = date.month == _currentDate.month;
                                  
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _currentDate = date;
                                        });
                                      },
                                      child: Container(
                                        height: 50, // Reduced height from 60 to 50
                                        margin: EdgeInsets.symmetric(horizontal: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected 
                                            ? const Color(0xFF0d6b5c)
                                            : isToday
                                              ? const Color(0xFF0d6b5c).withOpacity(0.1)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: isToday && !isSelected
                                            ? Border.all(color: const Color(0xFF0d6b5c), width: 2)
                                            : Border.all(color: Colors.grey[300]!, width: 1),
                                          boxShadow: isSelected ? [
                                            BoxShadow(
                                              color: const Color(0xFF0d6b5c).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ] : [],
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              date.day.toString(),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected 
                                                  ? Colors.white 
                                                  : isToday 
                                                    ? const Color(0xFF0d6b5c)
                                                    : isCurrentMonth
                                                      ? const Color(0xFF0d6b5c).withOpacity(0.87)
                                                      : Colors.grey[400],
                                              ),
                                            ),
                                            if (isToday && !isSelected)
                                              Container(
                                                width: 4,
                                                height: 4,
                                                margin: EdgeInsets.only(top: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0d6b5c),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8), // Reduced gap from 16 to 8
                const SizedBox(height: 4), // Reduced additional gap from 8 to 4
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, dd MMMM yyyy').format(_currentDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MedicationWizard(selectedDate: _currentDate),
                          ),
                        );
                      },
                      backgroundColor: const Color(0xFF0d6b5c),
                      shape: const CircleBorder(),
                      mini: true,
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: CaregiverService.getEffectiveUserId() != null
                  ? _firestore
                      .collection('Medications')
                      .where('userId', isEqualTo: CaregiverService.getEffectiveUserId())
                      .orderBy('createdAt', descending: false)
                      .snapshots()
                  : Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    color: Colors.white,
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    color: Colors.white,
                    child: Center(child: CircularProgressIndicator(color: const Color(0xFF0d6b5c))),
                  );
                }

                final allMedications = snapshot.data?.docs ?? [];
                
                // Filter medications for the selected date
                final filteredMedications = allMedications.where((doc) {
                  final medication = doc.data() as Map<String, dynamic>;
                  return _shouldShowMedicationForDate(medication, _currentDate);
                }).toList();

                if (filteredMedications.isEmpty) {
                  return Container(
                    color: Colors.white,
                    height: double.infinity,
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, -40), // Move up by 40 pixels
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No medications scheduled',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'for ${DateFormat('EEEE, dd MMMM').format(_currentDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Container(
                  color: Colors.white,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredMedications.length,
                    itemBuilder: (context, index) {
                      final medication = filteredMedications[index].data() as Map<String, dynamic>;
                      return _buildMedicationCard(medication, filteredMedications[index].id);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
          // Overlay when sidebar is open
          if (_isRightSidebarOpen)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isRightSidebarOpen = false;
                });
              },
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isRightSidebarOpen ? 0.5 : 0.0,
                child: Container(
                  color: Colors.black,
                ),
              ),
            ),
          // Right Sidebar
          if (_isRightSidebarOpen) _buildRightSidebar(),
        ],
      ),

    );
  }

  Widget _buildRightSidebar() {
    print('🏗️ Building right sidebar. Open: $_isRightSidebarOpen');
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      right: _isRightSidebarOpen ? 0 : -320,
      top: 0,
      bottom: 0,
      width: 320,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header section with profile
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0d6b5c),
                      const Color(0xFF0d6b5c).withOpacity(0.8),
                    ],
                  ),
              ),
              child: Column(
                children: [
                  _buildProfileAvatar(),
                  const SizedBox(height: 16),
                  // User name with proper text wrapping
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      CaregiverService.isInCaregiverMode 
                          ? (CaregiverService.currentPatientData?['patientName'] ?? _patientName ?? 'Patient')
                          : _auth.currentUser?.displayName ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Email with proper text wrapping
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      CaregiverService.isInCaregiverMode 
                          ? (CaregiverService.currentPatientData?['patientEmail'] ?? 'Patient Email')
                          : _auth.currentUser?.email ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildNavItem(
                    icon: Icons.medication,
                    title: 'Add Medications',
                    onTap: () => _navigateToPage(MedicationWizard(selectedDate: _currentDate)),
                  ),
                  _buildNavItem(
                    icon: Icons.calendar_today,
                    title: 'Appointments',
                    onTap: () => _navigateToPage(const AppointmentsPage()),
                  ),
                  _buildNavItem(
                    icon: Icons.monitor_heart,
                    title: 'Blood Pressure Monitoring',
                    onTap: () => _navigateToPage(const Metrics()),
                  ),
                  _buildNavItem(
                    icon: Icons.analytics,
                    title: 'Charts & Analytics',
                    onTap: () => _navigateToPage(const ChartsPage()),
                  ),
                  _buildNavItem(
                    icon: Icons.person,
                    title: 'Profile',
                    onTap: () => _navigateToPage(const ProfilePage()),
                  ),
                  _buildNavItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () => _navigateToPage(const app_settings.Settings()),
                  ),
                  _buildNavItem(
                    icon: Icons.thermostat,
                    title: 'Symptoms Tracking',
                    onTap: () => _navigateToPage(const SymptomsPage()),
                  ),
                ],
              ),
            ),
            // Logout button
            Container(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _logout();
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive 
                ? const Color(0xFF0d6b5c).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isActive 
                ? const Color(0xFF0d6b5c)
                : Colors.grey[600],
            size: 22,
          ),
        ),
                         title: Text(
          title,
          style: TextStyle(
            color: isActive 
                ? const Color(0xFF0d6b5c)
                : Colors.grey[800],
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[400],
          size: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: isActive 
            ? const Color(0xFF0d6b5c).withOpacity(0.05)
            : Colors.transparent,
        onTap: onTap,
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final user = _auth.currentUser;
    
    // In caregiver mode, fetch and show patient's profile picture
    if (CaregiverService.isInCaregiverMode) {
      final effectiveUserId = CaregiverService.getEffectiveUserId();
      if (effectiveUserId != null) {
        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('Users').doc(effectiveUserId).get(),
          builder: (context, snapshot) {
                         if (snapshot.hasData && snapshot.data!.exists) {
               final data = snapshot.data!.data() as Map<String, dynamic>?;
               final photoURL = data?['photoURL'] ?? data?['imgUrl'] ?? data?['googlePhotoURL'];
              
              if (photoURL != null) {
                // Show patient's Google profile picture
                return CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(photoURL),
                );
              }
            }
            
            // Fallback to medical services icon if no profile picture
            return const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.orange,
              child: Icon(Icons.medical_services, color: Colors.white, size: 32),
            );
          },
        );
      }
      
      // Fallback if no effective user ID
      return const CircleAvatar(
        radius: 28,
        backgroundColor: Colors.orange,
        child: Icon(Icons.medical_services, color: Colors.white, size: 32),
      );
    }
    
    if (user != null && user.photoURL != null) {
      // Google sign-in: show profile picture
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(user.photoURL!),
      );
    } else {
      // Email sign-in: show user icon
      return const CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFF0d6b5c),
        child: Icon(Icons.person, color: Colors.white, size: 32),
      );
    }
  }
}
