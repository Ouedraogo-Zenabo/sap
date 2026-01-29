import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/features/user/data/sources/user_local_service.dart';

class PushNotificationService {
  PushNotificationService._privateConstructor();
  static final PushNotificationService _instance = PushNotificationService._privateConstructor();
  factory PushNotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    // handle background message here (minimal)
    debugPrint('Background message received: ${message.messageId}');
  }

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();

      // iOS / Android permission
      await _requestPermissions();

      // Local notifications setup
      await _setupLocalNotifications();

      // Get token
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM token: $_fcmToken');

      // Listen token refresh
      _messaging.onTokenRefresh.listen((token) async {
        _fcmToken = token;
        await registerTokenOnServer(token);
      });

      // Foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('Foreground message: ${message.messageId}');
        await _showLocalNotification(message);
      });

      // When the app is opened from a notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification opened app: ${message.messageId}');
        // navigation logic can be added here
      });

      // register token on backend (best-effort)
      if (_fcmToken != null) {
        await registerTokenOnServer(_fcmToken!);
      }
    } catch (e) {
      debugPrint('PushNotificationService.initialize error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      // On Android 13+ permissions must be requested at runtime; handled in app UI if desired
    }
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        const DarwinInitializationSettings();

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Local notification tapped: ${response.payload}');
      },
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification == null) return;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'default_channel',
        'Default',
        channelDescription: 'Default channel',
        importance: Importance.max,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: platformDetails,
        payload: message.data.isNotEmpty ? message.data.toString() : null,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  Future<bool> registerTokenOnServer(String token, {String? accessToken}) async {
    try {
      // Best-effort: store token locally using existing service
      final local = UserLocalService();
      await local.saveFcmToken(token);
      // Implement server registration call here if backend endpoint exists
      return true;
    } catch (e) {
      debugPrint('registerTokenOnServer error: $e');
      return false;
    }
  }

  Future<bool> removeTokenFromServer({String? accessToken}) async {
    try {
      final local = UserLocalService();
      await local.removeFcmToken();
      return true;
    } catch (e) {
      debugPrint('removeTokenFromServer error: $e');
      return false;
    }
  }
}
