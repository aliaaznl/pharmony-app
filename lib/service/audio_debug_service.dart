import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioDebugService {
  static Future<void> runAudioDiagnostics() async {
    print('🔍 ========== AUDIO DIAGNOSTICS ==========');
    
    // Test 1: Check AudioPlayer availability
    try {
      final player = AudioPlayer();
      print('✅ AudioPlayer created successfully');
      
      // Test player capabilities
      print('📊 Audio player info:');
      print('  - State: ${player.state}');
      
      await player.dispose();
      print('✅ AudioPlayer disposed successfully');
    } catch (e) {
      print('❌ AudioPlayer test failed: $e');
    }
    
    // Test 2: Check platform audio capabilities
    try {
      print('📱 Testing platform audio...');
      
      // Test haptic feedback (this usually works if audio is working)
      HapticFeedback.lightImpact();
      print('✅ Haptic feedback works');
      
    } catch (e) {
      print('❌ Platform audio test failed: $e');
    }
    
    // Test 3: Asset accessibility
    print('📁 Checking asset configuration...');
    print('  - Expected asset path: assets/audio/reminder.wav');
    print('  - Make sure this path is in pubspec.yaml under assets');
    
    // Test 4: System audio recommendations
    print('🔧 AUDIO TROUBLESHOOTING CHECKLIST:');
    print('  1. Check phone volume (media volume, not ringtone)');
    print('  2. Disable Do Not Disturb mode');
    print('  3. Check if app has notification permissions');
    print('  4. Test with headphones vs speakers');
    print('  5. Restart the app completely');
    print('  6. Check if other apps can play audio');
    
    print('🔍 ========== DIAGNOSTICS COMPLETE ==========');
  }
  
  // Simple audio test with system sounds
  static Future<void> testSystemAudio() async {
    try {
      print('🔊 Testing system audio feedback...');
      
      // Try different haptic patterns
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.heavyImpact();
      
      print('✅ System audio test completed');
    } catch (e) {
      print('❌ System audio test failed: $e');
    }
  }
} 
