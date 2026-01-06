# Caregiver Access System Guide

## Overview
The new caregiver access system allows caregivers to access patient data using the patient's phone number and a 6-digit access code, without requiring the patient to create a formal caregiver account.

## How It Works

### For Patients

1. **Add Phone Number**: Patients must first add their phone number in their profile page
2. **Generate Access Code**: 
   - Go to Profile page
   - Scroll to "Caregiver Access" section
   - Click "Generate Code" to create a new 6-digit access code
   - The code is valid for 24 hours
3. **Share with Caregiver**: Share the code and phone number with the caregiver
4. **View Active Codes**: Use "View Codes" button to see all active access codes

### For Caregivers

1. **Access Patient Data**:
   - From login page: Click "Access Patient Data" button
   - From main app: Use the menu → "Access Patient Data"
2. **Enter Details**:
   - Patient's phone number (must match exactly what's in their profile)
   - 6-digit access code provided by the patient
3. **Login Required**: If not logged in, the system will prompt for login
4. **Access Granted**: Once verified, the caregiver can manage the patient's medications

## Security Features

- **24-Hour Expiry**: Access codes automatically expire after 24 hours
- **Phone Number Verification**: Caregivers must enter the exact phone number from patient's profile
- **One-Time Use**: Each code can only be used once per session
- **Login Required**: Caregivers must be logged into the app to access patient data
- **Session Tracking**: All access sessions are logged for audit purposes

## Database Collections

### `PatientAccessCodes`
```javascript
{
  "patientId": "user123",
  "patientName": "John Doe",
  "patientPhone": "+60123456789",
  "code": "123456",
  "createdAt": "2024-01-01T12:00:00Z",
  "expiresAt": "2024-01-02T12:00:00Z",
  "isActive": true,
  "createdBy": "user123"
}
```

### `TemporaryCaregiverSessions`
```javascript
{
  "caregiverId": "caregiver456",
  "caregiverName": "Jane Smith",
  "caregiverEmail": "jane@example.com",
  "patientId": "patient123",
  "patientName": "John Doe",
  "patientPhone": "+60123456789",
  "accessCodeId": "code789",
  "sessionStartedAt": "2024-01-01T12:00:00Z",
  "isActive": true
}
```

## User Interface

### Profile Page (Patients)
- **Generate Code**: Creates new 6-digit access code
- **View Codes**: Shows all active access codes with expiry times
- **Phone Number Required**: Must have phone number in profile

### Caregiver Access Page
- **Phone Number Field**: Enter patient's phone number
- **Access Code Field**: Enter 6-digit code
- **Validation**: Real-time validation of inputs
- **Error Handling**: Clear error messages for invalid codes/phone numbers

### Login Page
- **Access Patient Data Button**: Direct access to caregiver access page
- **No Account Required**: Can access without creating a patient account

## Workflow

1. **Patient Setup**:
   ```
   Profile → Add Phone Number → Generate Access Code → Share with Caregiver
   ```

2. **Caregiver Access**:
   ```
   Login Page → Access Patient Data → Enter Phone + Code → Login (if needed) → Access Granted
   ```

3. **Data Management**:
   ```
   Dashboard → Manage Patient Medications → Log Intake → View Health Metrics
   ```

## Benefits

- **Simple Setup**: No complex invitation system
- **Quick Access**: Caregivers can access patient data immediately
- **Secure**: Time-limited codes with phone verification
- **Flexible**: Works for temporary or permanent caregiver relationships
- **Audit Trail**: All access is logged and tracked

## Limitations

- **Phone Number Required**: Patients must have phone number in profile
- **24-Hour Expiry**: Codes expire quickly for security
- **One Session**: Each code is tied to one access session
- **Login Required**: Caregivers must have app accounts

## Future Enhancements

- **QR Code Generation**: Generate QR codes for easier sharing
- **SMS Integration**: Send codes via SMS automatically
- **Extended Expiry**: Allow longer expiry times for trusted caregivers
- **Multiple Sessions**: Allow one code to be used multiple times
- **Caregiver Profiles**: Store caregiver information for future access 