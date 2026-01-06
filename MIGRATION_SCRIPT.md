# Migration Script: Replace Old Alarm Services

## Files to Update

### 1. lib/main.dart
**Line 153**: Replace `AlarmService.scheduleAlarm` with `OptimizedAlarmService.scheduleAlarm`

```dart
// OLD:
await AlarmService.scheduleAlarm(
  scheduledTime: snoozeTime,
  medicineName: 'Snoozed: $medicineName',
  instructions: 'Take your medicine as prescribed',
  medicationId: 'snoozed_${alarmId}_${DateTime.now().millisecondsSinceEpoch}',
);

// NEW:
await OptimizedAlarmService.scheduleAlarm(
  scheduledTime: snoozeTime,
  medicineName: 'Snoozed: $medicineName',
  instructions: 'Take your medicine as prescribed',
  medicationId: 'snoozed_${alarmId}_${DateTime.now().millisecondsSinceEpoch}',
);
```

### 2. lib/pages/edit_medication_wizard.dart
**Line 458**: Replace `AlarmService.scheduleAlarm` with `OptimizedAlarmService.scheduleAlarm`

```dart
// OLD:
await AlarmService.scheduleAlarm(
  scheduledTime: finalScheduledTime,
  medicineName: _medicationNameController.text.trim(),
  instructions: "Take ${_doseAmountController.text.trim()} $_selectedDoseType $_selectedIntakeTime",
  medicationId: '${docRef.id}_dose_$i',
);

// NEW:
await OptimizedAlarmService.scheduleAlarm(
  scheduledTime: finalScheduledTime,
  medicineName: _medicationNameController.text.trim(),
  instructions: "Take ${_doseAmountController.text.trim()} $_selectedDoseType $_selectedIntakeTime",
  medicationId: '${docRef.id}_dose_$i',
);
```

### 3. lib/pages/medication_wizard.dart
**Line 356**: Replace `AlarmService.scheduleAlarm` with `OptimizedAlarmService.scheduleAlarm`

```dart
// OLD:
await AlarmService.scheduleAlarm(
  scheduledTime: finalScheduledTime,
  medicineName: _medicationNameController.text.trim(),
  instructions: "Take ${_doseAmountController.text.trim()} $_selectedDoseType $_selectedIntakeTime",
  medicationId: '${docRef.id}_dose_$i',
);

// NEW:
await OptimizedAlarmService.scheduleAlarm(
  scheduledTime: finalScheduledTime,
  medicineName: _medicationNameController.text.trim(),
  instructions: "Take ${_doseAmountController.text.trim()} $_selectedDoseType $_selectedIntakeTime",
  medicationId: '${docRef.id}_dose_$i',
);
```

### 4. lib/pages/meds.dart
**Lines 180 and 327**: Replace `AlarmService.scheduleAlarm` with `OptimizedAlarmService.scheduleAlarm`

```dart
// OLD:
await AlarmService.scheduleAlarm(
  scheduledTime: scheduledTime,
  medicineName: medicineName,
  instructions: instructions,
  medicationId: medicationId,
);

// NEW:
await OptimizedAlarmService.scheduleAlarm(
  scheduledTime: scheduledTime,
  medicineName: medicineName,
  instructions: instructions,
  medicationId: medicationId,
);
```

## Add Import Statement

Add this import to all files that use the alarm service:

```dart
import '../service/optimized_alarm_service.dart';
```

## Update Context Setting

In your main app initialization (main.dart), add:

```dart
// After runApp(const MyApp());
// In your app's initialization
OptimizedAlarmService.setContext(context);
```

## Test the Migration

After making these changes, test with:

```dart
// Test immediate alarm
await OptimizedAlarmService.testAlarm();

// Test scheduled alarm (30 seconds)
await OptimizedAlarmService.testScheduledAlarm();
```

## Expected Results

After migration:
- Alarms should ring exactly at scheduled time (no delays)
- Immediate alarms should show instantly
- Single alarm system (no conflicts)
- Minimal overhead and processing delays 