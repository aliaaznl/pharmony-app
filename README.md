# PHarmony: Mobile Application for Pulmonary Hypertension Patients

**PHarmony** is a mobile application designed to assist patients with Pulmonary Hypertension (PH) in managing their complex medication schedules and monitoring their health conditions. By integrating personalized reminders, vital sign tracking, and comprehensive data visualization, PHarmony aims to improve medication adherence and facilitate better communication between patients and healthcare providers.

![My Project Screenshot](https://raw.githubusercontent.com/aliaaznl/pharmony-app/0decd90e848517b856520bc3d0fc309bae93084d/screenshot.png)

## Table of Contents
- [Overview](#overview)
- [Main Features](#main-features)
- [System Architecture](#system-architecture)
- [Technology Stack](#technology-stack)
- [Installation](#installation)
- [Usage Guide](#usage-guide)
- [Screenshots](#screenshots)

## Overview
Pulmonary hypertension is a chronic condition requiring strict adherence to medication and constant health monitoring. PHarmony addresses the challenge of managing these complex regimens by providing a digital companion that tracks intake, monitors vital signs (blood pressure, heart rate), and visualizes health trends over time.

**Key Objectives:**
* Improve medication adherence through reliable, full-screen reminders.
* Monitor vital signs and symptoms to detect early warning signs.
* Provide actionable insights through interactive data visualization.
* Enhance caregiver involvement via emergency SMS alerts.

## Main Features

### Medication Management
* **Personalized Scheduling:** Support for complex schedules (e.g., multiple daily doses, specific days).
* **Smart Reminders:** Full-screen alarm notifications using `AlarmManager` and `Flutter Local Notifications` to ensure doses aren't missed.
* **Adherence Tracking:** Log status as *Taken*, *Skipped*, or *Snoozed*.

### Health Monitoring & Visualization
* **Vital Sign Tracking:** Log systolic/diastolic blood pressure and pulse rate.
* **Symptom Logging:** Record daily symptoms and their severity on a scale of 1-10.
* **Data Visualization:**
    * **Pie Charts:** View medication adherence rates (Taken vs. Missed).
    * **Line Charts:** Track blood pressure and heart rate trends over time.
    * **Gauge Charts:** Visualize symptom severity levels.
* **PDF Reports:** Export comprehensive health reports for doctor visits.

### Emergency Alert System
* **Crisis Detection:** Automatically detects hypertensive crisis levels (e.g., Systolic > 180 mmHg).
* **Caregiver SMS:** Sends an automated SMS with location and vitals to a registered caregiver via **Twilio API** if abnormal readings are detected consistently.

### Caregiver Access
* **Secure Access:** Patients generate a unique, time-limited 6-digit code.
* **Remote Monitoring:** Caregivers can view the patient's dashboard, adherence, and health status in real-time.

## System Architecture
PHarmony follows a modular architecture to ensure scalability and maintainability. The system connects the client-side Flutter application with a Firebase backend.

* **User Interface Module:** Handles all patient interactions (Login, Dashboard, Input forms).
* **Process Module:** Manages data logic and securely communicates with the database.
* **Notification Module:** Handles local alarms and push notifications.
* **Emergency Module:** Integrates with Twilio for external SMS communication.
* **Database Module:** Firebase Firestore for real-time data storage and synchronization.

## Technology Stack
* **Frontend Framework:** [Flutter](https://flutter.dev/) (Dart)
* **Backend Database:** [Google Firebase](https://firebase.google.com/) (Firestore, Authentication)
* **External APIs:** [Twilio](https://www.twilio.com/) (SMS Services)
* **Key Packages:**
    * `flutter_local_notifications`
    * `android_alarm_manager_plus`
    * `fl_chart` (for data visualization)
    * `pdf` (for report generation)

## Installation

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/yourusername/pharmony.git](https://github.com/yourusername/pharmony.git)
    ```
2.  **Navigate to the project directory:**
    ```bash
    cd pharmony
    ```
3.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Firebase Setup:**
    * Create a project in the Firebase Console.
    * Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective directories.
5.  **Run the App:**
    ```bash
    flutter run
    ```
