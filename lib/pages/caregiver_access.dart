import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../service/caregiver_service.dart';
import 'dash.dart';
import '../home.dart';

class CaregiverAccess extends StatefulWidget {
  const CaregiverAccess({super.key});

  @override
  State<CaregiverAccess> createState() => _CaregiverAccessState();
}

class _CaregiverAccessState extends State<CaregiverAccess> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final bool _isLoading = false;
  bool _isAccessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Register device token for notifications
    CaregiverService.registerDeviceToken();
  }

  String _formatPhoneNumber(String value) {
    // Remove all non-digits
    String digits = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // If starts with 60, keep it, otherwise add it
    if (!digits.startsWith('60')) {
      if (digits.startsWith('0')) {
        digits = '60${digits.substring(1)}';
      } else if (digits.isNotEmpty) {
        digits = '60$digits';
      }
    }
    
    // Return formatted without spaces
    return digits.isNotEmpty ? '+$digits' : '';
  }

  Future<void> _accessPatientData() async {
    print('--- _accessPatientData START ---');
    if (_phoneController.text.trim().isEmpty) {
      if (mounted) setState(() => _errorMessage = 'Please enter the patient\'s phone number');
      print('Error: phone number empty');
      return;
    }
    if (_codeController.text.trim().length != 6) {
      if (mounted) setState(() => _errorMessage = 'Please enter a valid 6-digit code');
      print('Error: code not 6 digits');
      return;
    }
    if (mounted) {
      setState(() {
        _isAccessing = true;
        _errorMessage = null;
      });
    }
    try {
      final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());
      final code = _codeController.text.trim();
      print('Looking for patient with phone: $formattedPhone');
      print('Access code entered: $code');
      QuerySnapshot? patientQuery;
      try {
        patientQuery = await _firestore
            .collection('Users')
            .where('phone', isEqualTo: formattedPhone)
            .get();
      } catch (e) {
        print('Firestore error (Users query): $e');
        if (mounted) {
          setState(() {
          _errorMessage = 'Error finding patient: $e';
          _isAccessing = false;
        });
        }
        return;
      }
      print('Found ${patientQuery.docs.length} patient(s) with this phone number');
      if (patientQuery.docs.isEmpty) {
        if (mounted) {
          setState(() {
          _errorMessage = 'No patient found with this phone number';
          _isAccessing = false;
        });
        }
        print('No patient found');
        return;
      }
      final patientDoc = patientQuery.docs.first;
      final patientId = patientDoc.id;
      Map<String, dynamic> patientData = {};
      try {
        final data = patientDoc.data();
        if (data is Map<String, dynamic>) {
          patientData = data;
        } else {
          throw Exception('Patient data is not a map');
        }
      } catch (e) {
        print('Error reading patient data: $e');
        if (mounted) {
          setState(() {
          _errorMessage = 'Patient data is corrupted.';
          _isAccessing = false;
        });
        }
        return;
      }
      print('Found patient: ${patientData['name'] ?? 'Unknown'} (ID: $patientId)');
      QuerySnapshot? accessCodeQuery;
      try {
        accessCodeQuery = await _firestore
            .collection('PatientAccessCodes')
            .where('patientId', isEqualTo: patientId)
            .where('code', isEqualTo: code)
            .where('isActive', isEqualTo: true)
            .get();
      } catch (e) {
        print('Firestore error (PatientAccessCodes query): $e');
        if (mounted) {
          setState(() {
          _errorMessage = 'Error verifying access code: $e';
          _isAccessing = false;
        });
        }
        return;
      }
      print('Found ${accessCodeQuery.docs.length} matching access code(s)');
      if (accessCodeQuery.docs.isEmpty) {
        if (mounted) {
          setState(() {
          _errorMessage = 'Invalid access code';
          _isAccessing = false;
        });
        }
        print('Invalid access code');
        return;
      }
      final accessCodeDoc = accessCodeQuery.docs.first;
      Map<String, dynamic> accessCodeData = {};
      try {
        final data = accessCodeDoc.data();
        if (data is Map<String, dynamic>) {
          accessCodeData = data;
        } else {
          throw Exception('Access code data is not a map');
        }
      } catch (e) {
        print('Error reading access code data: $e');
        if (mounted) {
          setState(() {
          _errorMessage = 'Access code data is corrupted.';
          _isAccessing = false;
        });
        }
        return;
      }
      DateTime? expiresAt;
      try {
        final expiresAtRaw = accessCodeData['expiresAt'];
        if (expiresAtRaw is Timestamp) {
          expiresAt = expiresAtRaw.toDate();
        } else if (expiresAtRaw is DateTime) {
          expiresAt = expiresAtRaw;
        } else {
          throw Exception('expiresAt is not a Timestamp or DateTime');
        }
      } catch (e) {
        print('Error reading expiresAt: $e');
        if (mounted) {
          setState(() {
          _errorMessage = 'Access code expiry is invalid.';
          _isAccessing = false;
        });
        }
        return;
      }
      if (DateTime.now().isAfter(expiresAt)) {
        if (mounted) {
          setState(() {
          _errorMessage = 'Access code has expired';
          _isAccessing = false;
        });
        }
        print('Access code expired');
        return;
      }
      try {
        await CaregiverService.createTemporaryCaregiverSession(
          patientId: patientId,
          patientName: patientData['name'] as String? ?? 'Unknown Patient',
          patientPhone: formattedPhone,
          accessCodeId: accessCodeDoc.id,
        );
      } catch (e) {
        print('Error creating temporary caregiver session: $e');
        if (mounted) {
          setState(() {
          _errorMessage = 'Could not create caregiver session: $e';
          _isAccessing = false;
        });
        }
        return;
      }
      try {
        await CaregiverService.switchToPatientViaPhone(
          patientId, 
          patientName: patientData['name'] as String? ?? 'Patient',
          patientEmail: patientData['email'] as String? ?? '',
        );
      } catch (e) {
        print('Error switching to patient: $e');
        if (mounted) {
          setState(() {
          _errorMessage = 'Could not switch to patient: $e';
          _isAccessing = false;
        });
        }
        return;
      }
      if (mounted) {
        try {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const Home(),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Now managing ${patientData['name'] ?? 'Patient'}'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          print('Error navigating to dashboard: $e');
        }
      }
    } on FirebaseException catch (e) {
      print('FirebaseException: $e');
      if (mounted) {
        setState(() {
        _errorMessage = 'You do not have permission to access this data. Please log in.';
        _isAccessing = false;
      });
      }
    } catch (e) {
      print('Unknown error: $e');
      if (mounted) {
        setState(() {
        _errorMessage = 'Error accessing patient data: $e';
        _isAccessing = false;
      });
      }
    }
    print('--- _accessPatientData END ---');
  }

  void _showLoginPrompt(String patientId, Map<String, dynamic> patientData, String phone, String accessCodeId) {
    if (!mounted) {
      print('Context not mounted, cannot show login prompt');
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.login, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text('Login Required'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To access patient data, you need to be logged in.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'Patient: ${patientData['name'] ?? 'Unknown'}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            Text(
              'Phone: $phone',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) setState(() => _isAccessing = false);
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToLogin(patientId, patientData, phone, accessCodeId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Login'),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin(String patientId, Map<String, dynamic> patientData, String phone, String accessCodeId) {
    try {
      // Store the access data temporarily (you might want to use a more robust solution)
      // For now, we'll pass it as arguments to the login page
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      
      // After successful login, the user should be redirected back to complete the access
      // This would require additional implementation in the login flow
    } catch (e) {
      print('Error navigating to login: $e');
      if (mounted) {
        setState(() => _isAccessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error navigating to login: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Caregiver Access',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Header Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.medical_services,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Access Patient Data',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the patient\'s phone number and 6-digit access code to manage their medications and health data.',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Form Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Phone Number Field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final formatted = _formatPhoneNumber(newValue.text);
                            return TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          }),
                        ],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Patient Phone Number',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.phone, color: colorScheme.primary, size: 20),
                          ),
                          labelStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: colorScheme.surface.withOpacity(0.8),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colorScheme.outline.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Access Code Field
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: '6-Digit Access Code',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.lock, color: colorScheme.primary, size: 20),
                          ),
                          labelStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: colorScheme.surface.withOpacity(0.8),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colorScheme.outline.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                      
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Access Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isAccessing ? null : _accessPatientData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          child: _isAccessing
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Accessing...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Access Patient Data',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Info Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'How to get access?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ask the patient to generate an access code from their profile page. The code will be valid for 24 hours.',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }
} 