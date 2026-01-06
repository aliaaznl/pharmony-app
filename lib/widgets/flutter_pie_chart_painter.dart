import 'package:flutter/material.dart';
import 'pie.dart';
import 'dart:math' as math;

class FlutterPieChartPainter extends CustomPainter {
  final List<Pie> pies;
  final int selected;
  final double animFraction;
  double _totalAngle = math.pi * 2;
  
  FlutterPieChartPainter({
    required this.pies,
    required this.selected,
    required this.animFraction,
  }) {
    _totalAngle = animFraction * math.pi * 2;
    assert(selected < pies.length || selected == -1,
        "The selected pie must be in the pies list range or -1!!");
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width < size.height ? size.width : size.height;
    final Paint paint = Paint();
    double totalProp = 0.0;
    for (final pie in pies) {
      totalProp = totalProp + pie.proportion;
    }
    
    // Much simpler approach: just animate the total sweep angle
    final totalAnimatedAngle = animFraction * math.pi * 2;
    
    double currentAngle = 0.0;
    double remainingAngle = totalAnimatedAngle;
    
    // Store text positions to check for overlaps
    List<Rect> textBounds = [];
    
    for (int i = 0; i < pies.length && remainingAngle > 0; i++) {
      final percentage = pies[i].proportion / totalProp;
      final fullSegmentAngle = percentage * math.pi * 2;
      
      // Calculate how much of this segment to draw
      final segmentAngle = math.min(remainingAngle, fullSegmentAngle);
      
      if (segmentAngle > 0.01) { // Only draw if there's meaningful angle
        paint
          ..color = pies[i].color
          ..style = PaintingStyle.fill;
        
        canvas.drawArc(
          Rect.fromLTWH(0.0, 0.0, side, size.height), 
          currentAngle - math.pi / 2, // Start from top
          segmentAngle, 
          true, 
          paint
        );
        
        if (selected == i) {
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * 0.012
            ..strokeCap = StrokeCap.round;
          canvas.drawArc(
              Rect.fromCircle(
                  center: Offset(size.width / 2, size.height / 2),
                  radius: side / 2 + size.width / 30),
              currentAngle - math.pi / 2,
              segmentAngle,
              false,
              paint);
        }
        
        // Draw percentage text on segment with improved positioning
        if (percentage > 0.03) { // Show text for segments larger than 3%
          final textStyle = TextStyle(
            color: Colors.white,
            fontSize: _calculateOptimalFontSize(percentage, side),
            fontWeight: FontWeight.bold,
          );
          
          final textSpan = TextSpan(
            text: '${(percentage * 100).round()}%',
            style: textStyle,
          );
          
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          
          textPainter.layout();
          
          // Calculate optimal text position
          final textPosition = _calculateTextPosition(
            currentAngle,
            fullSegmentAngle,
            textPainter,
            size,
            side,
            percentage,
            textBounds,
          );
          
          if (textPosition != null) {
            // Add this text bounds to the list for collision detection
            textBounds.add(Rect.fromLTWH(
              textPosition.dx,
              textPosition.dy,
              textPainter.width,
              textPainter.height,
            ));
            
            textPainter.paint(canvas, textPosition);
          }
        }
      }
      
      currentAngle += fullSegmentAngle;
      remainingAngle -= segmentAngle;
    }
  }

  double _calculateOptimalFontSize(double percentage, double side) {
    // Adjust font size based on segment size
    if (percentage > 0.3) return side * 0.1; // Large segments
    if (percentage > 0.15) return side * 0.08; // Medium segments
    if (percentage > 0.08) return side * 0.06; // Small segments
    return side * 0.05; // Very small segments
  }

  Offset? _calculateTextPosition(
    double currentAngle,
    double segmentAngle,
    TextPainter textPainter,
    Size size,
    double side,
    double percentage,
    List<Rect> existingTextBounds,
  ) {
    final segmentCenterAngle = currentAngle + (segmentAngle / 2) - math.pi / 2;
    
    // Try different radius positions to find the best fit
    final radiusOptions = [side / 3, side / 2.5, side / 2, side / 1.8];
    
    for (double radius in radiusOptions) {
      final textX = size.width / 2 + radius * math.cos(segmentCenterAngle);
      final textY = size.height / 2 + radius * math.sin(segmentCenterAngle);
      
      final textOffset = Offset(
        textX - textPainter.width / 2,
        textY - textPainter.height / 2,
      );
      
      final textRect = Rect.fromLTWH(
        textOffset.dx,
        textOffset.dy,
        textPainter.width,
        textPainter.height,
      );
      
      // Check if text fits within the chart bounds
      if (textRect.left >= 0 && 
          textRect.right <= size.width &&
          textRect.top >= 0 && 
          textRect.bottom <= size.height) {
        
        // Check for overlaps with existing text
        bool hasOverlap = false;
        for (Rect existingRect in existingTextBounds) {
          if (textRect.overlaps(existingRect)) {
            hasOverlap = true;
            break;
          }
        }
        
        if (!hasOverlap) {
          return textOffset;
        }
      }
    }
    
    // If no good position found, try positioning outside the segment
    if (percentage > 0.1) {
      final outerRadius = side / 1.5;
      final textX = size.width / 2 + outerRadius * math.cos(segmentCenterAngle);
      final textY = size.height / 2 + outerRadius * math.sin(segmentCenterAngle);
      
      final textOffset = Offset(
        textX - textPainter.width / 2,
        textY - textPainter.height / 2,
      );
      
      final textRect = Rect.fromLTWH(
        textOffset.dx,
        textOffset.dy,
        textPainter.width,
        textPainter.height,
      );
      
      // Check if it fits within chart bounds
      if (textRect.left >= 0 && 
          textRect.right <= size.width &&
          textRect.top >= 0 && 
          textRect.bottom <= size.height) {
        return textOffset;
      }
    }
    
    // If all else fails, don't show text for this segment
    return null;
  }

  @override
  bool shouldRepaint(covariant FlutterPieChartPainter oldDelegate) =>
      oldDelegate.animFraction != animFraction ||
      oldDelegate.pies != pies ||
      oldDelegate.selected != selected;
} 
