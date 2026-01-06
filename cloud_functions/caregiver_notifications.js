const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Cloud Function to send targeted push notifications to patient's device
 * when caregiver performs medication actions
 */
exports.sendCaregiverNotification = functions.https.onCall(async (data, context) => {
  try {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { patientId, title, body, notificationData } = data;
    
    // Validate required fields
    if (!patientId || !title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Verify caregiver has permission to send notifications to this patient
    const relationshipQuery = await admin.firestore()
      .collection('CaregiverPatients')
      .where('caregiverId', '==', context.auth.uid)
      .where('patientId', '==', patientId)
      .where('isActive', '==', true)
      .get();

    if (relationshipQuery.empty) {
      throw new functions.https.HttpsError('permission-denied', 'No permission to send notifications to this patient');
    }

    // Get patient's device token
    const patientDoc = await admin.firestore()
      .collection('Users')
      .doc(patientId)
      .get();

    if (!patientDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Patient not found');
    }

    const patientData = patientDoc.data();
    const deviceToken = patientData.deviceToken;

    if (!deviceToken) {
      console.log(`No device token found for patient: ${patientId}`);
      return { success: false, error: 'No device token found' };
    }

    // Prepare notification message
    const message = {
      token: deviceToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: 'caregiver_action',
        caregiverId: context.auth.uid,
        patientId: patientId,
        timestamp: Date.now().toString(),
        ...notificationData
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'caregiver_notifications',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Send notification
    const response = await admin.messaging().send(message);
    
    console.log('Notification sent successfully:', response);
    
    return { success: true, messageId: response };
    
  } catch (error) {
    console.error('Error sending caregiver notification:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});

/**
 * Cloud Function to send medication alarm notifications to patient's device
 * This ensures alarms only go to patient, not caregiver
 */
exports.sendMedicationAlarm = functions.https.onCall(async (data, context) => {
  try {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { patientId, medicationName, time, medicationId, alarmType } = data;
    
    // Validate required fields
    if (!patientId || !medicationName || !time || !medicationId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Verify caregiver has permission OR user is the patient themselves
    let hasPermission = false;
    
    if (context.auth.uid === patientId) {
      hasPermission = true; // Patient can always send to themselves
    } else {
      // Check caregiver permission
      const relationshipQuery = await admin.firestore()
        .collection('CaregiverPatients')
        .where('caregiverId', '==', context.auth.uid)
        .where('patientId', '==', patientId)
        .where('isActive', '==', true)
        .get();

      hasPermission = !relationshipQuery.empty;
    }

    if (!hasPermission) {
      throw new functions.https.HttpsError('permission-denied', 'No permission to send medication alarms to this patient');
    }

    // Get patient's device token
    const patientDoc = await admin.firestore()
      .collection('Users')
      .doc(patientId)
      .get();

    if (!patientDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Patient not found');
    }

    const patientData = patientDoc.data();
    const deviceToken = patientData.deviceToken;

    if (!deviceToken) {
      console.log(`No device token found for patient: ${patientId}`);
      return { success: false, error: 'No device token found' };
    }

    // Prepare alarm notification message
    const message = {
      token: deviceToken,
      notification: {
        title: '🚨 Medication Reminder',
        body: `Time to take ${medicationName}`,
      },
      data: {
        type: 'medication_alarm',
        medicationId: medicationId,
        medicationName: medicationName,
        time: time,
        alarmType: alarmType || 'scheduled',
        patientId: patientId,
        timestamp: Date.now().toString(),
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'medication_alarms',
          importance: 'high',
          category: 'alarm',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: '🚨 Medication Reminder',
              body: `Time to take ${medicationName}`,
            },
            sound: 'default',
            badge: 1,
            category: 'MEDICATION_ALARM',
          },
        },
      },
    };

    // Send notification
    const response = await admin.messaging().send(message);
    
    console.log('Medication alarm sent successfully:', response);
    
    return { success: true, messageId: response };
    
  } catch (error) {
    console.error('Error sending medication alarm:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send medication alarm');
  }
});

/**
 * Trigger when medication is created/updated to schedule alarms
 */
exports.onMedicationUpdate = functions.firestore
  .document('Medications/{medicationId}')
  .onWrite(async (change, context) => {
    try {
      const medicationId = context.params.medicationId;
      
      // If document was deleted, skip processing
      if (!change.after.exists) {
        return null;
      }

      const medicationData = change.after.data();
      const patientId = medicationData.userId;
      
      // Get patient's device token
      const patientDoc = await admin.firestore()
        .collection('Users')
        .doc(patientId)
        .get();

      if (!patientDoc.exists) {
        console.log(`Patient not found: ${patientId}`);
        return null;
      }

      const patientData = patientDoc.data();
      const deviceToken = patientData.deviceToken;

      if (!deviceToken) {
        console.log(`No device token found for patient: ${patientId}`);
        return null;
      }

      // Process medication doses and schedule alarms
      const doses = medicationData.doses || [];
      
      for (const dose of doses) {
        const time = dose.time;
        const doseIndex = doses.indexOf(dose);
        
        // Schedule alarm for this dose
        // This is a simplified example - in production, you'd want to use
        // a scheduling service like Cloud Scheduler or Cloud Tasks
        console.log(`Scheduling alarm for ${medicationData.medicationName} at ${time}`);
        
        // You can call your alarm scheduling logic here
        // For example, using Cloud Scheduler to trigger alarms at specific times
      }

      return null;
    } catch (error) {
      console.error('Error processing medication update:', error);
      return null;
    }
  }); 