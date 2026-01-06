import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/pdf_chart_api.dart';
import 'settings.dart';
import '../widgets/flutter_pie_chart.dart';
import '../widgets/pie.dart';
import '../service/caregiver_service.dart';

class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});

  @override
  _ChartsPageState createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _symptomsData = [];
  List<Map<String, dynamic>> _healthMetricsData = [];
  List<Map<String, dynamic>> _medicationData = [];
  bool _isLoading = true;
  String _selectedTimeRange = '7 days';
  
  // Animation controllers for interactive effects
  late AnimationController _chartAnimationController;
  late AnimationController _gaugeAnimationController;
  bool _controllersInitialized = false;
  
  // Touch interaction state
  int _touchedLineIndex = -1;
  String? _selectedSymptom;
  int _selectedPieIndex = -1;

  final List<String> _timeRanges = ['7 days', '30 days', '90 days'];

  void _onTimeRangeChanged(String? newValue) {
    if (newValue != null && newValue != _selectedTimeRange) {
      setState(() {
        _selectedTimeRange = newValue;
      });
      _loadData(); // Reload data with new time range
    }
  }

  // Export functionality state
  bool _exportMedication = false;
  bool _exportBloodPressure = false;
  bool _exportSymptoms = false;
  bool _isExporting = false;
  DateTimeRange? _selectedDateRange;
  String _selectedDuration = '7 days';
  final List<String> _durationOptions = ['7 days', '30 days', '90 days', 'Custom'];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadData();
  }

  void _initializeControllers() {
    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _gaugeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _controllersInitialized = true;
  }

  double get _safeChartAnimationValue {
    return _controllersInitialized ? _chartAnimationController.value : 1.0;
  }

  double get _safeGaugeAnimationValue {
    return _controllersInitialized ? _gaugeAnimationController.value : 1.0;
  }

  @override
  void dispose() {
    // Cancel any ongoing export operations
    _isExporting = false;
    
    if (_controllersInitialized) {
      _chartAnimationController.dispose();
      _gaugeAnimationController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    // Start animations
    if (_controllersInitialized) {
      _chartAnimationController.reset();
      _gaugeAnimationController.reset();
    }

    final user = _auth.currentUser;
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    if (effectiveUserId == null) return;

    try {
      final now = DateTime.now();
      DateTime startDate;
      
      switch (_selectedTimeRange) {
        case '7 days':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case '30 days':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case '90 days':
          startDate = now.subtract(const Duration(days: 90));
          break;
        default:
          startDate = now.subtract(const Duration(days: 7));
      }

      // Load symptoms data for the selected time range
      final symptomsQuery = await _firestore
          .collection('Symptoms')
          .where('userId', isEqualTo: effectiveUserId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
          .orderBy('timestamp', descending: true)
          .limit(500)
          .get();

      // Load health metrics data for the selected time range
      final metricsQuery = await _firestore
          .collection('BloodPressure')
          .where('userId', isEqualTo: effectiveUserId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
          .orderBy('timestamp', descending: true)
          .limit(500)
          .get();

      // Load medication data for the selected time range
      final medicationQuery = await _firestore
          .collection('Medications')
          .where('userId', isEqualTo: effectiveUserId)
          .get(); // Remove time filter to get all medications for the user

      // Convert data to lists (already filtered by date range at database level)
      final filteredSymptomsData = symptomsQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      final filteredMetricsData = metricsQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      final filteredMedicationData = medicationQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      print('📊 Data loaded for $_selectedTimeRange:');
      print('   🏥 Symptoms: ${filteredSymptomsData.length} records');
      print('   💓 Health Metrics: ${filteredMetricsData.length} records');
      print('   💊 Medications: ${filteredMedicationData.length} records');
      print('   📅 Date range: ${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(now)}');
      print('   👤 Effective User ID: $effectiveUserId');
      print('   🔄 Is Caregiver Mode: ${CaregiverService.isInCaregiverMode}');
      
      // Debug medication data
      for (var medication in filteredMedicationData) {
        final medicationName = medication['medicationName'] as String? ?? 'Unknown';
        final startDateStr = medication['startDate'] as String? ?? 'No start date';
        final endDateStr = medication['endDate'] as String? ?? 'No end date';
        final doses = medication['doses'] as List<dynamic>? ?? [];
        print('   💊 Medication: $medicationName, Start: $startDateStr, End: $endDateStr, Doses: ${doses.length}');
      }
      
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _symptomsData = filteredSymptomsData;
          _healthMetricsData = filteredMetricsData;
          _medicationData = filteredMedicationData;
          _isLoading = false;
        });
        
        // Start animations after data is loaded
        if (_controllersInitialized) {
          _chartAnimationController.forward();
          _gaugeAnimationController.forward();
        }
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _getLatestSymptomsSeverity() {
    Map<String, dynamic> latestSymptoms = {};
    
    // Filter symptoms data by the selected time range
    final now = DateTime.now();
    DateTime startDate;
    
    switch (_selectedTimeRange) {
      case '7 days':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case '30 days':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case '90 days':
        startDate = now.subtract(const Duration(days: 90));
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }
    
    print('🏥 Symptoms filtering for $_selectedTimeRange:');
    print('   📅 Date range: ${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(now)}');
    print('   📊 Total symptoms records: ${_symptomsData.length}');
    
    int filteredCount = 0;
    
    for (var symptomEntry in _symptomsData) {
      final timestamp = (symptomEntry['timestamp'] as Timestamp?)?.toDate();
      if (timestamp == null) continue;
      
      // Only include symptoms within the selected time range
      if (timestamp.isAfter(startDate) && timestamp.isBefore(now)) {
        filteredCount++;
        List<dynamic> symptoms = symptomEntry['symptoms'] ?? [];
        double severity = (symptomEntry['severityScale'] ?? 5.0).toDouble();
        
        for (var symptom in symptoms) {
          if (!latestSymptoms.containsKey(symptom) || 
              timestamp.isAfter(
                (latestSymptoms[symptom]['timestamp'] as Timestamp).toDate()
              )) {
            latestSymptoms[symptom] = {
              'severity': severity,
              'timestamp': symptomEntry['timestamp'],
            };
          }
        }
      }
    }
    
    print('   ✅ Filtered symptoms records: $filteredCount');
    print('   🎯 Unique symptoms found: ${latestSymptoms.length}');
    
    return latestSymptoms;
  }

  Future<Map<String, int>> _calculateMedicationAdherence() async {
    int totalExpectedDoses = 0;
    int takenDoses = 0;
    int skippedDoses = 0;
    int snoozedDoses = 0;
    int missedDoses = 0;
    
    final now = DateTime.now();
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    
    if (effectiveUserId == null) {
      return {'taken': 0, 'missed': 0, 'total': 0, 'skipped': 0, 'snoozed': 0};
    }
    
    // Get date range based on selection
    DateTime startDate;
    switch (_selectedTimeRange) {
      case '7 days':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case '30 days':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case '90 days':
        startDate = now.subtract(const Duration(days: 90));
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }
    
    print('🔍 Medication adherence calculation for $_selectedTimeRange:');
    print('   📅 Date range: ${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(now)}');
    
    try {
      // Step 1: Get all active medications for the user
      final medicationsQuery = await _firestore
          .collection('Medications')
          .where('userId', isEqualTo: effectiveUserId)
          .get();
      
      final medications = medicationsQuery.docs.map((doc) => doc.data()).toList();
      print('   💊 Found ${medications.length} medications for user: $effectiveUserId');
      
      // Step 2: Calculate expected doses for each medication
      for (var medication in medications) {
        final medicationName = medication['medicationName'] as String? ?? '';
        final doses = medication['doses'] as List<dynamic>? ?? [];
        final startDateStr = medication['startDate'] as String? ?? '';
        final endDateStr = medication['endDate'] as String? ?? '';
        
        if (doses.isEmpty) continue;
        
        // Parse medication date range
        DateTime? medicationStartDate;
        DateTime? medicationEndDate;
        
        try {
          if (startDateStr.isNotEmpty) {
            medicationStartDate = DateFormat('dd/MM/yyyy').parse(startDateStr);
          }
          if (endDateStr.isNotEmpty) {
            medicationEndDate = DateFormat('dd/MM/yyyy').parse(endDateStr);
          }
        } catch (e) {
          print('   ⚠️ Error parsing dates for medication $medicationName: $e');
          continue;
        }
        
        // Calculate effective date range (intersection of medication dates and selected time range)
        DateTime effectiveStartDate = startDate;
        DateTime effectiveEndDate = now;
        
        if (medicationStartDate != null && medicationStartDate.isAfter(startDate)) {
          effectiveStartDate = medicationStartDate;
        }
        if (medicationEndDate != null && medicationEndDate.isBefore(now)) {
          effectiveEndDate = medicationEndDate;
        }
        
        // Skip if medication is not active in the selected time range
        if (effectiveStartDate.isAfter(effectiveEndDate)) {
          print('   ⏭️ Skipping $medicationName - not active in selected time range');
          continue;
        }
        
        // Calculate expected doses for this medication
        final daysInRange = effectiveEndDate.difference(effectiveStartDate).inDays + 1;
        final dosesPerDay = doses.length;
        final expectedDosesForMedication = daysInRange * dosesPerDay;
        
        print('   📋 $medicationName: $dosesPerDay doses/day × $daysInRange days = $expectedDosesForMedication expected doses');
        
        totalExpectedDoses += expectedDosesForMedication;
      }
      
      print('   📊 Total expected doses: $totalExpectedDoses');
      
      // Step 3: Get actual medication status records
      final statusQueryWithUserId = await _firestore
          .collection('MedicationStatus')
          .where('userId', isEqualTo: effectiveUserId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThan: Timestamp.fromDate(now))
          .get();
      
      final statusQueryAll = await _firestore
          .collection('MedicationStatus')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThan: Timestamp.fromDate(now))
          .get();
      
      final allStatusData = [...statusQueryWithUserId.docs, ...statusQueryAll.docs];
      final statusData = allStatusData.map((doc) => doc.data()).toList();
      
      // Remove duplicates and filter by user
      final uniqueStatusData = <Map<String, dynamic>>[];
      final seenKeys = <String>{};
      
      for (var status in statusData) {
        final medicationId = status['medicationId'] as String? ?? '';
        final timestamp = status['timestamp'] as Timestamp?;
        final userId = status['userId'] as String?;
        
        // Only include records for the current user or records without userId (backward compatibility)
        if (timestamp != null && (userId == null || userId == effectiveUserId)) {
          final key = '${medicationId}_${timestamp.millisecondsSinceEpoch}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            uniqueStatusData.add(status);
          }
        }
      }
      
      print('   📊 Found ${uniqueStatusData.length} unique medication status records');
      
      // Step 4: Count actual statuses
      for (var status in uniqueStatusData) {
        final statusValue = status['status']?.toString().toLowerCase() ?? '';
        final timestamp = (status['timestamp'] as Timestamp?)?.toDate();
        final medicationId = status['medicationId'] as String? ?? '';
        final userId = status['userId'] as String? ?? 'no userId';
        
        // Skip records that don't look like actual medication doses
        if (medicationId.startsWith('bp_reminder_') || 
            medicationId.startsWith('test_') ||
            medicationId.isEmpty) {
          print('   ⏭️ Skipping non-medication record: $medicationId');
          continue;
        }
        
        print('   📋 Status: $statusValue for medicationId: $medicationId (userId: $userId) at ${timestamp != null ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp) : 'unknown time'}');
        
        // Count individual statuses
        switch (statusValue) {
          case 'taken':
            takenDoses++;
            break;
          case 'skipped':
            skippedDoses++;
            break;
          case 'snoozed':
            snoozedDoses++;
            break;
          case 'missed':
            missedDoses++;
            break;
        }
      }
      
      // Step 5: Calculate missed doses as the difference between expected and recorded
      final recordedDoses = takenDoses + skippedDoses + snoozedDoses;
      final calculatedMissed = totalExpectedDoses - recordedDoses;
      
      // Use the higher of calculated missed or explicitly recorded missed
      missedDoses = math.max(calculatedMissed > 0 ? calculatedMissed : 0, missedDoses);
      
      // Ensure we don't have negative values
      if (missedDoses < 0) missedDoses = 0;
      
      print('   📈 Adherence Summary:');
      print('      Expected Total: $totalExpectedDoses');
      print('      Taken: $takenDoses');
      print('      Skipped: $skippedDoses');
      print('      Snoozed: $snoozedDoses');
      print('      Missed: $missedDoses');
      print('      Recorded: $recordedDoses');
      
      // Calculate adherence percentage
      final adherencePercentage = totalExpectedDoses > 0 
          ? ((takenDoses / totalExpectedDoses) * 100).toStringAsFixed(1)
          : '0.0';
      
      print('      Adherence Rate: $adherencePercentage%');
      
      return {
        'taken': takenDoses,
        'missed': missedDoses,
        'skipped': skippedDoses,
        'snoozed': snoozedDoses,
        'total': totalExpectedDoses,
      };
    } catch (e) {
      print('Error calculating medication adherence: $e');
      return {'taken': 0, 'missed': 0, 'total': 0, 'skipped': 0, 'snoozed': 0};
    }
  }

  Color _getSymptomColor(String symptom) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.deepOrange,
    ];
    
    final index = symptom.hashCode % colors.length;
    return colors[index.abs()];
  }

  Color _getSeverityColor(double severity) {
    if (severity <= 2) return Colors.green;
    if (severity <= 4) return Colors.lightGreen;
    if (severity <= 6) return Colors.orange;
    if (severity <= 8) return Colors.deepOrange;
    return Colors.red;
  }

  String _getSeverityLabel(double value) {
    if (value <= 2) return 'Mild';
    if (value <= 4) return 'Light';
    if (value <= 6) return 'Moderate';
    if (value <= 8) return 'Severe';
    return 'Very Severe';
  }

  Color _getAdherenceColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 80) return Colors.lightGreen;
    if (percentage >= 70) return Colors.orange;
    if (percentage >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  void _showSymptomDetails(String symptom, double severity, DateTime timestamp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.sick, color: _getSeverityColor(severity)),
            const SizedBox(width: 8),
            Text(symptom),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Severity: ${severity.toStringAsFixed(1)}/10',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getSeverityColor(severity),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Level: ${_getSeverityLabel(severity)}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Last recorded: ${DateFormat('MMM dd, yyyy at HH:mm').format(timestamp)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationAdherencePieChart() {
    print('Debug: Building medication adherence pie chart for $_selectedTimeRange');
    return FutureBuilder<Map<String, int>>(
      future: _calculateMedicationAdherence(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 250,
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.black,
              ),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.hasError) {
          return SizedBox(
            height: 250,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medication, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'No medication data for $_selectedTimeRange',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        final adherenceData = snapshot.data!;
        final totalDoses = adherenceData['total'] ?? 0;
        
        if (totalDoses == 0) {
          return SizedBox(
            height: 250,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medication, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'No medication data for $_selectedTimeRange',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        final takenDoses = adherenceData['taken'] ?? 0;
        final missedDoses = adherenceData['missed'] ?? 0;
        final skippedDoses = adherenceData['skipped'] ?? 0;
        final snoozedDoses = adherenceData['snoozed'] ?? 0;
        
        // Calculate adherence percentage
        final adherencePercentage = totalDoses > 0 
            ? ((takenDoses / totalDoses) * 100).toStringAsFixed(1)
            : '0.0';
        
        print('📊 Pie Chart Data for $_selectedTimeRange:');
        print('   Expected Total: $totalDoses');
        print('   Taken: $takenDoses');
        print('   Missed: $missedDoses');
        print('   Skipped: $skippedDoses');
        print('   Snoozed: $snoozedDoses');
        print('   Adherence Rate: $adherencePercentage%');
        
        // Create pie segments for custom chart
        List<Pie> pieSegments = [];
        
        if (takenDoses > 0) {
          pieSegments.add(Pie(
            color: const Color(0xFF56BE8B),
            proportion: takenDoses.toDouble(),
          ));
        }
        if (missedDoses > 0) {
          pieSegments.add(Pie(
            color: const Color(0xFFFF4757),
            proportion: missedDoses.toDouble(),
          ));
        }
        if (skippedDoses > 0) {
          pieSegments.add(Pie(
            color: const Color(0xFFFFB366),
            proportion: skippedDoses.toDouble(),
          ));
        }
        if (snoozedDoses > 0) {
          pieSegments.add(Pie(
            color: const Color(0xFF2D8BBA),
            proportion: snoozedDoses.toDouble(),
          ));
        }
        
        // Create legend items based on available data
        List<Widget> legendItems = [];
        if (takenDoses > 0) legendItems.add(_buildLegendItem('Taken', const Color(0xFF56BE8B)));
        if (missedDoses > 0) legendItems.add(_buildLegendItem('Missed', const Color(0xFFFF4757)));
        if (skippedDoses > 0) legendItems.add(_buildLegendItem('Skipped', const Color(0xFFFFB366)));
        if (snoozedDoses > 0) legendItems.add(_buildLegendItem('Snoozed', const Color(0xFF2D8BBA)));
        
        // If no data, show default legend
        if (legendItems.isEmpty) {
          legendItems = [
            _buildLegendItem('Taken', const Color(0xFF56BE8B)),
            _buildLegendItem('Missed', const Color(0xFFFF4757)),
            _buildLegendItem('Skipped', const Color(0xFFFFB366)),
            _buildLegendItem('Snoozed', const Color(0xFF2D8BBA)),
          ];
        }
        
        return Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0d6b5c).withValues(alpha: 0.05),
                const Color(0xFF0d6b5c).withValues(alpha: 0.1),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF0d6b5c).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: SizedBox(
              height: 200,
              width: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Custom Animated Pie Chart
                  if (pieSegments.isNotEmpty)
                    FlutterPieChart(
                      key: ValueKey(pieSegments.length),
                      pies: pieSegments,
                      selected: _selectedPieIndex,
                      animationDuration: const Duration(milliseconds: 20000),
                      onTap: (index) {
                        setState(() {
                          _selectedPieIndex = index;
                        });
                        _showSegmentInfo(context, index, adherenceData);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInteractiveSymptomGaugeChart(String symptom, double severity) {
    final color = _getSeverityColor(severity);
    final percentage = severity / 10;
    
    return GestureDetector(
      onTap: () {
        final symptomData = _getLatestSymptomsSeverity()[symptom];
        final timestamp = (symptomData['timestamp'] as Timestamp).toDate();
        _showSymptomDetails(symptom, severity, timestamp);
      },
      child: _controllersInitialized ? AnimatedBuilder(
        animation: _gaugeAnimationController,
        builder: (context, child) {
          return Container(
            width: 140,
            height: 160,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _selectedSymptom == symptom ? color.withValues(alpha: 0.1) : Colors.transparent,
              border: _selectedSymptom == symptom 
                ? Border.all(color: color, width: 2)
                : null,
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: PieChart(
                          PieChartData(
                            startDegreeOffset: 270,
                            sectionsSpace: 0,
                            centerSpaceRadius: 30,
                            sections: [
                              PieChartSectionData(
                                value: percentage * 100 * _safeGaugeAnimationValue,
                                color: color,
                                radius: 15,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: (1 - percentage) * 100,
                                color: Colors.grey[300]!,
                                radius: 15,
                                showTitle: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${severity.round()}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            '/10',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  symptom,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _getSeverityLabel(severity),
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ) : Container(
        width: 140,
        height: 160,
        margin: const EdgeInsets.all(8),
        child: Column(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: PieChart(
                      PieChartData(
                        startDegreeOffset: 270,
                        sectionsSpace: 0,
                        centerSpaceRadius: 30,
                        sections: [
                          PieChartSectionData(
                            value: percentage * 100,
                            color: color,
                            radius: 15,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: (1 - percentage) * 100,
                            color: Colors.grey[300]!,
                            radius: 15,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${severity.round()}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        '/10',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              symptom,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _getSeverityLabel(severity),
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveMetricsLineChart() {
    print('Debug: Building metrics chart with ${_healthMetricsData.length} data points');
    
    // Filter health metrics data by the selected time range
    final now = DateTime.now();
    DateTime startDate;
    
    switch (_selectedTimeRange) {
      case '7 days':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case '30 days':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case '90 days':
        startDate = now.subtract(const Duration(days: 90));
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }
    
    // Filter data by time range
    final filteredData = _healthMetricsData.where((data) {
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      if (timestamp == null) return false;
      return timestamp.isAfter(startDate) && timestamp.isBefore(now);
    }).toList();
    
    print('💓 Health Metrics filtering for $_selectedTimeRange:');
    print('   📅 Date range: ${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(now)}');
    print('   📊 Total records: ${_healthMetricsData.length}');
    print('   ✅ Filtered records: ${filteredData.length}');
    
    if (filteredData.isEmpty) {
      return SizedBox(
        height: 250,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.monitor_heart, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'No health metrics data for $_selectedTimeRange',
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Sort data by timestamp
    final sortedData = List<Map<String, dynamic>>.from(filteredData);
    sortedData.sort((a, b) {
      final timestampA = (a['timestamp'] as Timestamp).toDate();
      final timestampB = (b['timestamp'] as Timestamp).toDate();
      return timestampA.compareTo(timestampB);
    });

    // Prepare chart data
    final systolicSpots = <FlSpot>[];
    final diastolicSpots = <FlSpot>[];
    final pulseSpots = <FlSpot>[];

    for (int i = 0; i < sortedData.length; i++) {
      final data = sortedData[i];
      final x = i.toDouble();
      
      final systolic = (data['systolic'] ?? 0).toDouble();
      final diastolic = (data['diastolic'] ?? 0).toDouble();
      final pulse = (data['pulse'] ?? 0).toDouble();

      if (systolic > 0) systolicSpots.add(FlSpot(x, systolic));
      if (diastolic > 0) diastolicSpots.add(FlSpot(x, diastolic));
      if (pulse > 0) pulseSpots.add(FlSpot(x, pulse));
    }

    return AnimatedBuilder(
      animation: _chartAnimationController,
      builder: (context, child) {
        return SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 20,
                verticalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[300]!,
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: Colors.grey[300]!,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: math.max(1, sortedData.length / 4).toDouble(),
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < sortedData.length) {
                        final timestamp = (sortedData[index]['timestamp'] as Timestamp).toDate();
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Transform.rotate(
                            angle: -0.5, // Slight rotation to prevent overlap
                            child: Text(
                              DateFormat('dd/MM').format(timestamp),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return Container();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 20,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      );
                    },
                    reservedSize: 28,
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey[400]!, width: 1),
              ),
              minX: 0,
              maxX: math.max(0, sortedData.length - 1).toDouble(),
              minY: 0,
              maxY: 200,
              lineBarsData: [
                // Systolic line
                if (systolicSpots.isNotEmpty)
                  LineChartBarData(
                    spots: systolicSpots.map((spot) => FlSpot(spot.x,spot.y *
                     _safeChartAnimationValue
                    )).toList(),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withValues(alpha: 0.8),Colors.red,],),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.red,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withValues(alpha: 0.3),
                          Colors.red.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                // Diastolic line
                if (diastolicSpots.isNotEmpty)
                  LineChartBarData(
                    spots: diastolicSpots.map((spot) => FlSpot(spot.x, spot.y * 
                    _safeChartAnimationValue
                    )).toList(),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withValues(alpha: 0.8), Colors.blue,],),

                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.blue,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withValues(alpha: 0.3),
                          Colors.blue.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                // Pulse line
                if (pulseSpots.isNotEmpty)
                  LineChartBarData(
                    spots: pulseSpots.map((spot) => FlSpot(spot.x, spot.y * 
                    _safeChartAnimationValue
                    )).toList(),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [Colors.green.withValues(alpha: 0.8), Colors.green,],),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.green,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withValues(alpha: 0.3),
                          Colors.green.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.blueGrey.withValues(alpha: 0.8),
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      const textStyle = TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      );
                      
                      String label = '';
                      Color color = Colors.white;
                      
                      if (touchedSpot.barIndex == 0) {
                        label = 'Systolic';
                        color = Colors.red;
                      } else if (touchedSpot.barIndex == 1) {
                        label = 'Diastolic';
                        color = Colors.blue;
                      } else if (touchedSpot.barIndex == 2) {
                        label = 'Pulse';
                        color = Colors.green;
                      }
                      
                      final index = touchedSpot.x.toInt();
                      final timestamp = (sortedData[index]['timestamp'] as Timestamp).toDate();
                      
                      return LineTooltipItem(
                        '$label: ${touchedSpot.y.round()}\n${DateFormat('MM/dd HH:mm').format(timestamp)}',
                        textStyle.copyWith(color: color),
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
                getTouchLineStart: (data, index) => 0,
                getTouchLineEnd: (data, index) => double.infinity,
                touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                  setState(() {
                    if (touchResponse != null && touchResponse.lineBarSpots != null) {
                      _touchedLineIndex = touchResponse.lineBarSpots!.first.spotIndex;
                    } else {
                      _touchedLineIndex = -1;
                    }
                  });
                },
              ),
            ),
          ),
        );
      },
    );
  }





  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // Sharper corners
          ),
          title: const Text('Export Health Data'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select data to export:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Medication Intake'),
                  value: _exportMedication,
                  onChanged: (value) => setDialogState(() => _exportMedication = value ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Blood Pressure Readings'),
                  value: _exportBloodPressure,
                  onChanged: (value) => setDialogState(() => _exportBloodPressure = value ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Symptoms'),
                  value: _exportSymptoms,
                  onChanged: (value) => setDialogState(() => _exportSymptoms = value ?? false),
                ),
                const SizedBox(height: 16),
                const Text('Select duration:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedDuration,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _durationOptions.map((duration) => DropdownMenuItem(
                    value: duration,
                    child: Text(duration),
                  )).toList(),
                  onChanged: (value) => setDialogState(() => _selectedDuration = value ?? '7 days'),
                ),
                if (_selectedDuration == 'Custom') ...[
                  const SizedBox(height: 16),
                  const Text('Select date range:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final dateRange = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _selectedDateRange,
                      );
                      if (dateRange != null) {
                        setDialogState(() => _selectedDateRange = dateRange);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDateRange != null
                                ? '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}'
                                : 'Select date range',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (_exportMedication || _exportBloodPressure || _exportSymptoms) && !_isExporting
                  ? () async {
                      Navigator.pop(context);
                      await _exportPdf();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0d6b5c),
                foregroundColor: Colors.white,
              ),
              child: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (!mounted) return;
    
    setState(() => _isExporting = true);

    try {
      // Additional mounted check during async operation
      if (!mounted) return;
      final user = _auth.currentUser;
      final effectiveUserId = CaregiverService.getEffectiveUserId();
      if (effectiveUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to export data'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isExporting = false);
        }
        return;
      }

            // Get user info - try multiple collections and fallback to Firebase Auth data  
      String userName = user?.displayName ?? 'User';
      String userEmail = user?.email ?? '';
      String userPhone = '';

      try {
        final userDoc = await _firestore.collection('Users').doc(user?.uid ?? effectiveUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          userName = userData['name'] ?? userName;
          userEmail = userData['email'] ?? userEmail;
          userPhone = userData['phone'] ?? '';
          print('✅ User info from Users collection: $userName');
        } else {
          print('⚠️ User document not found in Users collection');
        }
      } catch (e) {
        print('❌ Error accessing Users collection: $e');
        print('📋 Using Firebase Auth data only');
      }

      // Determine date range
      DateTime startDate, endDate;
      if (_selectedDuration == 'Custom' && _selectedDateRange != null) {
        startDate = _selectedDateRange!.start;
        endDate = _selectedDateRange!.end;
      } else {
        endDate = DateTime.now();
        switch (_selectedDuration) {
          case '7 days':
            startDate = endDate.subtract(const Duration(days: 7));
            break;
          case '30 days':
            startDate = endDate.subtract(const Duration(days: 30));
            break;
          case '90 days':
            startDate = endDate.subtract(const Duration(days: 90));
            break;
          default:
            startDate = endDate.subtract(const Duration(days: 7));
        }
      }
      
      print('📅 Export date range: ${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(endDate)}');
      print('   Duration: $_selectedDuration');
      print('   Start: $startDate');
      print('   End: $endDate');

      // Fetch selected data
      List<Map<String, dynamic>> medicationData = [];
      List<Map<String, dynamic>> bpData = [];
      List<Map<String, dynamic>> symptomsData = [];

      // Check if still mounted before proceeding with data fetching
      if (!mounted) return;

      if (_exportMedication) {
        try {
          print('🔍 Fetching medication data for user: $effectiveUserId');
          print('📅 Date range: ${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(endDate)}');
          
          // First, get all medications for this user
          final medicationQuery = await _firestore
              .collection('Medications')
              .where('userId', isEqualTo: effectiveUserId)
              .limit(100)
              .get();
          
          print('💊 Found ${medicationQuery.docs.length} Medications records for user $effectiveUserId');
          
          // Create a map of medication details
          final Map<String, Map<String, dynamic>> medicationDetails = {};
          for (var doc in medicationQuery.docs) {
            final data = doc.data();
            medicationDetails[doc.id] = data;
            print('  💊 Medication: ${data['medicationName']} - ID: ${doc.id}');
            print('    📋 Details: dose=${data['doseAmount']} ${data['doseType']}, type=${data['medicationType']}, start=${data['startDate']}, end=${data['endDate']}');
          }
          
          // Get medication intake records for this user's medications
          List<Map<String, dynamic>> allMedicationIntake = [];
          
          for (var medicationDoc in medicationQuery.docs) {
            final medicationId = medicationDoc.id;
            final medicationData = medicationDoc.data();
            
            print('  🔍 Checking medication: ${medicationData['medicationName']} (ID: $medicationId)');
            
            // Get all intake records for this medication (exact match)
            final intakeQuery = await _firestore
                .collection('MedicationStatus')
                .where('medicationId', isEqualTo: medicationId)
                .get();
            
            print('    📊 Found ${intakeQuery.docs.length} exact match intake records');
            
            // Also check for dose-specific records (medId_dose_0 format)
            final dosePattern = '${medicationId}_dose_';
            final doseQuery = await _firestore
                .collection('MedicationStatus')
                .get();
            
            final doseRecords = doseQuery.docs.where((doc) {
              final data = doc.data();
              final medId = data['medicationId'] ?? '';
              return medId.startsWith(dosePattern);
            }).toList();
            
            print('    📊 Found ${doseRecords.length} dose-specific intake records');
            
            // Combine both exact and dose-specific records
            final allIntakeRecords = [...intakeQuery.docs, ...doseRecords];
            
            for (var intakeDoc in allIntakeRecords) {
              final intakeData = intakeDoc.data();
              final status = intakeData['status']?.toString().toLowerCase() ?? '';
              final medId = intakeData['medicationId'] ?? '';
              
              print('      📋 Record: status=$status, medicationId=$medId');
              
              // Only include taken, skipped, snoozed records
              if (status == 'taken' || status == 'skipped' || status == 'snoozed') {
                final actionTime = (intakeData['actionTime'] as Timestamp?)?.toDate();
                final timestamp = (intakeData['timestamp'] as Timestamp?)?.toDate();
                final recordTime = actionTime ?? timestamp;
                
                if (recordTime != null) {
                  allMedicationIntake.add({
                    'medicationId': medicationId,
                    'medicationData': medicationData,
                    'intakeData': intakeData,
                    'recordTime': recordTime,
                  });
                  
                  print('        ✅ Added: ${medicationData['medicationName']} - $status - ${DateFormat('dd/MM/yyyy HH:mm').format(recordTime)}');
                } else {
                  print('        ❌ Skipped: No valid timestamp');
                }
              } else {
                print('        ❌ Skipped: Invalid status "$status"');
              }
            }
          }
          
          print('👤 Found ${allMedicationIntake.length} total medication intake records for user');
          
          // Filter by date range and format for export
          medicationData = allMedicationIntake.where((item) {
            final recordTime = item['recordTime'] as DateTime;
            final isInRange = recordTime.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                   recordTime.isBefore(endDate.add(const Duration(days: 1)));
            
            print('  📅 Date check: ${DateFormat('dd/MM/yyyy').format(recordTime)} - In range: $isInRange');
            return isInRange;
          }).map((item) {
            final medicationData = item['medicationData'] as Map<String, dynamic>;
            final intakeData = item['intakeData'] as Map<String, dynamic>;
            final recordTime = item['recordTime'] as DateTime;
            
            return {
              'name': medicationData['medicationName'] ?? '',
              'dose': '${medicationData['doseAmount'] ?? ''} ${medicationData['doseType'] ?? ''}',
              'type': medicationData['medicationType'] ?? '',
              'intakeTime': medicationData['intakeTime'] ?? '',
              'startDate': medicationData['startDate'] ?? '',
              'endDate': medicationData['endDate'] ?? '',
              'status': intakeData['status'] ?? '',
              'date': DateFormat('dd/MM/yyyy').format(recordTime),
              'time': DateFormat('HH:mm').format(recordTime),
              'recordTime': recordTime, // Keep for sorting
            };
          }).toList();
          
          // Sort medication data by date (ascending - oldest to newest)
          medicationData.sort((a, b) {
            final dateA = DateFormat('dd/MM/yyyy').parse(a['date']);
            final dateB = DateFormat('dd/MM/yyyy').parse(b['date']);
            if (dateA.isAtSameMomentAs(dateB)) {
              // If same date, sort by time
              final timeA = DateFormat('HH:mm').parse(a['time']);
              final timeB = DateFormat('HH:mm').parse(b['time']);
              return timeA.compareTo(timeB);
            }
            return dateA.compareTo(dateB);
          });
          
          // Remove recordTime after sorting
          for (var item in medicationData) {
            item.remove('recordTime');
          }
          
          print('✅ Medication intake data fetched: ${medicationData.length} records');
        } catch (e) {
          print('❌ Error fetching medication data: $e');
          medicationData = []; // Continue with empty data
        }
      }

      if (_exportBloodPressure) {
        try {
          final bpQuery = await _firestore
              .collection('BloodPressure')
              .where('userId', isEqualTo: effectiveUserId)
              .limit(500)
              .get();
          
          bpData = bpQuery.docs.map((doc) {
            final data = doc.data();
            final timestamp = (data['timestamp'] as Timestamp).toDate();
            return {
              'date': DateFormat('dd/MM/yyyy').format(timestamp),
              'time': DateFormat('HH:mm').format(timestamp),
              'systolic': data['systolic']?.toString() ?? '',
              'diastolic': data['diastolic']?.toString() ?? '',
              'pulse': data['pulse']?.toString() ?? '',
              'category': data['category']?.toString() ?? '',
              'timestamp': timestamp,
            };
          }).where((item) {
            final timestamp = item['timestamp'] as DateTime;
            return timestamp.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                   timestamp.isBefore(endDate.add(const Duration(days: 1)));
          }).toList();
          
          // Sort blood pressure data by date (ascending - oldest to newest)
          bpData.sort((a, b) {
            final dateA = DateFormat('dd/MM/yyyy').parse(a['date']);
            final dateB = DateFormat('dd/MM/yyyy').parse(b['date']);
            if (dateA.isAtSameMomentAs(dateB)) {
              // If same date, sort by time
              final timeA = DateFormat('HH:mm').parse(a['time']);
              final timeB = DateFormat('HH:mm').parse(b['time']);
              return timeA.compareTo(timeB);
            }
            return dateA.compareTo(dateB);
          });
          
          // Remove timestamp from final data
          for (var item in bpData) {
            item.remove('timestamp');
          }
          print('✅ Blood pressure data fetched: ${bpData.length} records');
        } catch (e) {
          print('❌ Error fetching blood pressure data: $e');
          bpData = []; // Continue with empty data
        }
      }

      if (_exportSymptoms) {
        try {
          final symptomsQuery = await _firestore
              .collection('Symptoms')
              .where('userId', isEqualTo: effectiveUserId)
              .limit(500)
              .get();
          
          symptomsData = symptomsQuery.docs.map((doc) {
            final data = doc.data();
            final timestamp = (data['timestamp'] as Timestamp).toDate();
            final symptoms = (data['symptoms'] as List<dynamic>?)?.join(', ') ?? '';
            return {
              'symptoms': symptoms,
              'severity': data['severityScale']?.toString() ?? '',
              'label': data['severityLabel'] ?? '',
              'date': DateFormat('dd/MM/yyyy').format(timestamp),
              'time': DateFormat('HH:mm').format(timestamp),
              'timestamp': timestamp,
            };
          }).where((item) {
            final timestamp = item['timestamp'] as DateTime;
            return timestamp.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                   timestamp.isBefore(endDate.add(const Duration(days: 1)));
          }).toList();
          
          // Sort symptoms data by date (ascending - oldest to newest)
          symptomsData.sort((a, b) {
            final dateA = DateFormat('dd/MM/yyyy').parse(a['date']);
            final dateB = DateFormat('dd/MM/yyyy').parse(b['date']);
            if (dateA.isAtSameMomentAs(dateB)) {
              // If same date, sort by time
              final timeA = DateFormat('HH:mm').parse(a['time']);
              final timeB = DateFormat('HH:mm').parse(b['time']);
              return timeA.compareTo(timeB);
            }
            return dateA.compareTo(dateB);
          });
          
          // Remove timestamp from final data
          for (var item in symptomsData) {
            item.remove('timestamp');
          }
          print('✅ Symptoms data fetched: ${symptomsData.length} records');
        } catch (e) {
          print('❌ Error fetching symptoms data: $e');
          symptomsData = []; // Continue with empty data
        }
      }

      // Check if we have any data to export
      final hasData = medicationData.isNotEmpty || bpData.isNotEmpty || symptomsData.isNotEmpty;
      if (!hasData) {
        print('⚠️ No data found for export');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No data found for the selected time range'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isExporting = false);
        }
        return;
      }

      // Generate PDF
      final filePath = await PdfChartApi.generateFull(
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        medicationData: medicationData,
        bpData: bpData,
        symptomsData: symptomsData,
        logoPath: 'lib/images/logo.png',
        startDate: startDate,
        endDate: endDate,
      );

      // Check if still mounted after PDF generation
      if (!mounted) return;

      // Save PDF path to SharedPreferences for reports page
      final prefs = await SharedPreferences.getInstance();
      final reports = prefs.getStringList('reports') ?? [];
      reports.add(filePath);
      await prefs.setStringList('reports', reports);

      print('✅ PDF exported successfully: $filePath');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('PDF exported successfully! Opening reports...')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to reports page after a brief delay to show success message
        Future.delayed(Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReportsPage(),
              ),
            );
          }
        });
      }

    } catch (e) {
      print('❌ Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Health Analytics',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0d6b5c),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _showExportDialog,
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Export Data',
          ),
          IconButton(
            onPressed: () async {
              // Add refresh animation
              if (mounted && _controllersInitialized) {
                _chartAnimationController.reset();
                _gaugeAnimationController.reset();
              }
              await _loadData();
            },
            icon: AnimatedBuilder(
              animation: _chartAnimationController,
              builder: (context, child) {
                return AnimatedRotation(
                  turns: _isLoading ? _safeChartAnimationValue * 2 : 0,
                  duration: const Duration(milliseconds: 800),
                  child: const Icon(Icons.refresh, color: Colors.white),
                );
              },
            ),
            tooltip: 'Refresh Data',
          ),

          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedTimeRange = value;
              });
              _loadData();
            },
            itemBuilder: (context) => _timeRanges
                .map((range) => PopupMenuItem(
                      value: range,
                      child: Row(
                        children: [
                          Icon(
                            _selectedTimeRange == range ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: _selectedTimeRange == range ? const Color(0xFF0d6b5c) : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(range),
                        ],
                      ),
                    ))
                .toList(),
            icon: const Icon(Icons.filter_list, color: Colors.white),
            tooltip: 'Filter Time Range',
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF0d6b5c)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Range Indicator
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0d6b5c).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Data for the last $_selectedTimeRange',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D1B2A),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Medication Adherence Pie Chart
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.medication, color: const Color(0xFF0d6b5c), size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: const Text(
                                  'Medication Adherence',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildMedicationAdherencePieChart(),
                          const SizedBox(height: 16),
                          FutureBuilder<Map<String, int>>(
                            future: _calculateMedicationAdherence(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 16,
                                    children: [
                                      _buildLegendItem('Taken', const Color(0xFF56BE8B)),
                                      _buildLegendItem('Missed', const Color(0xFFFF4757)),
                                    ],
                                  ),
                                );
                              }
                              
                              final adherenceData = snapshot.data!;
                              final takenDoses = adherenceData['taken'] ?? 0;
                              final missedDoses = adherenceData['missed'] ?? 0;
                              final skippedDoses = adherenceData['skipped'] ?? 0;
                              final snoozedDoses = adherenceData['snoozed'] ?? 0;
                              
                              List<Widget> legendItems = [];
                              
                              if (takenDoses > 0) {
                                legendItems.add(_buildLegendItem('Taken', const Color(0xFF56BE8B)));
                              }
                              if (missedDoses > 0) {
                                legendItems.add(_buildLegendItem('Missed', const Color(0xFFFF4757)));
                              }
                              if (skippedDoses > 0) {
                                legendItems.add(_buildLegendItem('Skipped', const Color(0xFFFFB366)));
                              }
                              if (snoozedDoses > 0) {
                                legendItems.add(_buildLegendItem('Snoozed', const Color(0xFF2D8BBA)));
                              }
                              
                              return SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: legendItems.isEmpty 
                                    ? [
                                        _buildLegendItem('Taken', const Color(0xFF56BE8B)),
                                        _buildLegendItem('Missed', const Color(0xFFFF4757)),
                                      ]
                                    : legendItems,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Health Metrics Chart
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.monitor_heart, color: const Color(0xFF0d6b5c), size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: const Text(
                                  'Health Metrics Trends',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildInteractiveMetricsLineChart(),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildLegendItem('Systolic', Colors.red),
                              _buildLegendItem('Diastolic', Colors.blue),
                              _buildLegendItem('Pulse', Colors.green),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Symptoms Severity Gauges
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.thermostat, color: const Color(0xFF0d6b5c), size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: const Text(
                                  'Symptoms Severity Overview',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Builder(
                            builder: (context) {
                              final latestSymptoms = _getLatestSymptomsSeverity();
                              
                              if (latestSymptoms.isEmpty) {
                                return SizedBox(
                                  height: 150,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.thermostat, 
                                             size: 48, color: Colors.grey),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No symptoms recorded for $_selectedTimeRange',
                                          style: TextStyle(color: Colors.grey, fontSize: 16),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              
                              return Wrap(
                                alignment: WrapAlignment.spaceEvenly,
                                children: latestSymptoms.entries.map((entry) {
                                  final symptom = entry.key;
                                  final severity = entry.value['severity'];
                                  
                                  return _buildInteractiveSymptomGaugeChart(symptom, severity);
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
                          boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }



  void _showSegmentInfo(BuildContext context, int sectionIndex, Map<String, int> adherenceData) {
    final takenDoses = adherenceData['taken'] ?? 0;
    final missedDoses = adherenceData['missed'] ?? 0;
    final skippedDoses = adherenceData['skipped'] ?? 0;
    final snoozedDoses = adherenceData['snoozed'] ?? 0;
    final totalDoses = adherenceData['total'] ?? 0;
    
    // Create a list of non-zero segments
    List<Map<String, dynamic>> segments = [];
    
    if (takenDoses > 0) {
      segments.add({
        'label': 'Taken',
        'count': takenDoses,
        'color': const Color(0xFF56BE8B),
        'icon': Icons.check_circle,
        'percentage': totalDoses > 0 ? (takenDoses / totalDoses * 100).round() : 0,
      });
    }
    
    if (missedDoses > 0) {
      segments.add({
        'label': 'Missed',
        'count': missedDoses,
        'color': const Color(0xFFFF4757),
        'icon': Icons.cancel,
        'percentage': totalDoses > 0 ? (missedDoses / totalDoses * 100).round() : 0,
      });
    }
    
    if (skippedDoses > 0) {
      segments.add({
        'label': 'Skipped',
        'count': skippedDoses,
        'color': const Color(0xFFFFB366),
        'icon': Icons.skip_next,
        'percentage': totalDoses > 0 ? (skippedDoses / totalDoses * 100).round() : 0,
      });
    }
    
    if (snoozedDoses > 0) {
      segments.add({
        'label': 'Snoozed',
        'count': snoozedDoses,
        'color': const Color(0xFF2D8BBA),
        'icon': Icons.snooze,
        'percentage': totalDoses > 0 ? (snoozedDoses / totalDoses * 100).round() : 0,
      });
    }
    
    if (sectionIndex >= 0 && sectionIndex < segments.length) {
      final segment = segments[sectionIndex];
      
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  segment['color'].withValues(alpha: 0.1),
                  segment['color'].withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon and title
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: segment['color'],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: segment['color'].withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    segment['icon'],
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                
                Text(
                  segment['label'],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: segment['color'],
                  ),
                ),
                const SizedBox(height: 8),
                
                Text(
                  '${segment['count']} doses',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                
                Text(
                  '${segment['percentage']}% of total',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Progress bar
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: segment['percentage'] / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: segment['color'],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: segment['color'],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Close',
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
      );
    }
  }

  // Function to delete test medication status records
  Future<void> _deleteTestMedicationStatus() async {
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    if (effectiveUserId == null) return;
    
    try {
      // Query for test medication status records
      final testRecords = await _firestore
          .collection('MedicationStatus')
          .where('userId', isEqualTo: effectiveUserId)
          .where('medicationId', whereIn: ['test_med_1', 'test_med_2', 'test_med_3'])
          .get();
      
      // Delete each test record
      for (var doc in testRecords.docs) {
        await doc.reference.delete();
      }
      
      print('✅ Deleted ${testRecords.docs.length} test medication status records');
    } catch (e) {
      print('❌ Error deleting test records: $e');
    }
  }



}

// Custom painter for futuristic background pattern
class FuturisticBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0d6b5c).withValues(alpha: 0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw grid pattern
    for (int i = 0; i < size.width; i += 20) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), size.height),
        paint,
      );
    }

    for (int i = 0; i < size.height; i += 20) {
      canvas.drawLine(
        Offset(0, i.toDouble()),
        Offset(size.width, i.toDouble()),
        paint,
      );
    }

    // Draw diagonal lines for tech effect
    paint.color = const Color(0xFF2D8BBA).withValues(alpha: 0.1);
    for (int i = -size.height.toInt(); i < size.width; i += 30) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
