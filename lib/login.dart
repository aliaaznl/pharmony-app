// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:phnew11/forgot_password.dart';
import 'package:phnew11/home.dart';
import 'package:phnew11/signup.dart';
import 'package:phnew11/pages/caregiver_dashboard.dart';
import 'package:phnew11/pages/caregiver_access.dart';
import 'package:phnew11/service/caregiver_service.dart';
import 'dart:io';

class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true; // Add password visibility state
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<bool> checkInternetConnection() async {
    try {
      // Try multiple reliable hosts
      final List<String> hosts = [
        'google.com',
        'firebase.google.com',
        'cloud.google.com'
      ];
      
      for (String host in hosts) {
        try {
          final result = await InternetAddress.lookup(host);
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            print('Successfully connected to $host');
            return true;
          }
        } catch (e) {
          print('Failed to connect to $host: $e');
          continue;
        }
      }
      return false;
    } catch (e) {
      print('Error checking internet connection: $e');
      return false;
    }
  }

  void signUserIn(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Check internet connection first
      bool hasInternet = await checkInternetConnection();
      print('Internet connection check result: $hasInternet');
      
      if (!hasInternet) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF0d6b5c),
              content: Text(
                'Unable to connect to the server. Please check your network settings or try again later.',
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

      print('Attempting to sign in with email: ${emailController.text.trim()}');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      print('Sign in successful');

      if (mounted) {
        await _checkCaregiverAndNavigate();
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      String message = '';
      if (e.code == 'user-not-found') {
        message = 'No User Found for that Email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong Password Provided by User';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error. Please check your internet connection and try again.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many failed attempts. Please try again later.';
      } else {
        message = 'An error occurred: ${e.message}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0d6b5c),
            content: Text(
              message,
              style: const TextStyle(fontSize: 18.0),
            ),
          ),
        );
      }
    } catch (e) {
      print('Unexpected error during sign in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0d6b5c),
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

  Future<void> _showCaregiverLoginInfo() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.medical_services, color: Color(0xFF0d6b5c)),
            SizedBox(width: 8),
            Text('Caregiver Access'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'As a caregiver, you can:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Help manage patient medications'),
            Text('• Log medication intake remotely'),
            Text('• View patient health metrics'),
            Text('• Set medication reminders'),
            SizedBox(height: 16),
            Text(
              'To get started:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Create your own account'),
            Text('2. Get an invitation code from your patient'),
            Text('3. Connect and start helping!'),
            SizedBox(height: 16),
            Text(
              'Medication alarms will only ring on the patient\'s phone, not yours.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Show caregiver-specific login UI
              _showCaregiverLogin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0d6b5c),
            ),
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCaregiverLogin() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Caregiver Login'),
        content: const Text(
          'Please sign in with your caregiver account using the regular login form.\n\n'
          'After logging in, you can access the Caregiver Dashboard to manage your patients.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0d6b5c),
            ),
            child: const Text('Got it!', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkCaregiverAndNavigate() async {
    try {
      // Check if user has any patients they're caring for
      final caregiverPatients = await CaregiverService.getCaregiverPatients().first;
      
      if (caregiverPatients.isNotEmpty) {
        // User is a caregiver, navigate to caregiver dashboard
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CaregiverDashboard()),
          );
        }
      } else {
        // Regular user, navigate to home
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
          );
        }
      }
    } catch (e) {
      // If there's an error checking caregiver status, default to home
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
      }
    }
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Check internet connection first
      bool hasInternet = await checkInternetConnection();
      if (!hasInternet) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF0d6b5c),
              content: Text(
                'Unable to connect to the server. Please check your network settings or try again later.',
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

      // Sign out first to clear any cached accounts and force account chooser
      await _googleSignIn.signOut();
      print('🔄 Cleared cached Google accounts to show account chooser');

      // Trigger the authentication flow - this will now show account chooser
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in flow
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        await _checkCaregiverAndNavigate();
      }
    } catch (e) {
      print('Error during Google sign in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0d6b5c),
            content: Text(
              'Error signing in with Google: $e',
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top section with logo
            Container(
              height: MediaQuery.of(context).size.height * 0.22,
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(18),
              child: Center(
                child: Image.asset(
                  'lib/images/PHARMONY.png',
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Bottom curved container
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF0d6b5c),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(0),
                    topRight: Radius.circular(50),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 10, 30, 10),
                  child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      const SizedBox(height: 20), // Add gap at top
                      
                      // Title
                      const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to continue.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 18),
                      
                      // Email field
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.email, color: Colors.white, size: 20),
                          ),
                          labelStyle: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                          color: Colors.white,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 10), // Reduced gap between email and password
                      
                      // Password field
                      TextFormField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.lock, color: Colors.white, size: 20),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          labelStyle: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                          color: Colors.white,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPassword(),
                            ),
                          );
                        },
                          child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : () => signUserIn(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(color: Color(0xFF0d6b5c))
                              : const Text(
                                  'Log In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0d6b5c),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Caregiver Access Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CaregiverAccess(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.medical_services, color: Colors.white, size: 20),
                          label: const Text(
                            'Caregiver Access',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Google sign in
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(
                              color: Colors.white,
                                  thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                              color: Colors.white,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                      const SizedBox(height: 12),
                      
                          Center(
                            child: InkWell(
                              onTap: () => signInWithGoogle(context),
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey.shade300),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(11.0),
                                  child: Image.asset(
                                    'lib/images/google.png',
                                    height: 30,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      const SizedBox(height: 15),
                      
                      // Sign up link
                      Center(
                        child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUp(),
                          ),
                        );
                      },
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                              children: const [
                                TextSpan(
                                  text: 'Sign Up',
                        style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
