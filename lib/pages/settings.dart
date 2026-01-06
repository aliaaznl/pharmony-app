import 'package:flutter/material.dart';
import 'package:phnew11/pages/medication_wizard.dart';
import 'package:phnew11/pages/metrics.dart';
import 'package:phnew11/pages/app_settings.dart';
import 'package:phnew11/pages/appointments.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phnew11/pages/profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../service/caregiver_service.dart';
import 'package:flutter/services.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0d6b5c),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Manage'),
            _buildSettingsCard(
              context,
              'Medications',
              Icons.medication,
              'Manage your medications and schedules',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MedicationWizard(selectedDate: DateTime.now()),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildSettingsCard(
              context,
              'Health Trackers',
              Icons.monitor_heart,
              'Configure health monitoring settings',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Metrics(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildSettingsCard(
              context,
              'Appointments',
              Icons.calendar_today,
              'Manage your medical appointments',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppointmentsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildSettingsCard(
              context,
              'Reports',
              Icons.assessment,
              'View and manage your health reports',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReportsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Settings'),
            _buildSettingsCard(
              context,
              'App Settings',
              Icons.settings,
              'Configure app preferences and notifications',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppSettingsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildSettingsCard(
              context,
              'Profile',
              Icons.person,
              'Manage your account and personal information',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Caregiver Access'),
            CaregiverAccessSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: const Color(0xFF0d6b5c),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CaregiverAccessSection extends StatefulWidget {
  const CaregiverAccessSection({super.key});

  @override
  State<CaregiverAccessSection> createState() => _CaregiverAccessSectionState();
}

class _CaregiverAccessSectionState extends State<CaregiverAccessSection> {
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
  }

  Future<void> _loadUserPhone() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userData = await _firestore.collection('Users').doc(user.uid).get();
        if (userData.exists) {
          final phone = userData.data()?['phone'] ?? '';
          _phoneController.text = phone;
        }
      } catch (e) {
        print('Error loading user phone: $e');
      }
    }
  }

  String _formatPhoneNumber(String value) {
    String digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (!digits.startsWith('60')) {
      if (digits.startsWith('0')) {
        digits = '60${digits.substring(1)}';
      } else if (digits.isNotEmpty) {
        digits = '60$digits';
      }
    }
    return digits.isNotEmpty ? '+$digits' : '';
  }

  Future<void> _generateAccessCode() async {
    print('🔍 Starting access code generation...');
    
    if (_auth.currentUser == null) {
      print('❌ User not logged in');
      _showErrorSnackBar('Please log in to generate access codes');
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      print('❌ Phone number is empty');
      _showErrorSnackBar('Please add your phone number first');
      return;
    }

    print('📱 Phone number: ${_phoneController.text.trim()}');
    
    if (!mounted) {
      print('❌ Widget not mounted, cannot proceed');
      return;
    }
    
    setState(() => _isSaving = true);

    try {
      print('🔄 Calling CaregiverService.generatePatientAccessCode()...');
      final code = await CaregiverService.generatePatientAccessCode();
      print('✅ Access code generated: $code');
      
      // Add a small delay to ensure UI is ready
      await Future.delayed(Duration(milliseconds: 100));
      
      if (mounted) {
        print('🎯 Widget is mounted, showing dialog...');
        try {
          _showAccessCodeDialog(code);
        } catch (dialogError) {
          print('❌ Error in dialog creation: $dialogError');
          _showErrorSnackBar('Access code generated: $code. Please note it down!');
        }
      } else {
        print('❌ Widget not mounted, cannot show dialog');
        _showErrorSnackBar('Access code generated: $code. Please note it down!');
      }
    } catch (e) {
      print('❌ Error generating access code: $e');
      _showErrorSnackBar('Error generating access code: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAccessCodeDialog(String code) {
    print('🎭 Showing access code dialog for code: $code');
    
    // Check if widget is still mounted and context is valid
    if (!mounted) {
      print('❌ Widget not mounted, cannot show dialog');
      _showErrorSnackBar('Access code generated: $code. Please note it down!');
      return;
    }
    
    try {
      // Use a simpler dialog structure to avoid potential issues
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.security, color: Theme.of(dialogContext).colorScheme.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Access Code Generated',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share this code with your caregiver:',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Text(
                      code,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phone Number: ${_phoneController.text}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'This code will expire in 24 hours.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _shareAccessCode(code);
              },
              icon: Icon(Icons.share),
              label: Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error showing access code dialog: $e');
      // Fallback: show a simple dialog with minimal complexity
      try {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Access Code Generated'),
            content: Text('Your access code is: $code\n\nPlease share this with your caregiver.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      } catch (fallbackError) {
        print('❌ Even fallback dialog failed: $fallbackError');
        _showErrorSnackBar('Access code generated: $code. Please note it down!');
      }
    }
  }

  void _shareAccessCode(String code) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Access code copied to clipboard'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

    void _viewActiveCodes() {
    if (_auth.currentUser == null) {
      _showErrorSnackBar('Please log in to view access codes');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Active Access Codes'),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: FutureBuilder<QuerySnapshot>(
            future: _firestore
                .collection('PatientAccessCodes')
                .where('patientId', isEqualTo: _auth.currentUser?.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.error, color: Colors.red, size: 32),
                      SizedBox(height: 8),
                      Text('Error loading codes', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Please try again later', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                );
              }

              final allCodes = snapshot.data?.docs ?? [];
              final codes = <QueryDocumentSnapshot>[];
              for (var doc in allCodes) {
                try {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['isActive'] == true) {
                    codes.add(doc);
                  }
                } catch (_) {}
              }

              if (codes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.grey, size: 32),
                      const SizedBox(height: 8),
                      const Text('No active access codes found', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Generate a new code to share with caregivers', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            await _generateAccessCode();
                            Future.delayed(const Duration(milliseconds: 500), () {
                              _viewActiveCodes();
                            });
                          } catch (e) {
                            _showErrorSnackBar('Error generating code: ${e.toString()}');
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0d6b5c)),
                        child: const Text('Generate Code', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: codes.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final code = data['code'] as String? ?? 'Unknown';
                    DateTime createdAt;
                    try {
                      createdAt = data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now();
                    } catch (_) {
                      createdAt = DateTime.now();
                    }
                    DateTime expiresAt;
                    try {
                      expiresAt = data['expiresAt'] != null ? (data['expiresAt'] as Timestamp).toDate() : DateTime.now().add(const Duration(hours: 24));
                    } catch (_) {
                      expiresAt = DateTime.now().add(const Duration(hours: 24));
                    }
                    final isExpired = DateTime.now().isAfter(expiresAt);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Code: $code',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isExpired ? Colors.red : Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isExpired ? 'EXPIRED' : 'ACTIVE',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  tooltip: 'Copy code',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: code));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard')));
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share, size: 20),
                                  tooltip: 'Share code',
                                  onPressed: () {
                                    Share.share('Use this code to connect as my caregiver: $code');
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Created: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('Expires: ${DateFormat('dd/MM/yyyy HH:mm').format(expiresAt)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _viewActiveCodes(); // Refresh the dialog
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  size: 32,
                  color: const Color(0xFF0d6b5c),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Caregiver Access',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Generate access codes for caregivers',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Share access codes with caregivers so they can help manage your medications.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            // Use Column for smaller screens to avoid overflow
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 400) {
                  // Stack buttons vertically on small screens
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _generateAccessCode,
                          icon: Icon(Icons.qr_code),
                          label: Text('Generate Code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0d6b5c),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _viewActiveCodes,
                          icon: Icon(Icons.list),
                          label: Text('View Codes'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0d6b5c),
                            side: BorderSide(color: const Color(0xFF0d6b5c)),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Use Row for larger screens
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _generateAccessCode,
                          icon: Icon(Icons.qr_code),
                          label: Text('Generate Code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0d6b5c),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _viewActiveCodes,
                          icon: Icon(Icons.list),
                          label: Text('View Codes'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0d6b5c),
                            side: BorderSide(color: const Color(0xFF0d6b5c)),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}

class ReportsSection extends StatefulWidget {
  const ReportsSection({super.key});

  @override
  State<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<ReportsSection> {
  List<String> reportPaths = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      reportPaths = prefs.getStringList('reports') ?? [];
    });
  }

  Future<void> _shareReport(String path) async {
    await Share.shareXFiles([XFile(path)], text: 'My Health Report');
  }

  Future<void> _clearAllReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('reports');
    setState(() {
      reportPaths.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All reports cleared!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Saved Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (reportPaths.isNotEmpty)
              TextButton(
                onPressed: _clearAllReports,
                child: Text('Clear All', style: TextStyle(color: theme.colorScheme.primary)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Make the reports list fill the remaining space
        Expanded(
          child: reportPaths.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No reports saved yet.',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 16),
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: reportPaths.length,
                  itemBuilder: (context, index) {
                    final path = reportPaths[index];
                    final fileName = path.split('/').last;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(fileName, style: TextStyle(color: theme.colorScheme.onSurface)),
                        trailing: IconButton(
                          icon: Icon(Icons.email, color: theme.colorScheme.primary),
                          onPressed: () => _shareReport(path),
                        ),
                        onTap: () => OpenFile.open(path),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports', style: TextStyle(color: theme.colorScheme.onPrimary)),
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ReportsSection(),
            ),
          ],
        ),
      ),
    );
  }
}
