import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:phnew11/widgets/heart_rate_chart.dart';
import '../service/caregiver_service.dart';

class HeartRatePage extends StatefulWidget {
  const HeartRatePage({super.key});

  @override
  State<HeartRatePage> createState() => _HeartRatePageState();
}

class _HeartRatePageState extends State<HeartRatePage> {
  final TextEditingController _rateController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime _selectedDateTime = DateTime.now();
  bool _reminderEnabled = false;

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

    if (_rateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter heart rate value'),
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
        'rate': int.parse(_rateController.text),
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

      await _firestore.collection('HeartRate').add(readingData);

      // Clear fields after successful save
      setState(() {
        _rateController.clear();
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Heart rate reading saved successfully!'),
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
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Heart Rate',
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
            // Heart Rate Chart
            Card(
              elevation: 4,
              child: Container(
                height: 300,
                padding: const EdgeInsets.all(16.0),
                child: const HeartRateChart(timeCategory: 'day'),
              ),
            ),
            const SizedBox(height: 16),
            
            // Input Form
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
                    TextField(
                      controller: _rateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Heart Rate (BPM)',
                        border: OutlineInputBorder(),
                      ),
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
            
            // Reminder Switch
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
            
            // Recent Readings
            const SizedBox(height: 16),
            const Text(
              'Recent Readings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: CaregiverService.getEffectiveUserId() != null
                  ? _firestore
                      .collection('HeartRate')
                      .where('userId', isEqualTo: CaregiverService.getEffectiveUserId()!)
                      .orderBy('timestamp', descending: true)
                      .limit(5)
                      .snapshots()
                  : Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading history'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No readings yet'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = (data['timestamp'] as Timestamp).toDate();
                    final rate = data['rate'] as int;

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.favorite, color: Colors.black),
                        title: Text('$rate BPM'),
                        subtitle: Text(DateFormat('dd/MM/yyyy - HH:mm').format(timestamp)),
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

  String _getHeartRateCategory(int rate) {
    if (rate < 60) return 'Low';
    if (rate < 100) return 'Normal';
    if (rate < 120) return 'Elevated';
    return 'High';
  }

  Color _getHeartRateColor(int rate) {
    if (rate < 60) return Colors.blue;
    if (rate < 100) return Colors.green;
    if (rate < 120) return Colors.orange;
    return Colors.red;
  }
} 
