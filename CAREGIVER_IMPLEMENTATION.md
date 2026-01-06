# Caregiver Feature Implementation Guide

## Overview
This implementation allows caregivers to manage medications for patients remotely while ensuring that medication alarms and notifications only go to the patient's device, not the caregiver's device.

## Key Features

### 1. **Caregiver-Patient Relationship Management**
- **Invitation System**: Patients generate 6-digit codes that expire in 24 hours
- **Secure Connection**: Caregivers accept invitations using the codes
- **Permission Control**: Granular permissions for different actions
- **Multiple Relationships**: One caregiver can manage multiple patients, one patient can have multiple caregivers

### 2. **Device-Specific Notifications**
- **Patient Device Targeting**: Alarms only ring on patient's phone
- **Caregiver Notifications**: Caregivers get confirmation notifications
- **Firebase Cloud Messaging**: Uses FCM for cross-device communication

### 3. **Context Switching**
- **Caregiver Mode**: Caregivers can switch between managing different patients
- **Visual Indicators**: Clear UI showing when in caregiver mode
- **Audit Trail**: All actions are logged with caregiver information

## Database Structure

### Collections

#### `CaregiverInvitations`
```javascript
{
  "invitationCode": "123456",
  "patientId": "user123",
  "patientName": "John Doe",
  "patientEmail": "john@example.com",
  "patientPhoneNumber": "+1234567890",
  "createdAt": "2024-01-01T12:00:00Z",
  "expiresAt": "2024-01-02T12:00:00Z",
  "isUsed": false,
  "usedBy": null,
  "usedAt": null
}
```

#### `CaregiverPatients`
```javascript
{
  "caregiverId": "caregiver123",
  "patientId": "patient456",
  "caregiverName": "Jane Smith",
  "caregiverEmail": "jane@example.com",
  "patientName": "John Doe",
  "patientEmail": "john@example.com",
  "relationshipType": "caregiver",
  "permissions": [
    "view_medications",
    "add_medications",
    "edit_medications",
    "log_medication_intake",
    "view_health_metrics"
  ],
  "createdAt": "2024-01-01T12:00:00Z",
  "isActive": true
}
```

#### `Users` (Enhanced)
```javascript
{
  "deviceToken": "fcm_token_here",
  "lastActive": "2024-01-01T12:00:00Z",
  "email": "user@example.com",
  "displayName": "User Name",
  "photoURL": "https://example.com/photo.jpg"
}
```

#### `Medications` (Enhanced)
```javascript
{
  "userId": "patient123", // Always the patient's ID
  "medicationName": "Aspirin",
  "createdBy": "caregiver456", // Present if created by caregiver
  "createdByType": "caregiver",
  "caregiverName": "Jane Smith",
  // ... other medication fields
}
```

#### `MedicationStatus` (Enhanced)
```javascript
{
  "medicationId": "med123",
  "userId": "patient123", // Always the patient's ID
  "status": "taken",
  "loggedBy": "caregiver456", // Present if logged by caregiver
  "loggedByType": "caregiver",
  "caregiverName": "Jane Smith",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

## Implementation Flow

### Patient Flow
1. **Invite Caregiver**
   - Go to Caregiver Management page
   - Enter their name and optional phone number
   - Generate 6-digit invitation code
   - Share code with caregiver (SMS, email, etc.)

2. **Manage Caregivers**
   - View connected caregivers
   - Remove caregiver access
   - See who performed medication actions

### Caregiver Flow
1. **Accept Invitation**
   - Enter invitation code in app
   - Connection is established
   - Get access to patient's medication schedule

2. **Manage Patient**
   - Switch to patient management mode
   - Add/edit medications (stored under patient's account)
   - Log medication intake
   - View patient's health metrics

3. **Switch Between Patients**
   - Manage multiple patients
   - Clear visual indicators of current patient
   - Easy switching between own account and patient accounts

## Technical Implementation

### Core Service (`CaregiverService`)
```dart
// Key methods:
- createCaregiverInvitation()
- acceptCaregiverInvitation()
- switchToPatient()
- getEffectiveUserId()
- registerDeviceToken()
- sendNotificationToPatient()
```

### UI Components
- **CaregiverManagement**: Main page for managing caregiver relationships
- **Dashboard Updates**: Shows caregiver mode indicator
- **Sidebar Navigation**: Includes caregiver management

### Notification System
- **Local Notifications**: For immediate device alarms
- **Push Notifications**: For cross-device communication
- **Cloud Functions**: Server-side notification targeting

## Security Features

### Authentication & Authorization
- **Firebase Auth**: Secure user authentication
- **Permission Validation**: Server-side permission checking
- **Expiring Invitations**: Time-limited invitation codes
- **Audit Trail**: Full logging of all actions

### Data Protection
- **User Isolation**: Patient data only accessible to authorized caregivers
- **Device Token Security**: Secure storage of notification tokens
- **Relationship Validation**: All operations validate caregiver-patient relationships

## Cloud Functions Setup

### Prerequisites
```bash
npm install -g firebase-tools
firebase login
firebase init functions
```

### Deploy Functions
```bash
cd functions
npm install firebase-functions firebase-admin
firebase deploy --only functions
```

### Required Functions
1. **sendCaregiverNotification**: Send notifications to patient's device
2. **sendMedicationAlarm**: Send medication alarms to patient only
3. **onMedicationUpdate**: Trigger when medications are created/updated

## Testing Scenarios

### Test Case 1: Basic Caregiver Setup
1. Patient creates invitation code
2. Caregiver accepts invitation
3. Verify relationship is established
4. Verify caregiver can switch to patient mode

### Test Case 2: Medication Management
1. Caregiver adds medication for patient
2. Verify medication is stored under patient's account
3. Verify caregiver metadata is recorded
4. Verify alarm goes to patient's device only

### Test Case 3: Multiple Patients
1. Caregiver connects to multiple patients
2. Switch between patients
3. Verify data isolation
4. Verify correct notification targeting

### Test Case 4: Permission Revocation
1. Patient removes caregiver access
2. Verify caregiver loses access
3. Verify existing medications remain

## Error Handling

### Common Error Cases
- **Expired Invitations**: Clear error message, generate new code
- **Invalid Permissions**: Graceful degradation, clear error messages
- **Device Token Issues**: Fallback to alternative notification methods
- **Network Issues**: Offline support, retry mechanisms

## Performance Considerations

### Optimization Strategies
- **Lazy Loading**: Load caregiver data only when needed
- **Caching**: Cache frequently accessed relationships
- **Batch Operations**: Group related database operations
- **Efficient Queries**: Use appropriate Firebase indexes

## Future Enhancements

### Potential Features
- **Video Calls**: Integrate video calling for medication reminders
- **Voice Notes**: Allow voice message attachments
- **Emergency Contacts**: Automatic notifications for missed medications
- **Medication Adherence Reports**: Generate compliance reports for healthcare providers
- **Geofencing**: Location-based medication reminders

## Troubleshooting

### Common Issues
1. **Notifications Not Received**: Check device token registration
2. **Permission Denied**: Verify caregiver-patient relationship
3. **Invitation Codes Not Working**: Check expiration and usage status
4. **UI Not Updating**: Verify stream subscriptions and state management

### Debug Steps
1. Check Firebase Console for error logs
2. Verify device tokens in Users collection
3. Check caregiver-patient relationships
4. Test notification delivery manually

## Deployment Checklist

### Pre-Deployment
- [ ] Update Firebase rules for new collections
- [ ] Deploy Cloud Functions
- [ ] Test notification delivery
- [ ] Verify permission system
- [ ] Test UI on different devices

### Post-Deployment
- [ ] Monitor Cloud Function logs
- [ ] Check notification delivery rates
- [ ] Monitor user feedback
- [ ] Verify database performance
- [ ] Test scalability

## Support & Maintenance

### Monitoring
- **Firebase Analytics**: Track feature usage
- **Error Reporting**: Monitor crashes and errors
- **Performance Monitoring**: Track app performance
- **User Feedback**: Collect user experience data

### Regular Maintenance
- **Database Cleanup**: Remove expired invitations
- **Token Refresh**: Update device tokens regularly
- **Permission Audits**: Review and update permissions
- **Security Updates**: Keep dependencies updated

This implementation provides a robust, secure, and user-friendly caregiver system that ensures medication alarms reach the right person while maintaining proper access control and audit trails. 