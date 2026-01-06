import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../service/caregiver_service.dart';
import 'package:intl/intl.dart';

class SymptomsPage extends StatefulWidget {
  const SymptomsPage({super.key});

  @override
  _SymptomsPageState createState() => _SymptomsPageState();
}

class _SymptomsPageState extends State<SymptomsPage> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  DateTime _selectedDateTime = DateTime.now();
  double _severityScale = 1.0;
  
  final List<Map<String, dynamic>> _allSymptoms = [
    {'name': 'Fever', 'icon': Icons.thermostat},
    {'name': 'Cough', 'icon': Icons.sick},
    {'name': 'Headache', 'icon': Icons.psychology},
    {'name': 'Nausea', 'icon': Icons.sentiment_very_dissatisfied},
    {'name': 'Fatigue', 'icon': Icons.battery_1_bar},
    {'name': 'Sore throat', 'icon': Icons.record_voice_over},
    {'name': 'Shortness of breath', 'icon': Icons.air},
    {'name': 'Chest pain', 'icon': Icons.favorite_border},
    {'name': 'Dizziness', 'icon': Icons.double_arrow},
    {'name': 'Runny nose', 'icon': Icons.coronavirus},
    {'name': 'Joint pain', 'icon': Icons.accessibility_new},
    {'name': 'Muscle ache', 'icon': Icons.fitness_center},
    {'name': 'Chills', 'icon': Icons.ac_unit},
    {'name': 'Sweating', 'icon': Icons.water_drop},
    {'name': 'Loss of appetite', 'icon': Icons.no_food},
    {'name': 'Vomiting', 'icon': Icons.sick_outlined},
    {'name': 'Diarrhea', 'icon': Icons.warning},
    {'name': 'Constipation', 'icon': Icons.block},
    {'name': 'Back pain', 'icon': Icons.accessibility},
    {'name': 'Insomnia', 'icon': Icons.bedtime_off},
    {'name': 'Anxiety', 'icon': Icons.psychology_alt},
    {'name': 'Depression', 'icon': Icons.sentiment_very_dissatisfied},
    {'name': 'Stomach pain', 'icon': Icons.local_hospital},
    {'name': 'Rash', 'icon': Icons.healing},
    {'name': 'Itching', 'icon': Icons.touch_app},
  ];
  
  List<Map<String, dynamic>> _filteredSymptoms = [];
  Map<String, dynamic>? _selectedSymptom;

  @override
  void initState() {
    super.initState();
    _filteredSymptoms = List.from(_allSymptoms);
  }

  void _filterSymptoms(String input) {
    setState(() {
      if (input.isEmpty) {
        _filteredSymptoms = List.from(_allSymptoms);
      } else {
        _filteredSymptoms = _allSymptoms
            .where((symptom) =>
                symptom['name'].toLowerCase().contains(input.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectSymptom(Map<String, dynamic> symptom) {
    setState(() {
      _selectedSymptom = symptom;
      _controller.clear();
      _filteredSymptoms = List.from(_allSymptoms);
    });
  }

  void _clearSelectedSymptom() {
    setState(() {
      _selectedSymptom = null;
      _filteredSymptoms = List.from(_allSymptoms);
    });
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
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

  String _getSeverityLabel(double value) {
    if (value <= 2) return 'Mild';
    if (value <= 4) return 'Light';
    if (value <= 6) return 'Moderate';
    if (value <= 8) return 'Severe';
    return 'Very Severe';
  }

  Color _getSeverityColor(double value) {
    if (value <= 2) return Colors.green;
    if (value <= 4) return Colors.lightGreen;
    if (value <= 6) return Colors.orange;
    if (value <= 8) return Colors.deepOrange;
    return Colors.red;
  }

  Future<void> _submitSymptom() async {
    final user = _auth.currentUser;
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    
    // Allow if user is authenticated OR if caregiver access has effective user ID
    if (effectiveUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save symptom'),
          backgroundColor: Color(0xFF0d6b5c),
        ),
      );
      return;
    }

    if (_selectedSymptom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a symptom'),
          backgroundColor: Color(0xFF0d6b5c),
        ),
      );
      return;
    }

    try {
      await _firestore.collection('Symptoms').add({
        'userId': effectiveUserId, // Use effective user ID (patient if in caregiver mode)
        'symptoms': [_selectedSymptom!['name']],
        'severityScale': _severityScale,
        'severityLabel': _getSeverityLabel(_severityScale),
        'timestamp': Timestamp.fromDate(_selectedDateTime),
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Symptom recorded successfully!'),
          backgroundColor: Color(0xFF0d6b5c),
        ),
      );

      // Reset form
      setState(() {
        _selectedSymptom = null;
        _severityScale = 1.0;
        _selectedDateTime = DateTime.now();
        _controller.clear();
        _filteredSymptoms = List.from(_allSymptoms);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving symptom: $e'),
          backgroundColor: Color(0xFF0d6b5c),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Symptoms Tracker',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF0d6b5c),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.white,
             body: SingleChildScrollView(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           children: [
             // Main Card for Symptom Recording
             Card(
               elevation: 4,
               child: Padding(
                 padding: const EdgeInsets.all(20.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Date and Time Section
                     const Text(
                       'Date and Time',
                       style: TextStyle(
                         fontSize: 18,
                         fontWeight: FontWeight.bold,
                         color: Color(0xFF0d6b5c),
                       ),
                     ),
                     const SizedBox(height: 12),
                     InkWell(
                       onTap: () => _selectDateTime(context),
                       child: InputDecorator(
                         decoration: const InputDecoration(
                           labelText: 'Date and Time',
                           border: OutlineInputBorder(),
                           prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF0d6b5c)),
                         ),
                         child: Text(
                           DateFormat('dd/MM/yyyy - HH:mm').format(_selectedDateTime),
                           style: const TextStyle(fontSize: 16),
                         ),
                       ),
                     ),
                     const SizedBox(height: 24),

                     // Symptom Selection Section
                     const Text(
                       'Select Symptom',
                       style: TextStyle(
                         fontSize: 18,
                         fontWeight: FontWeight.bold,
                         color: Color(0xFF0d6b5c),
                       ),
                     ),
                     const SizedBox(height: 12),
                     
                     // Search Field
                     TextField(
                       controller: _controller,
                       onChanged: _filterSymptoms,
                       decoration: InputDecoration(
                         labelText: 'Search symptom...',
                         border: const OutlineInputBorder(),
                         prefixIcon: const Icon(Icons.search, color: Color(0xFF0d6b5c)),
                         suffixIcon: _controller.text.isNotEmpty
                             ? IconButton(
                                 icon: const Icon(Icons.clear),
                                 onPressed: () {
                                   _controller.clear();
                                   _filterSymptoms('');
                                 },
                               )
                             : null,
                       ),
                     ),
                     const SizedBox(height: 12),
                     
                     // Symptoms List
                     Container(
                       height: 200,
                       decoration: BoxDecoration(
                         border: Border.all(color: Colors.grey[300]!),
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: _filteredSymptoms.isEmpty 
                         ? const Center(
                             child: Text(
                               'No symptoms found',
                               style: TextStyle(color: Colors.grey),
                             ),
                           )
                         : ListView.builder(
                             itemCount: _filteredSymptoms.length,
                             itemBuilder: (context, index) {
                               final symptom = _filteredSymptoms[index];
                               final isSelected = _selectedSymptom?['name'] == symptom['name'];
                               
                               return Container(
                                 color: isSelected ? const Color(0xFF0d6b5c).withOpacity(0.1) : null,
                                 child: ListTile(
                                   title: Text(
                                     symptom['name'],
                                     style: TextStyle(
                                       color: isSelected ? const Color(0xFF0d6b5c) : Colors.grey[700],
                                       fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                     ),
                                   ),
                                   trailing: Icon(
                                     isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                     color: isSelected ? const Color(0xFF0d6b5c) : Colors.grey[400],
                                   ),
                                   onTap: () => _selectSymptom(symptom),
                                 ),
                               );
                             },
                           ),
                     ),
                     const SizedBox(height: 16),
                     
                     // Selected Symptom Display
                     if (_selectedSymptom != null) ...[
                       const Text(
                         'Selected Symptom:',
                         style: TextStyle(
                           fontWeight: FontWeight.bold,
                           fontSize: 14,
                           color: Color(0xFF0d6b5c),
                         ),
                       ),
                       const SizedBox(height: 8),
                       Container(
                         width: double.infinity,
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(
                           border: Border.all(color: const Color(0xFF0d6b5c).withOpacity(0.3)),
                           borderRadius: BorderRadius.circular(8),
                           color: const Color(0xFF0d6b5c).withOpacity(0.05),
                         ),
                         child: Row(
                           children: [
                             Expanded(
                               child: Text(
                                 _selectedSymptom!['name'],
                                 style: const TextStyle(
                                   fontSize: 16,
                                   fontWeight: FontWeight.w600,
                                   color: Color(0xFF0d6b5c),
                                 ),
                               ),
                             ),
                             IconButton(
                               onPressed: _clearSelectedSymptom,
                               icon: const Icon(Icons.close, color: Color(0xFF0d6b5c)),
                               tooltip: 'Clear selection',
                             ),
                           ],
                         ),
                       ),
                       const SizedBox(height: 24),
                     ],

                     // Severity Scale Section
                     Row(
                       children: [
                         const Text(
                           'Severity Scale',
                           style: TextStyle(
                             fontSize: 18,
                             fontWeight: FontWeight.bold,
                             color: Color(0xFF0d6b5c),
                           ),
                         ),
                         if (_selectedSymptom != null) ...[
                           const SizedBox(width: 8),
                           Text(
                             'for ${_selectedSymptom!['name']}',
                             style: TextStyle(
                               fontSize: 14,
                               fontStyle: FontStyle.italic,
                               color: Colors.grey[600],
                             ),
                           ),
                         ],
                       ],
                     ),
                     const SizedBox(height: 16),
                     
                     // Severity Display
                     Row(
                       children: [
                         Container(
                           width: 60,
                           height: 60,
                           decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             color: _getSeverityColor(_severityScale).withOpacity(0.2),
                             border: Border.all(
                               color: _getSeverityColor(_severityScale),
                               width: 3,
                             ),
                           ),
                           child: Center(
                             child: Text(
                               '${_severityScale.round()}',
                               style: TextStyle(
                                 fontSize: 24,
                                 fontWeight: FontWeight.bold,
                                 color: _getSeverityColor(_severityScale),
                               ),
                             ),
                           ),
                         ),
                         const SizedBox(width: 16),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                 decoration: BoxDecoration(
                                   color: _getSeverityColor(_severityScale).withOpacity(0.2),
                                   borderRadius: BorderRadius.circular(16),
                                   border: Border.all(
                                     color: _getSeverityColor(_severityScale),
                                     width: 1,
                                   ),
                                 ),
                                 child: Text(
                                   _getSeverityLabel(_severityScale),
                                   style: TextStyle(
                                     color: _getSeverityColor(_severityScale),
                                     fontWeight: FontWeight.bold,
                                     fontSize: 16,
                                   ),
                                 ),
                               ),
                               const SizedBox(height: 4),
                               Text(
                                 'Rate the severity from 1 (mild) to 10 (very severe)',
                                 style: TextStyle(
                                   color: Colors.grey[600],
                                   fontSize: 12,
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 20),
                     
                     // Severity Slider
                     SliderTheme(
                       data: SliderTheme.of(context).copyWith(
                         activeTrackColor: _getSeverityColor(_severityScale),
                         thumbColor: _getSeverityColor(_severityScale),
                         overlayColor: _getSeverityColor(_severityScale).withOpacity(0.2),
                         valueIndicatorColor: _getSeverityColor(_severityScale),
                         trackHeight: 6,
                         thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                       ),
                       child: Slider(
                         value: _severityScale,
                         min: 1,
                         max: 10,
                         divisions: 9,
                         label: '${_severityScale.round()} - ${_getSeverityLabel(_severityScale)}',
                         onChanged: (value) {
                           setState(() {
                             _severityScale = value;
                           });
                         },
                       ),
                     ),
                     const Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text('1 - Mild', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                         Text('10 - Very Severe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                       ],
                     ),
                     const SizedBox(height: 24),

                     // Submit Button
                     SizedBox(
                       width: double.infinity,
                       child: ElevatedButton(
                         onPressed: _selectedSymptom != null ? _submitSymptom : null,
                         style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFF0d6b5c),
                           disabledBackgroundColor: Colors.grey[300],
                           minimumSize: const Size(double.infinity, 55),
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(8),
                           ),
                         ),
                         child: Text(
                           _selectedSymptom == null 
                             ? 'Select a symptom to continue'
                             : 'Record ${_selectedSymptom!['name']}',
                           style: TextStyle(
                             color: _selectedSymptom == null ? Colors.grey[600] : Colors.white,
                             fontSize: 16,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
             ),
             
             const SizedBox(height: 24),
             
                           // Symptoms History Section (Outside the card)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Symptoms History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
             const SizedBox(height: 8),
             StreamBuilder<QuerySnapshot>(
               stream: CaregiverService.getEffectiveUserId() != null
                   ? _firestore
                       .collection('Symptoms')
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
                             Icons.sick_outlined,
                             size: 64,
                             color: Colors.grey[400],
                           ),
                           const SizedBox(height: 16),
                           Text(
                             'No symptoms recorded yet',
                             style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                               fontWeight: FontWeight.w500,
                               color: Colors.grey[600],
                             ),
                           ),
                           const SizedBox(height: 8),
                           Text(
                             'Record your first symptom above',
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
                     final symptoms = (reading['symptoms'] as List<dynamic>).cast<String>();
                     final severity = (reading['severityScale'] as num).toDouble();
                     final severityColor = _getSeverityColor(severity);
                     final severityLabel = _getSeverityLabel(severity);
                     
                     return Card(
                       margin: const EdgeInsets.only(bottom: 8),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       child: Container(
                         decoration: BoxDecoration(
                           borderRadius: BorderRadius.circular(12),
                           border: Border.all(
                             color: severityColor.withOpacity(0.3),
                             width: 2,
                           ),
                         ),
                         child: Padding(
                           padding: const EdgeInsets.all(12),
                           child: Row(
                             children: [
                               // Main Content (without icon)
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Text(
                                       symptoms.join(', '),
                                       style: const TextStyle(
                                         fontWeight: FontWeight.bold,
                                         fontSize: 17,
                                       ),
                                       maxLines: 2,
                                       overflow: TextOverflow.ellipsis,
                                     ),
                                     const SizedBox(height: 2),
                                     Text(
                                       'Severity: ${severity.toStringAsFixed(1)}/10',
                                       style: const TextStyle(fontSize: 13),
                                       maxLines: 1,
                                       overflow: TextOverflow.ellipsis,
                                     ),
                                     const SizedBox(height: 2),
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
                                 width: 85,
                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: severityColor,
                                   borderRadius: BorderRadius.circular(16),
                                 ),
                                 child: Text(
                                   severityLabel,
                                   style: const TextStyle(
                                     color: Colors.white,
                                     fontWeight: FontWeight.bold,
                                     fontSize: 9,
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
           ],
         ),
       ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
} 
