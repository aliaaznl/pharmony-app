import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../service/caregiver_service.dart';

class TemperaturePage extends StatefulWidget {
  const TemperaturePage({super.key});

  @override
  State<TemperaturePage> createState() => _TemperaturePageState();
}

class _TemperaturePageState extends State<TemperaturePage> {
  final TextEditingController _tempController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime _selectedDateTime = DateTime.now();
  bool _reminderEnabled = false;
  String _selectedUnit = '°C';

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
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
    if (effectiveUserId == null) return;

    if (_tempController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter temperature value'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saving reading...'),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 1),
        ),
      );

      // Save to Firestore with proper timestamp handling
      final readingData = {
        'userId': effectiveUserId, // Always store under patient's ID
        'temperature': double.parse(_tempController.text),
        'unit': _selectedUnit,
        'timestamp': Timestamp.fromDate(_selectedDateTime),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add caregiver metadata if in caregiver mode
      if (CaregiverService.isInCaregiverMode && user != null) {
        readingData.addAll({
          'enteredBy': user.uid,
          'enteredByType': 'caregiver',
          'caregiverName': user.displayName ?? user.email ?? 'Unknown Caregiver',
        });
      }

      await _firestore.collection('Temperature').add(readingData);

      // Clear fields after successful save
      setState(() {
        _tempController.clear();
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Temperature reading saved successfully!'),
          backgroundColor: Colors.black,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving reading: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tempController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Temperature',
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
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => _selectDateTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date and Time',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy - HH:mm').format(_selectedDateTime),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tempController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Temperature',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: _selectedUnit,
                          items: ['°C', '°F'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedUnit = newValue!;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveReading,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        'Add Reading',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Reminders'),
              value: _reminderEnabled,
              onChanged: (bool value) {
                setState(() {
                  _reminderEnabled = value;
                });
              },
              activeColor: Colors.black,
            ),
            const SizedBox(height: 16),
            const Text(
              'History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: CaregiverService.getEffectiveUserId() != null
                  ? _firestore
                      .collection('Temperature')
                      .where('userId', isEqualTo: CaregiverService.getEffectiveUserId())
                      .orderBy('timestamp', descending: true)
                      .snapshots()
                  : Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading history'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final readings = snapshot.data?.docs ?? [];

                if (readings.isEmpty) {
                  return const Center(
                    child: Text('No readings recorded yet'),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: readings.length,
                  itemBuilder: (context, index) {
                    final reading = readings[index].data() as Map<String, dynamic>;
                    final timestamp = (reading['timestamp'] as Timestamp).toDate();
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          '${reading['temperature']}${reading['unit']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy - HH:mm').format(timestamp),
                        ),
                        trailing: Text(
                          _getTemperatureCategory(reading['temperature'], reading['unit']),
                          style: TextStyle(
                            color: _getTemperatureColor(reading['temperature'], reading['unit']),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getTemperatureCategory(double temp, String unit) {
    if (unit == '°C') {
      if (temp < 36.1) return 'Low';
      if (temp < 37.2) return 'Normal';
      if (temp < 38.3) return 'Elevated';
      return 'High';
    } else {
      if (temp < 97.0) return 'Low';
      if (temp < 99.0) return 'Normal';
      if (temp < 101.0) return 'Elevated';
      return 'High';
    }
  }

  Color _getTemperatureColor(double temp, String unit) {
    if (unit == '°C') {
      if (temp < 36.1) return Colors.blue;
      if (temp < 37.2) return Colors.green;
      if (temp < 38.3) return Colors.orange;
      return Colors.red;
    } else {
      if (temp < 97.0) return Colors.blue;
      if (temp < 99.0) return Colors.green;
      if (temp < 101.0) return Colors.orange;
      return Colors.red;
    }
  }
} 
