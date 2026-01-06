import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/twilio_config.dart';
import '../service/caregiver_service.dart';

class TwilioService {
  static String get accountSid => TwilioConfig.accountSid;
  static String get authToken => TwilioConfig.authToken;
  static String get twilioPhoneNumber => TwilioConfig.twilioPhoneNumber;
  
  static String get twilioUrl => 'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json';
  
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send SMS alert to caregiver about hypertensive crisis
  static Future<bool> sendHypertensiveCrisisAlert({
    required String caregiverPhone,
    required String patientName,
    required double systolic,
    required double diastolic,
    required int consecutiveCount,
  }) async {
    // Check if SMS alerts are enabled and Twilio is configured
    if (!TwilioConfig.enableSmsAlerts || !TwilioConfig.isConfigured) {
      return false;
    }
    
    try {
      // Format phone number (remove + if present for Twilio)
      String formattedPhone = caregiverPhone.startsWith('+') 
          ? caregiverPhone 
          : '+$caregiverPhone';

      // Create SMS message (shortened for trial account)
      String message = 'EMERGENCY: $patientName BP ${systolic.toInt()}/${diastolic.toInt()} - $consecutiveCount high readings. Contact immediately!';

      // Prepare request
      final response = await http.post(
        Uri.parse(twilioUrl),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': twilioPhoneNumber,
          'To': formattedPhone,
          'Body': message,
        },
      );

      if (response.statusCode == 201) {
        // Log the SMS in Firestore for tracking
        await _logSmsAlert({
          'caregiverPhone': formattedPhone,
          'patientName': patientName,
          'systolic': systolic,
          'diastolic': diastolic,
          'consecutiveCount': consecutiveCount,
          'sentAt': FieldValue.serverTimestamp(),
          'status': 'sent',
          'twilioResponse': jsonDecode(response.body),
        });
        return true;
      } else {
        await _logSmsAlert({
          'caregiverPhone': formattedPhone,
          'patientName': patientName,
          'systolic': systolic,
          'diastolic': diastolic,
          'consecutiveCount': consecutiveCount,
          'sentAt': FieldValue.serverTimestamp(),
          'status': 'failed',
          'error': '${response.statusCode} - ${response.body}',
        });
        return false;
      }
    } catch (e) {
      await _logSmsAlert({
        'caregiverPhone': caregiverPhone,
        'patientName': patientName,
        'systolic': systolic,
        'diastolic': diastolic,
        'consecutiveCount': consecutiveCount,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'error',
        'error': e.toString(),
      });
      return false;
    }
  }

  /// Log SMS alerts in Firestore for tracking
  static Future<void> _logSmsAlert(Map<String, dynamic> alertData) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        alertData['userId'] = user.uid;
        await _firestore.collection('SmsAlerts').add(alertData);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  /// Check if SMS alerts are enabled and caregiver phone is available
  static Future<Map<String, dynamic>?> getCaregiverInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userData = await _firestore.collection('Users').doc(user.uid).get();
      if (!userData.exists) return null;

      final data = userData.data()!;
      final caregiverPhone = data['caregiverPhone'] as String?;
      final patientName = data['name'] as String?;

      if (caregiverPhone == null || caregiverPhone.isEmpty) {
        return null;
      }

      return {
        'caregiverPhone': caregiverPhone,
        'patientName': patientName ?? 'Patient',
      };
    } catch (e) {
      return null;
    }
  }

  /// Check recent blood pressure readings for consecutive hypertensive crisis
  static Future<int> checkConsecutiveHighReadings() async {
    try {
      final effectiveUserId = CaregiverService.getEffectiveUserId();
      if (effectiveUserId == null) return 0;

      // Get last 5 readings
      final readings = await _firestore
          .collection('BloodPressure')
          .where('userId', isEqualTo: effectiveUserId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (readings.docs.isEmpty) return 0;

      int consecutiveCount = 0;
      
      // Check consecutive readings from most recent
      for (var doc in readings.docs) {
        final data = doc.data();
        final systolic = (data['systolic'] as num).toDouble();
        final diastolic = (data['diastolic'] as num).toDouble();
        
        // Check if this reading is hypertensive crisis
        if (systolic > 180 || diastolic > 120) {
          consecutiveCount++;
        } else {
          // Stop counting if we hit a non-crisis reading
          break;
        }
      }

      return consecutiveCount;
    } catch (e) {
      return 0;
    }
  }


} 
