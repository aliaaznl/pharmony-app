import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:phnew11/login.dart';
import 'package:phnew11/firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/theme_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:alarm/alarm.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'service/alarm_service.dart';
import 'service/caregiver_service.dart';
import 'pages/reminder_alarm_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Global navigator key to access context from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Setup alarm stream listener to handle alarms when app is closed
void _setupAlarmStreamListener() {
  print('🔔 Setting up alarm stream listener for background alarms...');
  
  // Listen to alarm ring events
  Alarm.ringStream.stream.listen((alarmSettings) {
    print('🚨 ALARM TRIGGERED: ${alarmSettings.id}');
    print('  - Title: ${alarmSettings.notificationSettings.title}');
    print('  - Body: ${alarmSettings.notificationSettings.body}');
    
    // ALWAYS try to get stored alarm data first - this is the source of truth
    print('🔍 Looking for stored alarm data for ID: ${alarmSettings.id}');
    final storedData = AlarmService.getAlarmData(alarmSettings.id);
    
    if (storedData != null) {
      print('✅ Found stored alarm data for ID: ${alarmSettings.id}');
      print('  - Stored data: $storedData');
      
      final medicineName = storedData['medicineName'] ?? 'Unknown Medicine';
      final instructions = storedData['instructions'] ?? 'Take your medicine as prescribed';
      final medicationId = storedData['medicationId'] ?? 'unknown_id';
      
      print('📋 Using stored data:');
      print('  - Medicine Name: $medicineName');
      print('  - Instructions: $instructions');
      print('  - Medication ID: $medicationId');
      
      // Show the full-screen alarm interface with stored data
      _showFullScreenAlarm(
        alarmId: alarmSettings.id,
        medicineName: medicineName,
        instructions: instructions,
        medicationId: medicationId,
        time: '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      );
    } else {
      print('❌ CRITICAL ERROR: No stored data found for alarm ID: ${alarmSettings.id}');
      print('  - This should never happen if alarm was scheduled correctly');
      print('  - Debug: showing all stored alarm data:');
      AlarmService.debugShowAllAlarmData(); // Debug: check what's stored
      
      // Fallback: try to parse from notification body (but this is not reliable)
      final body = alarmSettings.notificationSettings.body;
      String medicineName = 'Unknown Medicine';
      String medicationId = 'unknown_id';
      
      try {
        // Extract medicine name from format: 'Time to take MedicineName - TAP TO OPEN - ID:medicationId'
        final nameMatch = RegExp(r'Time to take (.+?) - TAP TO OPEN').firstMatch(body);
        if (nameMatch != null) {
          medicineName = nameMatch.group(1) ?? 'Unknown Medicine';
        }
        
        // Extract medication ID from the end
        final idMatch = RegExp(r'ID:(.+?)$').firstMatch(body);
        if (idMatch != null) {
          medicationId = idMatch.group(1) ?? 'unknown_id';
        }
        
        print('⚠️ Using fallback parsed data:');
        print('  - Medicine Name: $medicineName');
        print('  - Medication ID: $medicationId');
        
      } catch (e) {
        print('❌ Error parsing alarm notification body: $e');
      }
      
      // Show the full-screen alarm interface with fallback data
      _showFullScreenAlarm(
        alarmId: alarmSettings.id,
        medicineName: medicineName,
        instructions: 'Take your medicine as prescribed',
        medicationId: medicationId,
        time: '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      );
    }
  });
  
  print('✅ Alarm stream listener set up successfully');
}

// Show full-screen alarm interface
void _showFullScreenAlarm({
  required int alarmId,
  required String medicineName,
  required String medicationId,
  required String time,
  String instructions = 'Take your medicine as prescribed',
}) {
  print('🔔 Showing full-screen alarm for: $medicineName');
  
  final context = navigatorKey.currentContext;
  if (context == null) {
    print('❌ No context available for full-screen alarm');
    return;
  }
  
        // Navigate to the alarm screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ReminderAlarmScreen(
            medicineName: medicineName,
            instructions: instructions,
            time: time,
        onTaken: () async {
          print('✅ Medicine taken from background alarm');
          await Alarm.stop(alarmId);
          
          // Update medication status in database
          await _updateMedicationStatusInBackground(medicationId, 'Taken');
          
          Navigator.of(context).pop();
        },
        onSkipped: () async {
          print('⏭️ Medicine skipped from background alarm');
          await Alarm.stop(alarmId);
          
          // Update medication status in database
          await _updateMedicationStatusInBackground(medicationId, 'Skipped');
          
          Navigator.of(context).pop();
        },
        onSnoozed: () async {
          print('😴 Medicine snoozed from background alarm');
          await Alarm.stop(alarmId);
          
          // Update medication status in database
          await _updateMedicationStatusInBackground(medicationId, 'Snoozed');
          
          // Schedule snooze for 10 minutes later
          final snoozeTime = DateTime.now().add(const Duration(minutes: 10));
          await AlarmService.scheduleAlarm(
            scheduledTime: snoozeTime,
            medicineName: 'Snoozed: $medicineName',
            instructions: 'Take your medicine as prescribed',
            medicationId: 'snoozed_${alarmId}_${DateTime.now().millisecondsSinceEpoch}',
          );
          
          Navigator.of(context).pop();
        },
      ),
      fullscreenDialog: true,
    ),
  );
}

// Update medication status in background for dashboard display
Future<void> _updateMedicationStatusInBackground(String medicationId, String status) async {
  try {
    // Get effective user ID for the status record
    final effectiveUserId = CaregiverService.getEffectiveUserId();
    
    await FirebaseFirestore.instance
        .collection('MedicationStatus')
        .add({
      'medicationId': medicationId,
      'status': status,
      'userId': effectiveUserId, // Add userId for charts query
      'timestamp': FieldValue.serverTimestamp(),
      'actionTime': DateTime.now(),
      'source': 'background_alarm',
    });
    
    print('✅ Background medication status updated: $status for $medicationId');
  } catch (e) {
    print('❌ Error updating background medication status: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize timezone
  tz.initializeTimeZones();
  
  // Initialize the alarm package for real alarm sounds
  await Alarm.init();
  print('✅ Real alarm system initialized');

  // Set up alarm stream listener to handle alarms when app is closed
  _setupAlarmStreamListener();

  // Initialize and reset caregiver service to ensure normal users start in their own mode
  CaregiverService.initialize();
  CaregiverService.resetCaregiverMode();
  print('✅ Caregiver service initialized and reset');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Health Monitor',
            navigatorKey: navigatorKey, // Add global navigator key
            theme: themeProvider.lightTheme.copyWith(
              textTheme: GoogleFonts.poppinsTextTheme(themeProvider.lightTheme.textTheme),
            ),
            darkTheme: themeProvider.darkTheme.copyWith(
              textTheme: GoogleFonts.poppinsTextTheme(themeProvider.darkTheme.textTheme),
            ),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(themeProvider.fontSizeMultiplier),
                ),
                child: child!,
              );
            },
            home: const LogIn(),
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

Future<void> scheduleNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'medication_reminder_channel',
    'Medication Reminder',
    channelDescription: 'Channel for medication reminder notifications',
    importance: Importance.max,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound('reminder'), // Uses reminder.wav from res/raw/
    enableVibration: true,
    playSound: true,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    'Medication Reminder',
    'Time to take your pulmonary hypertension medicine.',
    tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)), // 10s later
    notificationDetails,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}
