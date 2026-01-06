import 'package:flutter/material.dart';

class Pie {
  final Color color;
  final double proportion;

  Pie({required this.color, required this.proportion});

  Color get getColor => color;

  double get getPercentage => proportion;
} 
