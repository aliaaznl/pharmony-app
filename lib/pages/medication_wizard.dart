import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../service/notification_service.dart';
import '../service/alarm_service.dart';
import '../service/caregiver_service.dart';
import '../home.dart';
import 'medication_search.dart';

class MedicationWizard extends StatefulWidget {
  final DateTime selectedDate;

  const MedicationWizard({super.key, required this.selectedDate});

  @override
  _MedicationWizardState createState() => _MedicationWizardState();
}

class _MedicationWizardState extends State<MedicationWizard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form Controllers
  final TextEditingController _medicationNameController = TextEditingController();
  final TextEditingController _doseAmountController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Form Data
  String _selectedDoseType = 'pill';
  String _selectedMedicationType = 'tablets';
  String _selectedIntakeTime = 'before meals';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  final List<Map<String, dynamic>> _doses = [
    <String, dynamic>{'dose': '', 'time': TimeOfDay.now()},
  ];

  // Days selection
  final List<bool> _selectedDays = [true, true, true, true, true, true, true]; // Mon-Sun

  @override
  void initState() {
    super.initState();
    _startDate = widget.selectedDate;
    NotificationService.setContext(context);
    AlarmService.setContext(context);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _medicationNameController.dispose();
    _doseAmountController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      _doses.add(<String, dynamic>{'dose': '', 'time': TimeOfDay.now()});
    });
  }

  void _removeDose(int index) {
    setState(() {
      _doses.removeAt(index);
    });
  }

  Widget _buildMedicationTypeOption({
    required String imagePath,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                color: isSelected ? colorScheme.primary : colorScheme.surface,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  imagePath,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.6),
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to icon if image fails to load
                    return Icon(
                      _getIconForMedicationType(value),
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.6),
                      size: 24,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
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

  Widget _buildDayButton(String day, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedDays[index];
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDays[index] = !_selectedDays[index];
        });
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            day,
            style: TextStyle(
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForMedicationType(String type) {
    switch (type.toLowerCase()) {
      case 'tablets':
        return Icons.medication;
      case 'capsules':
        return Icons.medication_outlined;
      case 'syrup':
      case 'liquid':
        return Icons.water_drop;
      case 'injection':
        return Icons.medical_services;
      case 'drops':
        return Icons.opacity;
      default:
        return Icons.medication;
    }
  }

  Future<void> _saveMedication() async {
    final user = _auth.currentUser;
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    
    // Allow if user is authenticated OR if caregiver access has effective user ID
    if (effectiveUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save medications'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
      final medicationData = {
        'userId': effectiveUserId, // Always store under patient's ID
        'medicationName': _medicationNameController.text.trim(),
        'doseAmount': _doseAmountController.text.trim(),
        'doseType': _selectedDoseType,
        'medicationType': _selectedMedicationType,
        'intakeTime': _selectedIntakeTime,
        'doses': _doses
            .map(
              (dose) => {
                'time': '${dose['time'].hour.toString().padLeft(2, '0')}:${dose['time'].minute.toString().padLeft(2, '0')}',
              },
            )
            .toList(),
        'selectedDays': _selectedDays,
        'startDate': DateFormat('dd/MM/yyyy').format(_startDate),
        'endDate': DateFormat('dd/MM/yyyy').format(_endDate),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add caregiver metadata if in caregiver mode
      if (CaregiverService.isInCaregiverMode && user != null) {
        medicationData.addAll({
          'createdBy': user.uid,
          'createdByType': 'caregiver',
          'caregiverName': user.displayName ?? user.email ?? 'Unknown Caregiver',
        });
      }

      final docRef = await _firestore.collection('Medications').add(medicationData);

      // Schedule notifications for each dose
      for (var i = 0; i < _doses.length; i++) {
        try {
          final dose = _doses[i];
          final time = dose['time'] as TimeOfDay;
          
          final now = DateTime.now();
          final scheduledTime = DateTime(
            now.year,
            now.month,
            now.day,
            time.hour,
            time.minute,
          );
          
          final finalScheduledTime = scheduledTime.isBefore(now) 
              ? scheduledTime.add(const Duration(days: 1))
              : scheduledTime;

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

          final notificationId = '${docRef.id}_$i'.hashCode.abs() % 2147483647;

          // Schedule alarm for the patient (works for both patient and caregiver modes)
          if (CaregiverService.isInCaregiverMode) {
            // When caregiver creates medication, send notification to patient's device
            await CaregiverService.sendNotificationToPatient(
              patientId: effectiveUserId,
              title: 'Medication Reminder',
              body: 'Time to take ${_medicationNameController.text.trim()}',
              data: {
                'type': 'medication_alarm',
                'medicationId': '${docRef.id}_dose_$i',
                'medicationName': _medicationNameController.text.trim(),
                'instructions': "Take ${_doseAmountController.text.trim()} $_selectedDoseType $_selectedIntakeTime",
                'time': time.format(context),
              },
            );
            print('✅ Notification scheduled for patient device: ${_medicationNameController.text.trim()}');
          } else {
            // Patient creating their own medication - use local alarm system
            await AlarmService.scheduleAlarm(
              scheduledTime: finalScheduledTime,
              medicineName: _medicationNameController.text.trim(),
              instructions: "Take ${_doseAmountController.text.trim()} $_selectedDoseType $_selectedIntakeTime",
              medicationId: '${docRef.id}_dose_$i',
            );
            print('✅ Local alarm scheduled for ${time.format(context)} - ${_medicationNameController.text.trim()}');
          }
        } catch (notificationError) {
          print('Error scheduling notification for dose $i: $notificationError');
        }
      }

      // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
          content: Text('✅ ${_medicationNameController.text.trim()} reminder has been set successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Add Medication',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          children: [
            // Page indicator
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPageIndicator(0, 'Medication'),
                  const SizedBox(width: 8),
                  _buildPageIndicator(1, 'Schedule'),
                ],
              ),
            ),
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildMedicationPage(),
                  _buildSchedulePage(),
                ],
              ),
            ),
            // Bottom navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int pageIndex, String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = _currentPage == pageIndex;
    final isCompleted = _currentPage > pageIndex;
    
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: isCompleted || isActive ? colorScheme.primary : colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationPage() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medication Name',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          MedicationSearchWidget(
            controller: _medicationNameController,
            onMedicationSelected: (selectedMedication) {
              print('Selected medication: $selectedMedication');
            },
          ),
          const SizedBox(height: 16),

          Text(
            'Dose',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _doseAmountController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    hintText: 'Amount',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedDoseType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                  ),
                  items: ['pill', 'mg', 'ml'].map((String value) {
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

          Text(
            'Type',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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

          Text(
            'Intake Time',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedIntakeTime,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.outline),
              ),
            ),
            items: ['before meals', 'after meals', 'with food'].map((String value) {
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
        ],
      ),
    );
  }

  Widget _buildSchedulePage() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Doses and Times',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context, index),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: colorScheme.outline),
                            ),
                          ),
                          child: Text(
                            dose['time'].format(context),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ),
                    if (index > 0)
                      IconButton(
                        icon: Icon(Icons.delete, color: colorScheme.error),
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
            icon: Icon(Icons.add, color: colorScheme.onPrimary),
            label: Text(
              'Add More Doses',
              style: TextStyle(color: colorScheme.onPrimary),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Days Taken',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDayButton('M', 0),
              _buildDayButton('T', 1),
              _buildDayButton('W', 2),
              _buildDayButton('T', 3),
              _buildDayButton('F', 4),
              _buildDayButton('S', 5),
              _buildDayButton('S', 6),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'Start Date',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _selectDate(context, true),
            child: InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
              ),
              child: Text(
                DateFormat('dd/MM/yyyy').format(_startDate),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'End Date',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _selectDate(context, false),
            child: InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
              ),
              child: Text(
                DateFormat('dd/MM/yyyy').format(_endDate),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        16.0,
        16.0,
        16.0,
        16.0 + (MediaQuery.of(context).padding.bottom > 0 ? 8.0 : 0.0),
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: ElevatedButton(
                onPressed: _previousPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: colorScheme.outline),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Previous'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentPage == 1 ? _saveMedication : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                _currentPage == 1 ? 'Add Medication' : 'Next',
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
