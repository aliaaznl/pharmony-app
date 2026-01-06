import 'dart:async';
import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:phnew11/pages/dash.dart';
import 'package:phnew11/pages/metrics.dart';
import 'package:phnew11/pages/charts_page.dart';
import 'package:phnew11/pages/symptoms.dart';
import 'package:phnew11/pages/settings.dart';
import 'service/notification_service.dart';
import 'service/alarm_service.dart';
import 'service/caregiver_service.dart';
import 'pages/caregiver_dashboard.dart';
import 'pages/caregiver_access.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _currentPatientData;
  List<Map<String, dynamic>> _caregiverPatients = [];
  StreamSubscription<List<Map<String, dynamic>>>? _caregiverPatientsSubscription;

  final List<Widget> _pages = [
    const Dashboard(),     // HOME
    const Metrics(),       // HEALTH METRICS
    const ChartsPage(),    // CHARTS
    const SymptomsPage(),  // SYMPTOMS
    const Settings(),      // SETTINGS
  ];

  @override
  void initState() {
    super.initState();
    // Initialize services and load caregiver data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('🏠 Home.initState: Initializing notification service with context');
      print('   Context: $context');
      print('   Context mounted: ${context.mounted}');
      
      try {
        // Initialize NotificationService with proper context
        await NotificationService.initialize(context);
        
        // Set context for alarm service
        AlarmService.setContext(context);
        
        // Register device token for caregiver notifications
        await CaregiverService.registerDeviceToken();
        
        // Load caregiver patients if any
        _loadCaregiverPatients();
        
        print('✅ Both services initialized and context set');
      } catch (e) {
        print('❌ Error initializing services: $e');
      }
    });
  }

  void _loadCaregiverPatients() {
    // Cancel any existing subscription
    _caregiverPatientsSubscription?.cancel();
    
    _caregiverPatientsSubscription = CaregiverService.getCaregiverPatients().listen((patients) {
      if (mounted) {
        setState(() {
          _caregiverPatients = patients;
        });
      }
    });
  }

  Future<void> _switchToPatient(Map<String, dynamic> patient) async {
    try {
      await CaregiverService.switchToPatient(patient['patientId']);
      setState(() {
        _currentPatientData = patient;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Now managing ${patient['patientName']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error switching to patient: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _switchToOwnAccount() {
    CaregiverService.switchToOwnAccount();
    setState(() {
      _currentPatientData = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Switched back to your own account'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildCaregiverModeIndicator() {
    if (!CaregiverService.isInCaregiverMode && _caregiverPatients.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CaregiverService.isInCaregiverMode 
            ? colorScheme.primaryContainer 
            : colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            CaregiverService.isInCaregiverMode 
                ? Icons.medical_services 
                : Icons.person,
            color: CaregiverService.isInCaregiverMode 
                ? colorScheme.onPrimaryContainer 
                : colorScheme.onSurface,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              CaregiverService.isInCaregiverMode 
                  ? (CaregiverService.currentPatientData?['patientName'] ?? _currentPatientData?['patientName'] ?? 'Unknown Patient')
                  : 'Your Account',
              style: TextStyle(
                color: CaregiverService.isInCaregiverMode 
                    ? colorScheme.onPrimaryContainer 
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.swap_horiz,
              color: CaregiverService.isInCaregiverMode 
                  ? colorScheme.onPrimaryContainer 
                  : colorScheme.onSurface,
            ),
            onSelected: (value) {
              if (value == 'own_account') {
                _switchToOwnAccount();
              } else if (value == 'caregiver_access') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CaregiverAccess(),
                  ),
                );
              } else if (value == 'caregiver_dashboard') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CaregiverDashboard(),
                  ),
                );
              } else {
                // Switch to specific patient
                final patient = _caregiverPatients.firstWhere(
                  (p) => p['patientId'] == value,
                  orElse: () => {},
                );
                if (patient.isNotEmpty) {
                  _switchToPatient(patient);
                }
              }
            },
            itemBuilder: (context) => [
              // Only show "Switch to Your Account" for authenticated caregivers, not phone-based access
              if (CaregiverService.isInCaregiverMode && !CaregiverService.isPhoneBasedAccess)
                const PopupMenuItem<String>(
                  value: 'own_account',
                  child: Row(
                    children: [
                      Icon(Icons.person),
                      SizedBox(width: 8),
                      Text('Switch to Your Account'),
                    ],
                  ),
                ),
              
              // Patient options
              ..._caregiverPatients.map((patient) => PopupMenuItem<String>(
                value: patient['patientId'],
                child: Row(
                  children: [
                    Icon(
                      Icons.medical_services,
                      color: CaregiverService.currentPatientId == patient['patientId'] 
                          ? colorScheme.primary 
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Manage ${patient['patientName']}',
                        style: TextStyle(
                          color: CaregiverService.currentPatientId == patient['patientId'] 
                              ? colorScheme.primary 
                              : null,
                          fontWeight: CaregiverService.currentPatientId == patient['patientId']
                              ? FontWeight.bold 
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              
              // Management options - only show for authenticated users, not phone-based access
              if (!CaregiverService.isPhoneBasedAccess) ...[
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'caregiver_access',
                  child: Row(
                    children: [
                      Icon(Icons.login),
                      SizedBox(width: 8),
                      Text('Access Patient Data'),
                    ],
                  ),
                ),
              ],
              if (_caregiverPatients.isNotEmpty && !CaregiverService.isPhoneBasedAccess)
                const PopupMenuItem<String>(
                  value: 'caregiver_dashboard',
                  child: Row(
                    children: [
                      Icon(Icons.dashboard),
                      SizedBox(width: 8),
                      Text('Caregiver Dashboard'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Update context every time build is called to ensure it's always current
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        print('🏠 Home.build: Updating context for services');
        print('   Context: $context');
        print('   Context mounted: ${context.mounted}');
        NotificationService.setContext(context);
        AlarmService.setContext(context);
        print('✅ Context updated for both services');
      } catch (e) {
        print('❌ Error updating context: $e');
      }
    });
    
    return SafeArea(
      child: Scaffold(
        body: _selectedIndex < _pages.length 
            ? _pages[_selectedIndex] 
            : const Dashboard(),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: CurvedNavigationBar(
            backgroundColor: Colors.white,
            color: const Color(0xFF0d6b5c),
            buttonBackgroundColor: const Color(0xFF0d6b5c),
            height: 60,
            index: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index.clamp(0, _pages.length - 1);
              });
            },
            items: const [
              Icon(Icons.home, size: 30, color: Colors.white),
              Icon(Icons.monitor_heart, size: 30, color: Colors.white),
              Icon(Icons.analytics, size: 30, color: Colors.white),
              Icon(Icons.thermostat, size: 30, color: Colors.white),
              Icon(Icons.list, size: 30, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Health Metrics';
      case 2:
        return 'Charts';
      case 3:
        return 'Symptoms';
      case 4:
        return 'Settings';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _caregiverPatientsSubscription?.cancel();
    super.dispose();
  }
}
