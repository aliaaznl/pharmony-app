import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../service/caregiver_service.dart';

class HeartRateChart extends StatefulWidget {
  final String timeCategory; // 'day', 'week', or 'month'

  const HeartRateChart({
    super.key,
    required this.timeCategory,
  });

  @override
  State<HeartRateChart> createState() => _HeartRateChartState();
}

class _HeartRateChartState extends State<HeartRateChart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String selectedTimeCategory = 'day';

  Stream<QuerySnapshot> _getHeartRateStream() {
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    if (effectiveUserId == null) return Stream.empty();

    DateTime now = DateTime.now();
    DateTime startTime;

    switch (selectedTimeCategory) {
      case 'day':
        startTime = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startTime = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startTime = DateTime(now.year, now.month - 1, now.day);
        break;
      default:
        startTime = DateTime(now.year, now.month, now.day);
    }

    return _firestore
        .collection('HeartRate')
        .where('userId', isEqualTo: effectiveUserId)
        .where('timestamp', isGreaterThanOrEqualTo: startTime)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    selectedTimeCategory = widget.timeCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeCategoryButton('Day'),
              _buildTimeCategoryButton('Week'),
              _buildTimeCategoryButton('Month'),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getHeartRateStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No heart rate data available',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              List<FlSpot> spots = [];
              List<DateTime> timestamps = [];

              for (var i = 0; i < snapshot.data!.docs.length; i++) {
                final doc = snapshot.data!.docs[i];
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = (data['timestamp'] as Timestamp).toDate();
                final rate = (data['rate'] as num).toDouble();
                
                spots.add(FlSpot(i.toDouble(), rate));
                timestamps.add(timestamp);
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 12),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= timestamps.length) return const Text('');
                            DateTime date = timestamps[value.toInt()];
                            String format = selectedTimeCategory == 'day' ? 'HH:mm' : 'MM/dd';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat(format).format(date),
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                          reservedSize: 30,
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: const Color(0xFF0D1B2A),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                                                      color: const Color(0xFF0D1B2A).withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCategoryButton(String category) {
    bool isSelected = selectedTimeCategory.toLowerCase() == category.toLowerCase();
    return ElevatedButton(
      onPressed: () {
        setState(() {
          selectedTimeCategory = category.toLowerCase();
        });
      },
      style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? const Color(0xFF0D1B2A) : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black,
      ),
      child: Text(category),
    );
  }
} 
