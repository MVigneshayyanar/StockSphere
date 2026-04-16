/**
 * Cloud Functions for Firebase - Push Notifications
 *
 * This function sends push notifications when new knowledge posts are created.
 * Deploy this to Firebase Cloud Functions to enable notification sending.
 *
 * Setup Instructions:
 * 1. Install Firebase CLI: npm install -g firebase-tools
 * 2. Login: firebase login
 * 3. Initialize functions: firebase init functions
 * 4. Copy this code to functions/index.js
 * 5. Deploy: firebase deploy --only functions
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Send push notifications when a new notification document is created
 */
exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();

    if (data.sent) {
      return null; // Already sent
    }

    const { notification, tokens } = data;

    if (!tokens || tokens.length === 0) {
      console.log('No tokens to send to');
      return null;
    }

    // Prepare the message
    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: notification.data || {},
      tokens: tokens, // Array of FCM tokens
    };

    try {
      // Send to multiple devices
      const response = await admin.messaging().sendMulticast(message);

      console.log(`Successfully sent ${response.successCount} notifications`);
      console.log(`Failed to send ${response.failureCount} notifications`);

      // Mark as sent
      await snap.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        successCount: response.successCount,
        failureCount: response.failureCount,
      });

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        const tokensToRemove = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success &&
              (resp.error.code === 'messaging/invalid-registration-token' ||
               resp.error.code === 'messaging/registration-token-not-registered')) {
            tokensToRemove.push(tokens[idx]);
          }
        });

        // Remove invalid tokens from fcm_tokens collection
        const batch = admin.firestore().batch();
        tokensToRemove.forEach(token => {
          batch.delete(admin.firestore().collection('fcm_tokens').doc(token));
        });
        await batch.commit();

        console.log(`Removed ${tokensToRemove.length} invalid tokens`);
      }

      return { success: true };
    } catch (error) {
      console.error('Error sending notification:', error);
      await snap.ref.update({
        error: error.message,
        errorCode: error.code,
      });
      throw error;
    }
  });

/**
 * Alternative: Send to topic (more efficient for broadcasting)
 */
exports.sendToTopic = functions.firestore
  .document('knowledge/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();

    const message = {
      notification: {
        title: `🔔 New ${data.category} Post`,
        body: data.title,
      },
      data: {
        type: 'knowledge',
        docId: context.params.docId,
        title: data.title,
        content: data.content || '',
        category: data.category || 'General',
      },
      topic: 'knowledge_updates',
    };

    try {
      const response = await admin.messaging().send(message);
      console.log('Successfully sent message to topic:', response);
      return { success: true, messageId: response };
    } catch (error) {
      console.error('Error sending message to topic:', error);
      throw error;
    }
  });

