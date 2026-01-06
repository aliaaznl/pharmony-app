import 'package:flutter/material.dart';
import 'flutter_pie_chart_painter.dart';
import 'pie.dart';
import 'dart:math' as math;

class FlutterPieChart extends StatefulWidget {
  FlutterPieChart({
    super.key,
    required this.pies,
    required this.selected,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.onTap,
  }) {
    assert(selected < pies.length || selected == -1,
        "The selected pie must be in the pies list range or -1!!");
  }
  
  final List<Pie> pies;
  final int selected;
  final Duration animationDuration;
  final Function(int)? onTap;
  
  @override
  _FlutterPieChartState createState() => _FlutterPieChartState();
}

class _FlutterPieChartState extends State<FlutterPieChart>
    with SingleTickerProviderStateMixin {
  late Animation<double> animation;
  AnimationController? controller;
  double _animFraction = 0.0;
  
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    final Animation curve = CurvedAnimation(
      parent: controller!,
      curve: Curves.easeInOut,
    );
    animation =
        Tween<double>(begin: 0, end: 1).animate(curve as Animation<double>)
          ..addListener(() {
            if (mounted) {
              setState(() {
                _animFraction = animation.value;
              });
            }
          });
    
    // Start animation immediately
    controller!.forward();
  }

  @override
  void didUpdateWidget(FlutterPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pies != widget.pies) {
      controller?.reset();
      controller?.forward();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (TapDownDetails details) {
        if (widget.onTap != null) {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final size = renderBox.size;
          final center = Offset(size.width / 2, size.height / 2);
          final tapPosition = details.localPosition;
          final dx = tapPosition.dx - center.dx;
          final dy = tapPosition.dy - center.dy;
          final angle = (math.atan2(dy, dx) + math.pi / 2) % (2 * math.pi);
          
          double totalProp = 0.0;
          for (final pie in widget.pies) {
            totalProp += pie.proportion;
          }
          
          double currentAngle = 0.0;
          for (int i = 0; i < widget.pies.length; i++) {
            final pieAngle = (widget.pies[i].proportion / totalProp) * 2 * math.pi;
            if (angle >= currentAngle && angle < currentAngle + pieAngle) {
              widget.onTap!(i);
              break;
            }
            currentAngle += pieAngle;
          }
        }
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: FlutterPieChartPainter(
            pies: widget.pies,
            selected: widget.selected,
            animFraction: _animFraction,
          ),
        ),
      ),
    );
  }
} 
