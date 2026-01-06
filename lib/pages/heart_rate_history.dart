import 'package:flutter/material.dart';
import 'package:phnew11/widgets/heart_rate_chart.dart';

class HeartRateHistory extends StatelessWidget {
  const HeartRateHistory({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate History'),
        backgroundColor: Colors.black,
      ),
      body: const HeartRateChart(timeCategory: 'day'),
    );
  }
} 
