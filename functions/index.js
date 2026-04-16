const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Send push notifications when a new notification document is created
 * Uses FCM V1 API (modern, recommended)
 */
exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();

    if (data.sent) {
      console.log('Notification already sent, skipping');
      return null;
    }

    const { notification, tokens } = data;

    if (!tokens || tokens.length === 0) {
      console.log('No tokens to send to');
      await snap.ref.update({
        sent: true,
        error: 'No tokens available',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    console.log(`Attempting to send notification to ${tokens.length} device(s)`);

    let successCount = 0;
    let failureCount = 0;
    const tokensToRemove = [];

    // Send to each token individually with V1 API
    const sendPromises = tokens.map(async (token) => {
      try {
        const message = {
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: notification.data || {},
          token: token,
          android: {
            notification: {
              sound: 'default',
              priority: 'high',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        await admin.messaging().send(message);
        successCount++;
        console.log(`✅ Sent to token: ${token.substring(0, 20)}...`);
      } catch (error) {
        failureCount++;
        console.error(`❌ Failed to send to token: ${token.substring(0, 20)}...`, error.code);

        // Mark invalid tokens for removal
        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
          tokensToRemove.push(token);
        }
      }
    });

    // Wait for all sends to complete
    await Promise.all(sendPromises);

    console.log(`✅ Successfully sent ${successCount} notification(s)`);
    console.log(`❌ Failed to send ${failureCount} notification(s)`);

    // Update notification document
    await snap.ref.update({
      sent: true,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      successCount: successCount,
      failureCount: failureCount,
    });

    // Clean up invalid tokens
    if (tokensToRemove.length > 0) {
      console.log(`🧹 Removing ${tokensToRemove.length} invalid token(s)`);
      const batch = admin.firestore().batch();
      tokensToRemove.forEach(token => {
        batch.delete(admin.firestore().collection('fcm_tokens').doc(token));
      });
      await batch.commit();
      console.log('✅ Invalid tokens removed');
    }

    return {
      success: true,
      successCount,
      failureCount,
      tokensRemoved: tokensToRemove.length
    };
  });

/**
 * Send to topic when knowledge is created
 * This is more efficient for broadcasting to all users
 */
exports.sendKnowledgeNotification = functions.firestore
  .document('knowledge/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();

    console.log(`📚 New knowledge posted: ${data.title}`);

    const message = {
      notification: {
        title: `🔔 New ${data.category || 'General'} Post`,
        body: data.title,
      },
      data: {
        type: 'knowledge',
        docId: context.params.docId,
        title: data.title,
        content: data.content || '',
        category: data.category || 'General',
        timestamp: new Date().toISOString(),
      },
      topic: 'knowledge_updates',
      android: {
        notification: {
          sound: 'default',
          priority: 'high',
          channelId: 'knowledge_channel',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log('✅ Successfully sent message to topic:', response);
      return { success: true, messageId: response };
    } catch (error) {
      console.error('❌ Error sending message to topic:', error);
      throw error;
    }
  });



