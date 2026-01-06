import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../service/caregiver_service.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _pastAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final effectiveUserId = CaregiverService.getEffectiveUserId();
      if (effectiveUserId == null) {
        print('❌ No effective user ID available');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      print('🔍 Loading appointments for user: $effectiveUserId');
      if (CaregiverService.isInCaregiverMode) {
        print('👥 Caregiver mode: Loading patient appointments');
      }

      // Simplified query without orderBy to avoid composite index requirement
      final appointmentsQuery = await _firestore
          .collection('Appointments')
          .where('userId', isEqualTo: effectiveUserId)
          .get();

      print('📋 Found ${appointmentsQuery.docs.length} appointments');

      final now = DateTime.now();
      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];

      for (var doc in appointmentsQuery.docs) {
        final data = doc.data();
        print('📄 Appointment data: $data');
        
        try {
        final appointmentDate = (data['dateTime'] as Timestamp).toDate();
        final appointmentData = {'id': doc.id, ...data};

        if (appointmentDate.isAfter(now)) {
          upcoming.add(appointmentData);
            print('⏰ Added to upcoming: ${data['doctorName']} on $appointmentDate');
        } else {
          past.add(appointmentData);
            print('📅 Added to past: ${data['doctorName']} on $appointmentDate');
          }
        } catch (e) {
          print('❌ Error processing appointment ${doc.id}: $e');
        }
      }

      // Sort appointments manually after fetching
      upcoming.sort((a, b) => 
          (a['dateTime'] as Timestamp).compareTo(b['dateTime'] as Timestamp));
      past.sort((a, b) => 
          (b['dateTime'] as Timestamp).compareTo(a['dateTime'] as Timestamp));

      print('✅ Final counts - Upcoming: ${upcoming.length}, Past: ${past.length}');

      if (mounted) {
        setState(() {
          _upcomingAppointments = upcoming;
          _pastAppointments = past;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading appointments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading appointments: $e'),
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Appointments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.onPrimary,
          indicatorWeight: 3,
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withOpacity(0.7),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upcoming, size: 20),
                  const SizedBox(width: 8),
                  Text('Upcoming (${_upcomingAppointments.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 20),
                  const SizedBox(width: 8),
                  Text('Past (${_pastAppointments.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            )
          : Column(
              children: [
                _buildStatsHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUpcomingTab(),
                      _buildPastTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAppointmentDialog,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Appointment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 8,
      ),
    );
  }

  Widget _buildStatsHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nextAppointment = _upcomingAppointments.isNotEmpty ? _upcomingAppointments.first : null;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: colorScheme.onPrimary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Quick Overview',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (nextAppointment != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.onPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: colorScheme.onPrimary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Appointment',
                          style: TextStyle(
                            color: colorScheme.onPrimary.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${nextAppointment['doctorName']} - ${nextAppointment['type']}',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy - hh:mm a').format(
                            (nextAppointment['dateTime'] as Timestamp).toDate(),
                          ),
                          style: TextStyle(
                            color: colorScheme.onPrimary.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.onPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available, color: colorScheme.onPrimary, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'No upcoming appointments',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingTab() {
    if (_upcomingAppointments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available,
        title: 'No Upcoming Appointments',
        subtitle: 'Tap the + button to schedule your next appointment',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _upcomingAppointments.length,
      itemBuilder: (context, index) {
        final appointment = _upcomingAppointments[index];
        return _buildAppointmentCard(appointment, isUpcoming: true);
      },
    );
  }

  Widget _buildPastTab() {
    if (_pastAppointments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No Past Appointments',
        subtitle: 'Your appointment history will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pastAppointments.length,
      itemBuilder: (context, index) {
        final appointment = _pastAppointments[index];
        return _buildAppointmentCard(appointment, isUpcoming: false);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, {required bool isUpcoming}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appointmentDate = (appointment['dateTime'] as Timestamp).toDate();
    final type = appointment['type'] as String;
    final color = _getAppointmentColor(type, colorScheme);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: colorScheme.surface,
        child: InkWell(
          onTap: () => _showAppointmentDetails(appointment),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: color, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isUpcoming) ...[
                      IconButton(
                        onPressed: () => _editAppointment(appointment),
                        icon: const Icon(Icons.edit, size: 20),
                        color: colorScheme.onSurface.withOpacity(0.6),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _cancelAppointment(appointment),
                        icon: const Icon(Icons.delete, size: 20),
                        color: colorScheme.error,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment['doctorName'] ?? 'Unknown Doctor',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, color: colorScheme.onSurface.withOpacity(0.6), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, yyyy - hh:mm a').format(appointmentDate),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, color: colorScheme.onSurface.withOpacity(0.6), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment['location'] ?? 'No location specified',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                if (appointment['notes'] != null && appointment['notes'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, color: colorScheme.onSurface.withOpacity(0.6), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          appointment['notes'],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getAppointmentColor(String type, ColorScheme colorScheme) {
    switch (type.toLowerCase()) {
      case 'general checkup':
        return Colors.blue;
      case 'specialist':
        return Colors.purple;
      case 'follow-up':
        return Colors.green;
      case 'emergency':
        return Colors.red;
      case 'consultation':
        return Colors.orange;
      case 'dental':
        return Colors.teal;
      case 'eye exam':
        return Colors.indigo;
      default:
        return colorScheme.primary;
    }
  }

  void _showAddAppointmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AddAppointmentDialog(onAppointmentAdded: _loadAppointments),
    );
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AppointmentDetailsDialog(appointment: appointment),
    );
  }

  void _editAppointment(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AddAppointmentDialog(
        appointment: appointment,
        onAppointmentAdded: _loadAppointments,
      ),
    );
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('Appointments').doc(appointment['id']).delete();
        _loadAppointments();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling appointment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// Add Appointment Dialog
class AddAppointmentDialog extends StatefulWidget {
  final Map<String, dynamic>? appointment;
  final VoidCallback onAppointmentAdded;

  const AddAppointmentDialog({
    super.key,
    this.appointment,
    required this.onAppointmentAdded,
  });

  @override
  State<AddAppointmentDialog> createState() => _AddAppointmentDialogState();
}

class _AddAppointmentDialogState extends State<AddAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _doctorNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedType = 'General Checkup';
  bool _isLoading = false;

  final List<String> _appointmentTypes = [
    'General Checkup',
    'Specialist',
    'Follow-up',
    'Emergency',
    'Consultation',
    'Dental',
    'Eye Exam',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.appointment != null) {
      _loadAppointmentData();
    }
  }

  void _loadAppointmentData() {
    final appointment = widget.appointment!;
    _doctorNameController.text = appointment['doctorName'] ?? '';
    _locationController.text = appointment['location'] ?? '';
    _notesController.text = appointment['notes'] ?? '';
    _selectedType = appointment['type'] ?? 'General Checkup';
    
    final dateTime = (appointment['dateTime'] as Timestamp).toDate();
    _selectedDate = dateTime;
    _selectedTime = TimeOfDay.fromDateTime(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7, // Reduced height to account for keyboard
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - fixed height
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_box, color: colorScheme.onSurface, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.appointment != null ? 'Edit Appointment' : 'New Appointment',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: colorScheme.onSurface, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            // Form content - scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextFormField(
                      controller: _doctorNameController,
                      decoration: InputDecoration(
                        labelText: 'Doctor Name',
                        prefixIcon: Icon(Icons.person, color: colorScheme.onSurfaceVariant, size: 20),
                        border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter doctor name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Appointment Type',
                        prefixIcon: Icon(Icons.category, color: colorScheme.onSurfaceVariant, size: 20),
                        border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _appointmentTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDateTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date & Time',
                          prefixIcon: Icon(Icons.calendar_today, color: colorScheme.onSurfaceVariant, size: 20),
                          border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        child: Text(
                          '${DateFormat('MMM dd, yyyy').format(_selectedDate)} at ${_selectedTime.format(context)}',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location (Optional)',
                        prefixIcon: Icon(Icons.location_on, color: colorScheme.onSurfaceVariant, size: 20),
                        border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        prefixIcon: Icon(Icons.note, color: colorScheme.onSurfaceVariant, size: 20),
                        border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveAppointment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: colorScheme.onPrimary)
                            : Text(
                                widget.appointment != null ? 'Update' : 'Schedule',
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Future<void> _selectDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });
      }
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final effectiveUserId = CaregiverService.getEffectiveUserId();
      
      if (effectiveUserId == null) {
        throw Exception('No effective user ID available');
      }

      final appointmentDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final appointmentData = {
        'userId': effectiveUserId, // Always use the effective user ID (patient's ID)
        'doctorName': _doctorNameController.text.trim(),
        'type': _selectedType,
        'location': _locationController.text.trim(),
        'notes': _notesController.text.trim(),
        'dateTime': Timestamp.fromDate(appointmentDateTime),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add caregiver metadata if in caregiver mode
      if (CaregiverService.isInCaregiverMode) {
        appointmentData.addAll({
          'createdBy': user?.uid ?? 'anonymous',
          'createdByType': 'caregiver',
          'caregiverName': user?.displayName ?? user?.email ?? 'Unknown Caregiver',
        });
      }

      print('💾 Saving appointment data: $appointmentData');

      if (widget.appointment != null) {
        await FirebaseFirestore.instance
            .collection('Appointments')
            .doc(widget.appointment!['id'])
            .update(appointmentData);
        print('✅ Appointment updated successfully');
      } else {
        final docRef = await FirebaseFirestore.instance
            .collection('Appointments')
            .add(appointmentData);
        print('✅ Appointment created successfully with ID: ${docRef.id}');
      }

      widget.onAppointmentAdded();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.appointment != null 
                ? 'Appointment updated successfully!' 
                : 'Appointment scheduled successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error saving appointment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving appointment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// Appointment Details Dialog
class AppointmentDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const AppointmentDetailsDialog({
    super.key,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appointmentDate = (appointment['dateTime'] as Timestamp).toDate();
    final isUpcoming = appointmentDate.isAfter(DateTime.now());

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: colorScheme.onSurface),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Appointment Details',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Doctor', appointment['doctorName'] ?? 'Unknown', colorScheme),
                    _buildDetailRow('Type', appointment['type'] ?? 'General', colorScheme),
                    _buildDetailRow('Date', DateFormat('EEEE, MMM dd, yyyy').format(appointmentDate), colorScheme),
                    _buildDetailRow('Time', DateFormat('hh:mm a').format(appointmentDate), colorScheme),
                    if (appointment['location'] != null && appointment['location'].isNotEmpty)
                      _buildDetailRow('Location', appointment['location'], colorScheme),
                    _buildDetailRow('Status', isUpcoming ? 'Upcoming' : 'Past', colorScheme),
                    if (appointment['notes'] != null && appointment['notes'].isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Notes:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(appointment['notes']),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
} 
