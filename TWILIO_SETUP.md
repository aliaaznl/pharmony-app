# Twilio SMS Alert Setup Guide

This app can send SMS alerts to caregivers when a patient has 3+ consecutive hypertensive crisis blood pressure readings (systolic > 180 and/or diastolic > 120).

## Setup Steps

### 1. Create a Twilio Account
- Go to [https://www.twilio.com/](https://www.twilio.com/)
- Sign up for a free account
- Verify your email and phone number

### 2. Get Your Twilio Credentials
1. Go to the [Twilio Console](https://console.twilio.com/)
2. From the main dashboard, copy these values:
   - **Account SID** (starts with "AC...")
   - **Auth Token** (click the eye icon to reveal)

### 3. Get a Twilio Phone Number
1. In the Twilio Console, go to **Phone Numbers** > **Manage** > **Buy a number**
2. Choose a phone number (free trial gives you one free number)
3. Copy the phone number (including the country code, e.g., "+12345678901")

### 4. Configure the App
1. Open `lib/config/twilio_config.dart` in your Flutter project
2. Replace the placeholder values:
   ```dart
   static const String accountSid = 'AC...'; // Your actual Account SID
   static const String authToken = '...';    // Your actual Auth Token  
   static const String twilioPhoneNumber = '+1234567890'; // Your Twilio phone number
   ```

### 5. Set Up Caregiver Information
1. Open the app and go to **Profile** page
2. Fill in the **Caregiver Name** and **Caregiver Phone** fields
3. Make sure the caregiver phone number includes the country code (e.g., "+601234567890" for Malaysia)

## How It Works

1. When a user enters blood pressure readings, the app checks if it's a hypertensive crisis (systolic > 180 or diastolic > 120)
2. The app counts consecutive hypertensive crisis readings
3. If there are 3+ consecutive crisis readings AND a caregiver phone is configured, an SMS alert is sent
4. The SMS includes:
   - Patient name
   - Current blood pressure reading
   - Number of consecutive high readings
   - Emergency advisory message

## Testing

To test the SMS functionality:
1. Make sure you've completed all setup steps
2. Add 3 consecutive blood pressure readings with values > 180/120
3. The SMS should be sent automatically after the 3rd reading

## Troubleshooting

- **SMS not sending?** Check that:
  - Twilio credentials are correct in `twilio_config.dart`
  - Caregiver phone number is set in the Profile page
  - Phone numbers include country codes
  - Your Twilio trial account has credits

- **"Failed to send SMS" message?** Check the app logs for detailed error messages

## Free Trial Limitations

Twilio free trial accounts have some limitations:
- Limited SMS credits
- Can only send to verified phone numbers
- May have "Sent from your Twilio trial account" prefix

For production use, you'll need to upgrade to a paid Twilio account.

## Privacy & Security

- SMS alerts are only sent for genuine medical emergencies (3+ consecutive hypertensive crisis readings)
- All SMS sending attempts are logged in Firebase for audit purposes
- Twilio credentials should be kept secure and not shared 