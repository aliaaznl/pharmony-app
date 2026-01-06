# PHARMONY Health Monitoring App - Use Cases

## App Overview
PHARMONY is a comprehensive health management mobile application that combines medication tracking, vital signs monitoring, emergency alerts, and health data visualization to provide users with complete control over their health management.

## Primary User Types

### 1. **Chronic Disease Patients**
- Elderly patients with hypertension, diabetes, or heart conditions
- Patients requiring regular medication adherence
- Individuals needing consistent health monitoring

### 2. **Caregivers & Family Members**
- Adult children monitoring elderly parents
- Spouses caring for partners with chronic conditions
- Professional caregivers managing multiple patients

### 3. **Healthcare Professionals**
- Doctors monitoring patients remotely
- Nurses tracking patient compliance
- Healthcare coordinators managing care plans

---

## Detailed Use Cases

### **Use Case 1: Chronic Hypertension Management**

**Primary Actor:** 68-year-old patient with hypertension
**Scenario:** Daily blood pressure monitoring with emergency alerts

**User Story:**
Margaret, a 68-year-old retiree, was diagnosed with hypertension and needs to take medication twice daily while monitoring her blood pressure regularly.

**Workflow:**
1. **Morning Routine:**
   - Margaret opens PHARMONY at 8:00 AM
   - Receives a medication reminder alarm with full-screen notification
   - Takes her morning blood pressure medication
   - Marks medication as "Taken" in the app
   - Records her blood pressure reading (135/85 mmHg)

2. **Continuous Monitoring:**
   - App automatically categorizes reading as "Hypertension Stage 1"
   - Data is stored in Firebase with timestamp
   - Charts page shows trends over time

3. **Emergency Scenario:**
   - Margaret's blood pressure spikes to 185/125 mmHg
   - After 3 consecutive high readings, app automatically sends SMS to her daughter
   - SMS: "EMERGENCY: Margaret BP 185/125 - 3 high readings. Contact immediately!"
   - Daughter receives alert and can take immediate action

**Technical Features Used:**
- Real-time alarm system with background processing
- Automatic blood pressure categorization
- Twilio SMS integration for emergency alerts
- Firebase cloud storage for health data
- Trend analysis and visualization

---

### **Use Case 2: Multi-Medication Management**

**Primary Actor:** 72-year-old patient with multiple chronic conditions
**Scenario:** Complex medication schedule with different dosing times

**User Story:**
Robert has diabetes, hypertension, and heart disease, requiring 6 different medications at various times throughout the day.

**Workflow:**
1. **Initial Setup:**
   - Robert uses the Medication Wizard to add all medications
   - Sets up different dosing schedules: morning, noon, evening, bedtime
   - Configures medication types (tablets, pills, liquid)
   - Sets treatment duration and refill reminders

2. **Daily Management:**
   - 7:00 AM: Diabetes medication reminder
   - 8:00 AM: Blood pressure medication
   - 12:00 PM: Heart medication
   - 6:00 PM: Evening medications
   - 10:00 PM: Bedtime medications

3. **Medication Tracking:**
   - Each reminder shows full-screen alarm with medicine name
   - Options to mark as "Taken," "Skipped," or "Snoozed"
   - Snoozed medications reschedule for 10 minutes later
   - Medication status logged in Firebase for compliance tracking

4. **Medication Search & Management:**
   - Can search for new medications to add
   - Edit existing medication schedules
   - View medication history and compliance rates

**Technical Features Used:**
- Advanced alarm scheduling with background processing
- Medication wizard for complex setups
- Real-time medication status tracking
- Audio notifications with custom sounds
- Snooze functionality with automatic rescheduling

---

### **Use Case 3: Family Caregiver Monitoring**

**Primary Actor:** Adult daughter caring for elderly father
**Scenario:** Remote monitoring with emergency notifications

**User Story:**
Sarah lives 50 miles away from her 75-year-old father who has heart disease and often forgets his medications.

**Workflow:**
1. **Setup & Configuration:**
   - Sarah helps father install PHARMONY
   - Configures her phone number for emergency SMS alerts
   - Sets up father's medication schedule
   - Configures blood pressure monitoring routine

2. **Remote Monitoring:**
   - Father receives daily medication reminders
   - App tracks medication compliance automatically
   - Sarah can review compliance data through shared access
   - Blood pressure readings are automatically categorized

3. **Emergency Response:**
   - Father's blood pressure reaches crisis levels (190/130)
   - After 3 consecutive high readings, SMS is automatically sent to Sarah
   - Sarah receives: "EMERGENCY: Dad BP 190/130 - 3 high readings. Contact immediately!"
   - Sarah can immediately call father or emergency services

4. **Data Sharing:**
   - Sarah can access father's health charts and trends
   - Medication compliance reports help identify patterns
   - Data can be shared with healthcare providers

**Technical Features Used:**
- Automatic emergency SMS alerts via Twilio
- Real-time health data synchronization
- Family member notification system
- Cloud-based data sharing
- Compliance tracking and reporting

---

### **Use Case 4: Healthcare Provider Integration**

**Primary Actor:** Family physician managing multiple patients
**Scenario:** Remote patient monitoring with data-driven insights

**User Story:**
Dr. Martinez manages 50+ patients with chronic conditions and needs to monitor their medication adherence and vital signs between visits.

**Workflow:**
1. **Patient Onboarding:**
   - Dr. Martinez recommends PHARMONY to patients
   - Patients set up app with medication schedules
   - Emergency contacts configured for high-risk patients

2. **Continuous Monitoring:**
   - Patients record daily vital signs (BP, heart rate, temperature)
   - Medication adherence automatically tracked
   - Symptom tracking provides additional health insights

3. **Data Analysis:**
   - Charts and trends show patient progress over time
   - PDF reports can be generated for medical records
   - Identifies patients requiring intervention

4. **Emergency Response:**
   - High-risk patients with hypertensive crisis trigger automatic alerts
   - Dr. Martinez can be included in emergency notification chain
   - Immediate intervention can be coordinated

**Technical Features Used:**
- Comprehensive health data visualization
- PDF report generation for medical records
- Multi-user notification system
- Appointment scheduling integration
- Cloud-based data storage with Firebase

---

### **Use Case 5: Elderly Independent Living**

**Primary Actor:** 82-year-old living independently
**Scenario:** Comprehensive health self-management

**User Story:**
Eleanor wants to age in place independently but needs help managing her health conditions and medications.

**Workflow:**
1. **Daily Health Routine:**
   - Morning: Temperature and blood pressure check
   - Throughout day: Medication reminders with audio alerts
   - Evening: Symptom tracking and health summary

2. **Health Monitoring:**
   - Records multiple vital signs daily
   - Tracks symptoms and correlates with medication timing
   - Uses large fonts and high contrast for accessibility

3. **Medication Management:**
   - Audio reminders help overcome hearing difficulties
   - Large, clear medication interface
   - Simple "Taken/Skipped" options reduce confusion

4. **Emergency Preparedness:**
   - Emergency contacts configured for family members
   - Automatic alerts for concerning health trends
   - Integration with healthcare providers

**Technical Features Used:**
- Accessibility features with large fonts
- Audio notification system
- Simplified user interface
- Theme customization (dark/light modes)
- Emergency contact management

---

### **Use Case 6: Post-Surgery Recovery**

**Primary Actor:** Patient recovering from cardiac surgery
**Scenario:** Intensive monitoring during recovery period

**User Story:**
Michael recently had cardiac surgery and needs intensive monitoring during his 3-month recovery period.

**Workflow:**
1. **Recovery Setup:**
   - Multiple medications with complex timing
   - Frequent vital sign monitoring requirements
   - Symptom tracking for recovery indicators

2. **Intensive Monitoring:**
   - Blood pressure checks 3x daily
   - Heart rate monitoring
   - Temperature tracking for infection signs
   - Pain level and symptom documentation

3. **Medication Adherence:**
   - Pain medications with controlled scheduling
   - Cardiac medications with strict timing
   - Anticoagulants requiring precise dosing

4. **Healthcare Team Communication:**
   - Data sharing with cardiac surgeon
   - Trend analysis for recovery progress
   - Alert system for concerning changes

**Technical Features Used:**
- Intensive scheduling capabilities
- Multiple vital sign tracking
- Symptom correlation analysis
- Healthcare provider data sharing
- Recovery progress visualization

---

## Technical Architecture Benefits

### **For Patients:**
- **Reliability:** Background alarm system works even when app is closed
- **Accessibility:** Large fonts, audio alerts, dark mode support
- **Comprehensive:** All health data in one secure location
- **Emergency Ready:** Automatic crisis detection and alerting

### **For Caregivers:**
- **Peace of Mind:** Real-time SMS alerts for emergencies
- **Remote Monitoring:** Access to patient's health trends
- **Data-Driven:** Compliance reports and health analytics
- **Immediate Response:** Emergency notifications enable quick action

### **For Healthcare Providers:**
- **Patient Engagement:** Improved medication adherence
- **Data Insights:** Comprehensive health trend analysis
- **Remote Care:** Monitor patients between appointments
- **Documentation:** PDF reports for medical records

### **Technical Robustness:**
- **Cloud Storage:** Firebase ensures data security and accessibility
- **Real-time Sync:** All devices stay updated with latest information
- **Offline Capability:** Core functions work without internet
- **Multi-platform:** Works on iOS, Android, and web platforms

---

## Market Impact

PHARMONY addresses critical healthcare challenges:

- **Medication Non-Adherence:** Costs US healthcare system $100+ billion annually
- **Aging Population:** 54 million seniors need better health management tools
- **Chronic Disease Management:** 60% of adults have at least one chronic condition
- **Healthcare Access:** Remote monitoring reduces need for frequent office visits
- **Emergency Response:** Early detection prevents hospitalizations

This comprehensive use case analysis demonstrates how PHARMONY can serve as a complete health management solution for patients, caregivers, and healthcare providers, ultimately improving health outcomes while reducing healthcare costs. 