import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Initialize Firebase Messaging
  Future<void> initialize() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted notification permission');

        // Get FCM token
        String? token = await _messaging.getToken();
        if (token != null) {
          debugPrint('📱 FCM Token: $token');
          await _saveTokenToFirestore(token);
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_saveTokenToFirestore);
      } else {
        debugPrint('❌ User declined notification permission');
      }
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  /// Save FCM token to Firestore for the current user
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      // Save to a global tokens collection
      await _firestore.collection('fcm_tokens').doc(token).set({
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      }, SetOptions(merge: true));

      debugPrint('✅ FCM token saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Send notification to all usewhen knowledge is posted
  Future<void> sendKnowledgeNotification({
    required String title,
    required String content,
    required String category,
  }) async {
    try {
      // Get all FCM tokens from Firestore
      final tokensSnapshot = await _firestore.collection('fcm_tokens').get();

      if (tokensSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No FCM tokens found');
        return;
      }

      // Create notification payload
      final notification = {
        'title': '🔔 New $category Post',
        'body': title,
        'data': {
          'type': 'knowledge',
          'title': title,
          'content': content,
          'category': category,
          'timestamp': DateTime.now().toIso8601String(),
        },
      };

      // Save notification to Firestore to trigger Cloud Function
      // You'll need to set up a Cloud Function to actually send the FCM messages
      await _firestore.collection('notifications').add({
        'notification': notification,
        'tokens': tokensSnapshot.docs.map((doc) => doc['token']).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      debugPrint('✅ Notification queued for ${tokensSnapshot.docs.length} devices');
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
    }
  }

  /// Subscribe to knowledge updates topic
  Future<void> subscribeToKnowledgeTopic() async {
    try {
      await _messaging.subscribeToTopic('knowledge_updates');
      debugPrint('✅ Subscribed to knowledge updates');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from knowledge updates topic
  Future<void> unsubscribeFromKnowledgeTopic() async {
    try {
      await _messaging.unsubscribeFromTopic('knowledge_updates');
      debugPrint('✅ Unsubscribed from knowledge updates');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }
}

