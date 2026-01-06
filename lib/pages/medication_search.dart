import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../service/caregiver_service.dart';

class MedicationSearchWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String)? onMedicationSelected;

  const MedicationSearchWidget({
    super.key,
    required this.controller,
    this.onMedicationSelected,
  });

  @override
  _MedicationSearchWidgetState createState() => _MedicationSearchWidgetState();
}

class _MedicationSearchWidgetState extends State<MedicationSearchWidget> {
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() {
          _showSuggestions = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String _simplifyMedicationName(String complexName) {
    // Remove common technical terms and dosage information
    String simplified = complexName;
    
    // Extract brand name from brackets [Brand Name]
    final brandMatch = RegExp(r'\[([^\]]+)\]').firstMatch(simplified);
    if (brandMatch != null) {
      return brandMatch.group(1)!;
    }
    
    // Remove dosage information (e.g., "500 MG", "10 ML", etc.)
    simplified = simplified.replaceAll(RegExp(r'\b\d+(\.\d+)?\s*(MG|ML|MCG|G|%)\b', caseSensitive: false), '');
    
    // Remove route of administration
    simplified = simplified.replaceAll(RegExp(r'\b(Oral|Injectable|Topical|Intravenous|Sublingual)\b', caseSensitive: false), '');
    
    // Remove dosage forms
    simplified = simplified.replaceAll(RegExp(r'\b(Tablet|Capsule|Solution|Suspension|Cream|Ointment|Gel|Patch|Injection)\b', caseSensitive: false), '');
    
    // Remove extra spaces and trim
    simplified = simplified.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // If simplified name is too short or empty, return first word of original
    if (simplified.length < 3) {
      simplified = complexName.split(' ').first;
    }
    
    return simplified;
  }

  Future<void> _fetchMedicationSuggestions(String input) async {
    if (input.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });

    try {
      final url = Uri.parse(
        'https://rxnav.nlm.nih.gov/REST/drugs.json?name=$input',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List<Map<String, dynamic>> results = [];

        if (jsonData['drugGroup'] != null &&
            jsonData['drugGroup']['conceptGroup'] != null) {
          for (var group in jsonData['drugGroup']['conceptGroup']) {
            if (group['conceptProperties'] != null) {
              for (var item in group['conceptProperties']) {
                final originalName = item['name'];
                final simplifiedName = _simplifyMedicationName(originalName);
                
                results.add({
                  'name': originalName,
                  'simplifiedName': simplifiedName,
                  'rxcui': item['rxcui'],
                  'synonym': item['synonym'] ?? '',
                });
              }
            }
          }
        }

        // Sort by simplified name length (shorter = simpler)
        results.sort((a, b) => a['simplifiedName'].length.compareTo(b['simplifiedName'].length));

        final uniqueResults = <String, Map<String, dynamic>>{};
        for (var result in results) {
          // Use simplified name as key to avoid duplicates
          uniqueResults[result['simplifiedName']] = result;
        }

        setState(() {
          _suggestions = uniqueResults.values.take(10).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
    }
  }

  void _onSuggestionTap(Map<String, dynamic> medication) {
    // Use simplified name for the text field
    widget.controller.text = medication['simplifiedName'];
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
    
    if (widget.onMedicationSelected != null) {
      widget.onMedicationSelected!(medication['simplifiedName']);
    }
    
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: _fetchMedicationSuggestions,
          onTap: () {
            if (widget.controller.text.isNotEmpty && _suggestions.isNotEmpty) {
              setState(() {
                _showSuggestions = true;
              });
            }
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            hintText: 'Search medication name...',
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            suffixIcon: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() {
                        _suggestions = [];
                        _showSuggestions = false;
                      });
                    },
                  )
                : const Icon(Icons.search),
          ),
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
              color: colorScheme.surface,
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final medication = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.medication,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  title: Text(
                    medication['simplifiedName'],
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication['name'],
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      if (medication['synonym'].isNotEmpty)
                        Text(
                          'Also known as: ${medication['synonym']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                    ],
                  ),
                  onTap: () => _onSuggestionTap(medication),
                );
              },
            ),
          ),
      ],
    );
  }
}

class MedicationApiSearchPage extends StatefulWidget {
  final DateTime? selectedDate;

  const MedicationApiSearchPage({super.key, this.selectedDate});

  @override
  _MedicationApiSearchPageState createState() => _MedicationApiSearchPageState();
}

class _MedicationApiSearchPageState extends State<MedicationApiSearchPage> {
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _doseAmountController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedDoseType = 'pill';
  String _selectedMedicationType = 'tablets';
  String _selectedIntakeTime = 'before meals';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  final List<Map<String, dynamic>> _doses = [
    {'dose': '', 'time': TimeOfDay.now()},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.selectedDate != null) {
      _startDate = widget.selectedDate!;
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
    if (effectiveUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save medications'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_medicationController.text.trim().isEmpty) {
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
      await _firestore.collection('Medications').add({
        'userId': effectiveUserId, // Use effective user ID (patient if in caregiver mode)
        'medicationName': _medicationController.text.trim(),
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
        'startDate': DateFormat('dd/MM/yyyy').format(_startDate),
        'endDate': DateFormat('dd/MM/yyyy').format(_endDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medication saved successfully!'),
          backgroundColor: Colors.black,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving medication: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Medication with Search',
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
              controller: _medicationController,
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

            const Text(
              'Type',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedMedicationType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: ['tablets', 'liquid', 'capsule', 'injection', 'drops']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value.capitalize()),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedMedicationType = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),

            const Text(
              'Intake Time',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedIntakeTime,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: ['before meals', 'after meals', 'with meals', 'on empty stomach']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value.capitalize()),
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
                              dose['time'].format(context),
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
} 
