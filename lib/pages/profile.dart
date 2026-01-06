import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../service/caregiver_service.dart';

// Custom clipper for the bottom arc
class BottomArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 80); // Start the curve higher
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 30, // Control point extends further down to create more upward curve
      size.width,
      size.height - 80, // End the curve higher
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _caregiverNameController = TextEditingController();
  final TextEditingController _caregiverPhoneController = TextEditingController();
  final TextEditingController _medicalNotesController = TextEditingController();
  
  DateTime? _birthDate;
  String? _patientPhotoURL; // Store patient's Google profile picture URL
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Animation controllers
  late AnimationController _fadeAnimationController;
  late AnimationController _scaleAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    
    // Add listeners for auto-save
    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _caregiverNameController.addListener(_onFieldChanged);
    _caregiverPhoneController.addListener(_onFieldChanged);
    _medicalNotesController.addListener(_onFieldChanged);
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleAnimationController, curve: Curves.elasticOut),
    );
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    
    if (effectiveUserId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('No user data available');
      }
      return;
    }

    try {
      // In caregiver mode, load patient data; otherwise load current user data
      final userIdToLoad = CaregiverService.isInCaregiverMode ? effectiveUserId : (user?.uid ?? effectiveUserId);
      final userData = await _firestore.collection('Users').doc(userIdToLoad).get();
      
      if (mounted) {
        setState(() {
          if (userData.exists) {
            final data = userData.data()!;
            _nameController.text = data['name'] ?? (CaregiverService.isInCaregiverMode ? (CaregiverService.currentPatientData?['patientName'] ?? '') : (user?.displayName ?? ''));
            _emailController.text = data['email'] ?? (CaregiverService.isInCaregiverMode ? (CaregiverService.currentPatientData?['patientEmail'] ?? '') : (user?.email ?? ''));
            _phoneController.text = data['phone'] ?? '';
            _caregiverNameController.text = data['caregiverName'] ?? '';
            _caregiverPhoneController.text = data['caregiverPhone'] ?? '';
            _medicalNotesController.text = data['medicalNotes'] ?? '';
            
            if (data['birthDate'] != null) {
              _birthDate = (data['birthDate'] as Timestamp).toDate();
            }
            
            // Store patient's Google profile picture URL if available
            if (CaregiverService.isInCaregiverMode) {
              _patientPhotoURL = data['photoURL'] ?? data['imgUrl'] ?? data['googlePhotoURL'];
            }
          } else {
            // Initialize with basic data
            if (CaregiverService.isInCaregiverMode) {
              _nameController.text = CaregiverService.currentPatientData?['patientName'] ?? '';
              _emailController.text = CaregiverService.currentPatientData?['patientEmail'] ?? '';
            } else {
              _nameController.text = user?.displayName ?? '';
              _emailController.text = user?.email ?? '';
              _createUserDocument();
            }
          }
          _isLoading = false;
        });
        
        // Start animations
        _fadeAnimationController.forward();
        _scaleAnimationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error loading profile data');
      }
    }
  }

  Future<void> _createUserDocument() async {
    final user = _auth.currentUser;
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    
    if (effectiveUserId == null) return;

    // In caregiver mode, create patient document; otherwise create current user document
    final userIdToCreate = CaregiverService.isInCaregiverMode ? effectiveUserId : (user?.uid ?? effectiveUserId);
    
    final createData = {
      'name': CaregiverService.isInCaregiverMode ? (CaregiverService.currentPatientData?['patientName'] ?? '') : (user?.displayName ?? ''),
      'email': CaregiverService.isInCaregiverMode ? (CaregiverService.currentPatientData?['patientEmail'] ?? '') : (user?.email ?? ''),
      'phone': '',
      'caregiverName': '',
      'caregiverPhone': '',
      'medicalNotes': '',
      'lastUpdated': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Add caregiver metadata if in caregiver mode
    if (CaregiverService.isInCaregiverMode && user != null) {
      createData['createdBy'] = user.uid;
      createData['createdByType'] = 'caregiver';
      createData['caregiverName'] = user.displayName ?? user.email ?? 'Unknown Caregiver';
    }

    await _firestore.collection('Users').doc(userIdToCreate).set(createData);
  }

  Timer? _saveTimer;
  void _onFieldChanged() {
    // Cancel previous timer
    _saveTimer?.cancel();
    
    // Set new timer for auto-save
    _saveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_isSaving) {
        _saveUserData();
      }
    });
  }

  Future<void> _saveUserData() async {
    final user = _auth.currentUser;
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    
    if (effectiveUserId == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      // In caregiver mode, save to patient's document; otherwise save to current user's document
      final userIdToSave = CaregiverService.isInCaregiverMode ? effectiveUserId : (user?.uid ?? effectiveUserId);
      
      final saveData = {
        'name': _nameController.text.trim(),
        'email': CaregiverService.isInCaregiverMode ? (CaregiverService.currentPatientData?['patientEmail'] ?? '') : (user?.email ?? ''),
        'phone': _phoneController.text.trim(),
        'caregiverName': _caregiverNameController.text.trim(),
        'caregiverPhone': _caregiverPhoneController.text.trim(),
        'medicalNotes': _medicalNotesController.text.trim(),
        'birthDate': _birthDate != null ? Timestamp.fromDate(_birthDate!) : null,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Add caregiver metadata if in caregiver mode
      if (CaregiverService.isInCaregiverMode && user != null) {
        saveData['lastUpdatedBy'] = user.uid;
        saveData['lastUpdatedByType'] = 'caregiver';
        saveData['caregiverName'] = user.displayName ?? user.email ?? 'Unknown Caregiver';
      }

      await _firestore.collection('Users').doc(userIdToSave).set(saveData, SetOptions(merge: true));
    } catch (e) {
      _showErrorSnackBar('Error saving profile');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Get profile image based on current mode (caregiver or normal user)
  ImageProvider? _getProfileImage() {
    final user = _auth.currentUser;
    
    if (CaregiverService.isInCaregiverMode) {
      // In caregiver mode, use patient's Google profile picture if available
      return _patientPhotoURL != null ? NetworkImage(_patientPhotoURL!) : null;
    } else {
      // In normal mode, use current user's photo URL
      return user?.photoURL != null ? NetworkImage(user!.photoURL!) : null;
    }
  }







  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now().subtract(Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
      _onFieldChanged();
    }
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

  Widget _buildGlowingCard({required Widget child, double? height}) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, _) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: colorScheme.surface,
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildFuturisticTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines ?? 1,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
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
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        actions: [
          if (_isSaving)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: _isLoading
            ? Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading your profile...',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Top Arc Section with Gradient
                    ClipPath(
                      clipper: BottomArcClipper(),
                      child: Container(
                        height: 360, // Increased height further to accommodate all elements
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withOpacity(0.8),
                              colorScheme.primary.withOpacity(0.6),
                            ],
                          ),
                        ),
                      child: Stack(
                        children: [
                          // Profile Picture positioned to avoid title overlap
                          Positioned(
                            top: 100, // Keep this to avoid title overlap
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 55,
                                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                                  backgroundImage: _getProfileImage(),
                                  child: _getProfileImage() == null
                                      ? Icon(
                                          Icons.person,
                                          size: 50,
                                          color: colorScheme.primary,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          // Name and Email positioned with proper spacing from profile picture
                          Positioned(
                            bottom: 80, // Moved up from 60 to create more space from profile picture
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Text(
                                  _nameController.text.isNotEmpty ? _nameController.text : 'Your Name',
                                  style: TextStyle(
                                    fontSize: 22, // Slightly smaller font
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2, // Allow up to 2 lines for long names
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 6), // Reduced spacing
                                Text(
                                  _emailController.text,
                                  style: TextStyle(
                                    fontSize: 14, // Slightly smaller font
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                    
                    // White Content Area
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 20),
                              
                              // Profile Details Section
                              Text(
                                'Profile Details',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 20),
                              
                              _buildFuturisticTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                icon: Icons.person,
                              ),
                              
                              _buildFuturisticTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                icon: Icons.email,
                                readOnly: true,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              
                              _buildFuturisticTextField(
                                controller: TextEditingController(
                                  text: _birthDate != null
                                      ? DateFormat('dd/MM/yyyy').format(_birthDate!)
                                      : '',
                                ),
                                label: 'Birth Date',
                                icon: Icons.cake,
                                readOnly: true,
                                onTap: _selectBirthDate,
                              ),
                              
                              _buildFuturisticTextField(
                                controller: _phoneController,
                                label: 'Phone Number',
                                icon: Icons.phone,
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
                              ),
                              
                              SizedBox(height: 30),
                              
                              // Emergency Contacts Section
                              Text(
                                'Emergency Contacts',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 20),
                              
                              _buildFuturisticTextField(
                                controller: _caregiverNameController,
                                label: 'Caregiver Name',
                                icon: Icons.person_add,
                              ),
                              
                              _buildFuturisticTextField(
                                controller: _caregiverPhoneController,
                                label: 'Caregiver Phone',
                                icon: Icons.phone_in_talk,
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
                              ),
                              
                              SizedBox(height: 30),
                              
                              // Medical Information Section
                              Text(
                                'Medical Information',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 20),
                              
                              _buildFuturisticTextField(
                                controller: _medicalNotesController,
                                label: 'Medical Notes / Allergies',
                                icon: Icons.note_add,
                                maxLines: 4,
                              ),
                              
                              SizedBox(height: 30),
                              
                              SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _fadeAnimationController.dispose();
    _scaleAnimationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _caregiverNameController.dispose();
    _caregiverPhoneController.dispose();
    _medicalNotesController.dispose();
    super.dispose();
  }
}