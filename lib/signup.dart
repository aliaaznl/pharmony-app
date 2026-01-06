// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phnew11/home.dart';
import 'package:phnew11/login.dart';
import 'dart:io';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController(); // Add confirm password controller
  final phoneController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true; // Add password visibility state
  bool _obscureConfirmPassword = true; // Add confirm password visibility state

  // Format Malaysian phone number to +60 format
  String formatMalaysianPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // If it starts with 60, add + prefix
    if (digitsOnly.startsWith('60')) {
      return '+$digitsOnly';
    }
    // If it starts with 0, replace with +60
    else if (digitsOnly.startsWith('0')) {
      return '+60${digitsOnly.substring(1)}';
    }
    // If it's 10 digits and doesn't start with 0, assume it's a Malaysian number
    else if (digitsOnly.length == 10) {
      return '+60$digitsOnly';
    }
    // If it's already in +60 format, return as is
    else if (phoneNumber.startsWith('+60')) {
      return phoneNumber;
    }
    // Default: add +60 prefix
    else {
      return '+60$digitsOnly';
    }
  }

  Future<bool> checkInternetConnection() async {
    try {
      final List<String> hosts = [
        'google.com',
        'firebase.google.com',
        'cloud.google.com'
      ];
      
      for (String host in hosts) {
        try {
          final result = await InternetAddress.lookup(host);
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            return true;
          }
        } catch (e) {
          continue;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void signUserUp(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Validate passwords match
      if (passwordController.text.trim() != confirmPasswordController.text.trim()) {
        if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
              backgroundColor: Color(0xFF0D1B2A),
              content: Text(
                'Passwords do not match!',
                style: TextStyle(fontSize: 18.0),
              ),
            ),
          );
        }
        setState(() {
          isLoading = false;
        });
      return;
    }

      // Check internet connection
      bool hasInternet = await checkInternetConnection();
      if (!hasInternet) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF0D1B2A),
              content: Text(
                'Unable to connect to the server. Please check your network settings.',
                style: TextStyle(fontSize: 18.0),
              ),
            ),
          );
        }
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Format phone number to +60 format before saving
      String formattedPhoneNumber = formatMalaysianPhoneNumber(phoneController.text.trim());

      // Create user account
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );

      // Update display name
      await userCredential.user?.updateDisplayName(nameController.text.trim());

      // Save user data to Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userCredential.user!.uid)
          .set({
        'name': nameController.text.trim(),
            'email': emailController.text.trim(),
        'phone': formattedPhoneNumber,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = '';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else {
        message = 'An error occurred: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D1B2A),
            content: Text(
              message,
              style: const TextStyle(fontSize: 18.0),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D1B2A),
            content: Text(
              'An unexpected error occurred: $e',
              style: const TextStyle(fontSize: 18.0),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d6b5c),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            ),
            child: Column(
              children: [
                // Green space at top (smaller)
                Container(
                  height: 80,
                  width: double.infinity,
                  color: const Color(0xFF0d6b5c),
                ),
                // White curved container with form
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 80 - MediaQuery.of(context).padding.top,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(0),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Create new',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                            const Text(
                              'Account',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LogIn(),
                                  ),
                                );
                              },
                              child: Text(
                                'Already Registered? Login Here',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color.fromARGB(255, 184, 181, 181),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Form fields
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20), // Add gap at top
                            
                            // Name field
                            TextFormField(
                              controller: nameController,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0d6b5c),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0d6b5c).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.person, color: Color(0xFF0d6b5c), size: 20),
                                ),
                                labelStyle: TextStyle(
                                  color: const Color(0xFF0d6b5c).withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0d6b5c).withOpacity(0.05),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF0d6b5c).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0d6b5c),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Email field
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0d6b5c),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0d6b5c).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.email, color: Color(0xFF0d6b5c), size: 20),
                                ),
                                labelStyle: TextStyle(
                                  color: const Color(0xFF0d6b5c).withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0d6b5c).withOpacity(0.05),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF0d6b5c).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0d6b5c),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Password field
                            TextFormField(
                              controller: passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0d6b5c),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0d6b5c).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.lock, color: Color(0xFF0d6b5c), size: 20),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: const Color(0xFF0d6b5c),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                labelStyle: TextStyle(
                                  color: const Color(0xFF0d6b5c).withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0d6b5c).withOpacity(0.05),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF0d6b5c).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0d6b5c),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 20), // Reduced gap between password fields
                            
                            // Confirm password field
                            TextFormField(
                              controller: confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0d6b5c),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0d6b5c).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.lock, color: Color(0xFF0d6b5c), size: 20),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                    color: const Color(0xFF0d6b5c),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                labelStyle: TextStyle(
                                  color: const Color(0xFF0d6b5c).withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0d6b5c).withOpacity(0.05),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF0d6b5c).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0d6b5c),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Phone number field
                            TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                                LengthLimitingTextInputFormatter(15),
                              ],
                              onChanged: (value) {
                                // Auto-format the phone number
                                if (value.isNotEmpty && !value.startsWith('+60')) {
                                  String formatted = formatMalaysianPhoneNumber(value);
                                  if (formatted != value) {
                                    phoneController.value = TextEditingValue(
                                      text: formatted,
                                      selection: TextSelection.collapsed(offset: formatted.length),
                                    );
                                  }
                                }
                              },
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0d6b5c),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Phone Number (+60)',
                                hintText: '+60 12-345 6789',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0d6b5c).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.phone, color: Color(0xFF0d6b5c), size: 20),
                                ),
                                labelStyle: TextStyle(
                                  color: const Color(0xFF0d6b5c).withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                hintStyle: TextStyle(
                                  color: const Color(0xFF0d6b5c).withOpacity(0.5),
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0d6b5c).withOpacity(0.05),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF0d6b5c).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0d6b5c),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        
                        // Sign up button
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => signUserUp(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0d6b5c),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
