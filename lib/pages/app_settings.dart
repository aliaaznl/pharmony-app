import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  bool _notificationsEnabled = true;
  bool _medicationReminders = true;
  bool _bloodPressureReminders = true;
  bool _emergencyAlerts = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _medicationReminders = prefs.getBool('medication_reminders') ?? true;
      _bloodPressureReminders = prefs.getBool('bp_reminders') ?? true;
      _emergencyAlerts = prefs.getBool('emergency_alerts') ?? true;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('App Settings'),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Appearance Section
                _buildSectionCard(
                  'Appearance',
                  Icons.palette,
                  [
                    _buildSwitchTile(
                      'Dark Mode',
                      'Use dark theme throughout the app',
                      Icons.dark_mode,
                      themeProvider.isDarkMode,
                      (value) => themeProvider.toggleTheme(),
                    ),
                    _buildSwitchTile(
                      'High Contrast',
                      'Increase contrast for better visibility',
                      Icons.contrast,
                      themeProvider.isHighContrast,
                      (value) => themeProvider.toggleHighContrast(),
                    ),
                    _buildSliderTile(
                      'Font Size',
                      'Adjust text size for better readability',
                      Icons.format_size,
                      themeProvider.fontSizeMultiplier,
                      0.8,
                      1.5,
                      (value) => themeProvider.setFontSize(value),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Notifications Section
                _buildSectionCard(
                  'Notifications',
                  Icons.notifications,
                  [
                    _buildSwitchTile(
                      'Enable Notifications',
                      'Allow app to send notifications',
                      Icons.notifications_active,
                      _notificationsEnabled,
                      (value) {
                        setState(() => _notificationsEnabled = value);
                        _saveSetting('notifications_enabled', value);
                      },
                    ),
                    _buildSwitchTile(
                      'Medication Reminders',
                      'Remind you to take medications',
                      Icons.medication,
                      _medicationReminders,
                      (value) {
                        setState(() => _medicationReminders = value);
                        _saveSetting('medication_reminders', value);
                      },
                      enabled: _notificationsEnabled,
                    ),
                    _buildSwitchTile(
                      'Blood Pressure Reminders',
                      'Remind you to check blood pressure',
                      Icons.monitor_heart,
                      _bloodPressureReminders,
                      (value) {
                        setState(() => _bloodPressureReminders = value);
                        _saveSetting('bp_reminders', value);
                      },
                      enabled: _notificationsEnabled,
                    ),
                    _buildSwitchTile(
                      'Emergency Alerts',
                      'Critical health alerts to caregivers',
                      Icons.emergency,
                      _emergencyAlerts,
                      (value) {
                        setState(() => _emergencyAlerts = value);
                        _saveSetting('emergency_alerts', value);
                      },
                      enabled: _notificationsEnabled,
                    ),
                  ],
                ),
                

                
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    bool enabled = true,
  }) {
    return Semantics(
      label: '$title. $subtitle. ${value ? "Enabled" : "Disabled"}',
      toggled: value,
      enabled: enabled,
      child: ListTile(
        leading: Icon(
          icon,
          color: enabled 
            ? Theme.of(context).iconTheme.color 
            : Theme.of(context).disabledColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: enabled 
              ? null 
              : Theme.of(context).disabledColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: enabled 
              ? Theme.of(context).textTheme.bodySmall?.color 
              : Theme.of(context).disabledColor,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: const Color(0xFF0d6b5c),
          activeTrackColor: const Color(0xFF0d6b5c).withOpacity(0.5),
          inactiveThumbColor: Theme.of(context).colorScheme.outline,
          inactiveTrackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Theme.of(context).disabledColor;
            }
            return Theme.of(context).colorScheme.outline;
          }),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    IconData icon,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Theme.of(context).iconTheme.color),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Text(
            '${(value * 100).round()}%',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 7,
          activeColor: const Color(0xFF0d6b5c),
          inactiveColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          thumbColor: const Color(0xFF0d6b5c),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Theme.of(context).iconTheme.color),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showFeatureSnackBar(String feature, bool enabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature ${enabled ? 'enabled' : 'disabled'}',
        ),
        backgroundColor: const Color(0xFF0d6b5c),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }


}
