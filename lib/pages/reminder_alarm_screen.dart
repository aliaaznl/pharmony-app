import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ReminderAlarmScreen extends StatefulWidget {
  final String medicineName;
  final String instructions;
  final String time;
  final VoidCallback onTaken;
  final VoidCallback onSkipped;
  final VoidCallback onSnoozed;

  const ReminderAlarmScreen({
    super.key,
    required this.medicineName,
    required this.instructions,
    required this.time,
    required this.onTaken,
    required this.onSkipped,
    required this.onSnoozed,
  });

  @override
  State<ReminderAlarmScreen> createState() => _ReminderAlarmScreenState();
}

class _ReminderAlarmScreenState extends State<ReminderAlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  double _slidePosition = 0.0;
  final double _slideThreshold = 0.8;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final slideContainerWidth = screenWidth - 60;
    final slideButtonSize = 60.0;
    final maxSlideDistance = slideContainerWidth - slideButtonSize - 20;
    final now = DateTime.now();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2b5f56),
              Color(0xFF4c8479),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circular time display - redesigned to match the translucent circle
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Soft, translucent teal color matching the image
                    color: const Color(0xFF7FB3A8).withOpacity(0.25), // Translucent soft teal
                    // Enhanced shadow for floating effect (no border)
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 25,
                        spreadRadius: 3,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Time display with better contrast
                        Text(
                          widget.time,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w300,
                            fontFamily: 'monospace',
                            shadows: [
                              Shadow(
                                offset: Offset(0, 2),
                                blurRadius: 4,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Day and date with improved styling
                        Text(
                          DateFormat('EEE, dd MMM').format(now),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Medicine name
                Text(
                  widget.medicineName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Instructions
                Text(
                  widget.instructions,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),

                // Slide to take medicine
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(
                      color: _slidePosition > maxSlideDistance * _slideThreshold 
                          ? Colors.green 
                          : Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Background text
                      Center(
                        child: Text(
                          _slidePosition > maxSlideDistance * _slideThreshold 
                              ? "RELEASE TO TAKE MEDICINE" 
                              : "SLIDE TO TAKE MEDICINE",
                          style: TextStyle(
                            color: _slidePosition > maxSlideDistance * _slideThreshold 
                                ? Colors.green 
                                : Colors.white.withOpacity(0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      
                      // Sliding button
                      Positioned(
                        left: 10 + _slidePosition,
                        top: 10,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _slidePosition = (_slidePosition + details.delta.dx)
                                  .clamp(0.0, maxSlideDistance);
                            });
                          },
                          onPanEnd: (details) {
                            if (_slidePosition > maxSlideDistance * _slideThreshold) {
                              print('✅ Medicine taken via slide');
                              HapticFeedback.heavyImpact();
                              widget.onTaken();
                            } else {
                              // Reset position
                              setState(() {
                                _slidePosition = 0.0;
                              });
                            }
                          },
                          child: Container(
                            width: slideButtonSize,
                            height: slideButtonSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _slidePosition > maxSlideDistance * _slideThreshold 
                                  ? Colors.green 
                                  : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _slidePosition > maxSlideDistance * _slideThreshold 
                                  ? Icons.check 
                                  : Icons.arrow_forward_ios,
                              color: _slidePosition > maxSlideDistance * _slideThreshold 
                                  ? Colors.white 
                                  : Colors.black,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30), // Reduced from 40

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: "SNOOZE",
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          widget.onSnoozed();
                        },
                        color: Colors.orange, // Yellow/orange for snooze
                        icon: Icons.snooze,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildActionButton(
                        label: "DISMISS",
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onSkipped();
                        },
                        color: Colors.red, // Red for dismiss
                        icon: Icons.close,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
    required IconData icon,
  }) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2), // Use the color parameter
          foregroundColor: color, // Icon and text color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: color.withOpacity(0.5), width: 2), // Border color
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color, // Ensure text color matches
              ),
            ),
          ],
        ),
      ),
    );
  }
} 

