import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:math';

class CaregiverService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  // Initialize auth state listener to automatically reset caregiver mode on sign out
  static void _initializeAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        // User signed out, reset caregiver mode
        resetCaregiverMode();
        print('🔄 User signed out - automatically reset caregiver mode');
      }
    });
  }
  
  // Static constructor to initialize the auth listener
  static bool _isInitialized = false;
  static void initialize() {
    if (!_isInitialized) {
      _initializeAuthListener();
      _isInitialized = true;
      print('✅ CaregiverService initialized with auth listener');
    }
  }

  // Generate a 6-digit invitation code
  static String _generateInvitationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Register device token for push notifications
  static Future<void> registerDeviceToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      // Store device token in user's document
      await _firestore.collection('Users').doc(user.uid).set({
        'deviceToken': token,
        'lastActive': FieldValue.serverTimestamp(),
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
      }, SetOptions(merge: true));

      print('✅ Device token registered: $token');
    } catch (e) {
      print('❌ Error registering device token: $e');
    }
  }

  /// Patient creates invitation code for caregiver
  static Future<String> createCaregiverInvitation({
    required String patientName,
    String? patientPhoneNumber,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final invitationCode = _generateInvitationCode();
      final expiresAt = DateTime.now().add(const Duration(hours: 24)); // 24 hour expiry

      // Create invitation document
      await _firestore.collection('CaregiverInvitations').doc(invitationCode).set({
        'patientId': user.uid,
        'patientName': patientName,
        'patientEmail': user.email,
        'patientPhoneNumber': patientPhoneNumber,
        'invitationCode': invitationCode,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isUsed': false,
        'createdBy': user.uid,
      });

      print('✅ Caregiver invitation created: $invitationCode');
      return invitationCode;
    } catch (e) {
      print('❌ Error creating caregiver invitation: $e');
      rethrow;
    }
  }

  /// Caregiver accepts invitation using code
  static Future<bool> acceptCaregiverInvitation(String invitationCode) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get invitation document
      final invitationDoc = await _firestore
          .collection('CaregiverInvitations')
          .doc(invitationCode)
          .get();

      if (!invitationDoc.exists) {
        throw Exception('Invalid invitation code');
      }

      final invitation = invitationDoc.data()!;
      
      // Check if invitation is still valid
      if (invitation['isUsed'] == true) {
        throw Exception('Invitation code has already been used');
      }

      final expiresAt = (invitation['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('Invitation code has expired');
      }

      final patientId = invitation['patientId'] as String;

      // Create caregiver-patient relationship
      await _firestore.collection('CaregiverPatients').add({
        'caregiverId': user.uid,
        'patientId': patientId,
        'caregiverName': user.displayName ?? user.email,
        'caregiverEmail': user.email,
        'patientName': invitation['patientName'],
        'patientEmail': invitation['patientEmail'],
        'relationshipType': 'caregiver', // Could be 'family', 'nurse', etc.
        'permissions': [
          'view_medications',
          'add_medications',
          'edit_medications',
          'log_medication_intake',
          'view_health_metrics',
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Mark invitation as used
      await invitationDoc.reference.update({
        'isUsed': true,
        'usedBy': user.uid,
        'usedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Caregiver invitation accepted successfully');
      return true;
    } catch (e) {
      print('❌ Error accepting caregiver invitation: $e');
      rethrow;
    }
  }

  /// Get patients that the current user is a caregiver for
  static Stream<List<Map<String, dynamic>>> getCaregiverPatients() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<Map<String, dynamic>>[]);
      }
      
      return _firestore
          .collection('CaregiverPatients')
          .where('caregiverId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList());
    });
  }

  /// Get caregivers for the current patient
  static Stream<List<Map<String, dynamic>>> getPatientCaregivers() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<Map<String, dynamic>>[]);
      }
      
      return _firestore
          .collection('CaregiverPatients')
          .where('patientId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList());
    });
  }

  /// Switch to managing a specific patient (for caregiver)
  static Future<void> switchToPatient(String patientId) async {
    try {
      final user = _auth.currentUser;
      
      // If user is authenticated, verify caregiver has permission to manage this patient
      if (user != null) {
        final relationship = await _firestore
            .collection('CaregiverPatients')
            .where('caregiverId', isEqualTo: user.uid)
            .where('patientId', isEqualTo: patientId)
            .where('isActive', isEqualTo: true)
            .get();

        if (relationship.docs.isEmpty) {
          throw Exception('You do not have permission to manage this patient');
        }
      }

      // Store current patient context in local storage or state management
      // For simplicity, we'll use a static variable, but in production use proper state management
      _currentPatientId = patientId;
      _isInCaregiverMode = true;
      
      print('✅ Switched to managing patient: $patientId');
    } catch (e) {
      print('❌ Error switching to patient: $e');
      rethrow;
    }
  }

  /// Switch to managing a patient via phone-based access (no pre-existing relationship required)
  static Future<void> switchToPatientViaPhone(String patientId, {String? patientName, String? patientEmail}) async {
    try {
      // Store current patient context for phone-based access
      _currentPatientId = patientId;
      _isInCaregiverMode = true;
      _isPhoneBasedAccess = true; // Track that this is phone-based access
      
      // Store patient data for UI display
      if (patientName != null || patientEmail != null) {
        _currentPatientData = {
          'patientId': patientId,
          'patientName': patientName ?? 'Patient',
          'patientEmail': patientEmail ?? '',
        };
      }
      
      print('✅ Switched to managing patient via phone access: $patientId');
    } catch (e) {
      print('❌ Error switching to patient via phone: $e');
      rethrow;
    }
  }

  /// Switch back to own account
  static void switchToOwnAccount() {
    _currentPatientId = null;
    _isInCaregiverMode = false;
    _isPhoneBasedAccess = false;
    _currentPatientData = null;
    print('✅ Switched back to own account');
  }

  /// Get current patient ID (if in caregiver mode)
  static String? _currentPatientId;
  static bool _isInCaregiverMode = false;
  static bool _isPhoneBasedAccess = false; // Track if access is via phone/code
  static Map<String, dynamic>? _currentPatientData; // Store patient data for UI

  static String? get currentPatientId => _currentPatientId;
  static bool get isInCaregiverMode => _isInCaregiverMode;
  static bool get isPhoneBasedAccess => _isPhoneBasedAccess;
  static Map<String, dynamic>? get currentPatientData => _currentPatientData;

  /// Reset caregiver mode to ensure normal user login
  static void resetCaregiverMode() {
    _currentPatientId = null;
    _isInCaregiverMode = false;
    _isPhoneBasedAccess = false;
    _currentPatientData = null;
    print('✅ Caregiver mode reset - normal user mode');
  }

  /// Get the effective user ID (patient if in caregiver mode, otherwise current user)
  static String? getEffectiveUserId() {
    if (_isInCaregiverMode && _currentPatientId != null) {
      return _currentPatientId;
    }
    return _auth.currentUser?.uid;
  }

  /// Get patient's device token for sending notifications
  static Future<String?> getPatientDeviceToken(String patientId) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(patientId).get();
      if (userDoc.exists) {
        return userDoc.data()?['deviceToken'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Error getting patient device token: $e');
      return null;
    }
  }

  /// Send targeted notification to patient's device only
  static Future<void> sendNotificationToPatient({
    required String patientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final patientDeviceToken = await getPatientDeviceToken(patientId);
      
      if (patientDeviceToken == null) {
        print('⚠️ No device token found for patient: $patientId');
        return;
      }

      // In a real app, you would send this via Firebase Cloud Functions or your backend
      // For now, we'll just log it
      print('📱 Sending notification to patient device: $patientDeviceToken');
      print('Title: $title');
      print('Body: $body');
      print('Data: $data');

      // TODO: Implement actual FCM sending via Cloud Functions or backend
      // This would be done server-side to avoid exposing FCM server key
      
    } catch (e) {
      print('❌ Error sending notification to patient: $e');
    }
  }

  /// Remove caregiver relationship
  static Future<void> removeCaregiverRelationship(String relationshipId) async {
    try {
      await _firestore.collection('CaregiverPatients').doc(relationshipId).update({
        'isActive': false,
        'removedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Caregiver relationship removed');
    } catch (e) {
      print('❌ Error removing caregiver relationship: $e');
      rethrow;
    }
  }

  /// Check if current user has permission to manage a patient
  static Future<bool> hasPatientPermission(String patientId, String permission) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // If it's the patient themselves, they have all permissions
      if (user.uid == patientId) return true;

      // Check caregiver permissions
      final relationship = await _firestore
          .collection('CaregiverPatients')
          .where('caregiverId', isEqualTo: user.uid)
          .where('patientId', isEqualTo: patientId)
          .where('isActive', isEqualTo: true)
          .get();

      if (relationship.docs.isEmpty) return false;

      final permissions = relationship.docs.first.data()['permissions'] as List<dynamic>?;
      return permissions?.contains(permission) ?? false;
    } catch (e) {
      print('❌ Error checking patient permission: $e');
      return false;
    }
  }

  /// Get patient details for caregiver
  static Future<Map<String, dynamic>?> getPatientDetails(String patientId) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(patientId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting patient details: $e');
      return null;
    }
  }

  /// Generate access code for patient (to be used by caregivers)
  static Future<String> generatePatientAccessCode() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user's phone number
      final userDoc = await _firestore.collection('Users').doc(user.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final phoneNumber = userData['phone'] as String?;
      
      if (phoneNumber == null || phoneNumber.isEmpty) {
        throw Exception('Phone number not found in profile. Please add your phone number first.');
      }

      // Generate 6-digit code
      final accessCode = _generateInvitationCode();
      final expiresAt = DateTime.now().add(const Duration(hours: 24)); // 24 hour expiry

      // Deactivate any existing active codes for this patient
      await _firestore
          .collection('PatientAccessCodes')
          .where('patientId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.update({'isActive': false});
        }
      });

      // Create new access code
      await _firestore.collection('PatientAccessCodes').add({
        'patientId': user.uid,
        'patientName': userData['name'] ?? user.displayName ?? 'Unknown',
        'patientPhone': phoneNumber,
        'code': accessCode,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isActive': true,
        'createdBy': user.uid,
      });

      print('✅ Patient access code generated: $accessCode');
      return accessCode;
    } catch (e) {
      print('❌ Error generating patient access code: $e');
      rethrow;
    }
  }

  /// Create temporary caregiver session for phone-based access
  static Future<void> createTemporaryCaregiverSession({
    required String patientId,
    required String patientName,
    required String patientPhone,
    required String accessCodeId,
  }) async {
    try {
      final user = _auth.currentUser;
      
      // Create temporary session record
      await _firestore.collection('TemporaryCaregiverSessions').add({
        'caregiverId': user?.uid ?? 'anonymous',
        'caregiverName': user?.displayName ?? user?.email ?? 'Anonymous Caregiver',
        'caregiverEmail': user?.email ?? 'anonymous@caregiver.com',
        'patientId': patientId,
        'patientName': patientName,
        'patientPhone': patientPhone,
        'accessCodeId': accessCodeId,
        'sessionStartedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'accessMethod': user == null ? 'phone_code' : 'authenticated',
      });

      print('✅ Temporary caregiver session created');
    } catch (e) {
      print('❌ Error creating temporary caregiver session: $e');
      rethrow;
    }
  }

  /// Get active temporary sessions for current user
  static Stream<List<Map<String, dynamic>>> getTemporarySessions() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('TemporaryCaregiverSessions')
        .where('caregiverId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .orderBy('sessionStartedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// End temporary caregiver session
  static Future<void> endTemporarySession(String sessionId) async {
    try {
      await _firestore.collection('TemporaryCaregiverSessions').doc(sessionId).update({
        'isActive': false,
        'sessionEndedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Temporary session ended');
    } catch (e) {
      print('❌ Error ending temporary session: $e');
      rethrow;
    }
  }

  /// Create medication on behalf of patient (caregiver function)
  static Future<void> createMedicationForPatient({
    required String patientId,
    required Map<String, dynamic> medicationData,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Add caregiver metadata
      medicationData['userId'] = patientId; // Store under patient's ID
      medicationData['createdBy'] = user.uid; // Track who created it
      medicationData['createdByType'] = 'caregiver';
      medicationData['caregiverName'] = user.displayName ?? user.email;
      medicationData['createdAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('Medications').add(medicationData);

      // Send notification to patient's device about new medication
      await sendNotificationToPatient(
        patientId: patientId,
        title: 'New Medication Added',
        body: 'Your caregiver added ${medicationData['medicationName']} to your schedule',
        data: {
          'type': 'medication_added',
          'medicationName': medicationData['medicationName'],
          'caregiverName': user.displayName ?? user.email,
        },
      );

      print('✅ Medication created for patient by caregiver');
    } catch (e) {
      print('❌ Error creating medication for patient: $e');
      rethrow;
    }
  }

  /// Log medication intake on behalf of patient (caregiver function)
  static Future<void> logMedicationIntakeForPatient({
    required String patientId,
    required String medicationId,
    required String status, // 'taken', 'skipped', 'snoozed'
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _firestore.collection('MedicationStatus').add({
        'medicationId': medicationId,
        'userId': patientId, // Patient's ID
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'loggedBy': user.uid, // Caregiver's ID
        'loggedByType': 'caregiver',
        'caregiverName': user.displayName ?? user.email,
        'actionTime': DateTime.now(),
      });

      print('✅ Medication intake logged for patient by caregiver');
    } catch (e) {
      print('❌ Error logging medication intake for patient: $e');
      rethrow;
    }
  }
} 