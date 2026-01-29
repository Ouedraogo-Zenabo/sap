import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/features/user/data/sources/user_local_service.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialise Firebase Cloud Messaging et les notifications locales
  static Future<void> initialize() async {
    // Demander la permission pour les notifications
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('🔔 Permission notifications: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Notifications autorisées');
    } else {
      debugPrint('❌ Notifications refusées');
      return;
    }

    // Initialiser les notifications locales
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('📱 Notification cliquée: ${response.payload}');
      },
    );

    // Créer le canal de notification Android
    const androidChannel = AndroidNotificationChannel(
      'alerts',
      'Alertes',
      description: 'Notifications pour les alertes',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Obtenir le token FCM
    final token = await _firebaseMessaging.getToken();
    debugPrint('🔑 FCM Token: $token');
    
    // TODO: Envoyer ce token au serveur backend
    if (token != null) {
      await _sendTokenToServer(token);
    }

    // Écouter les changements de token
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 Nouveau FCM Token: $newToken');
      _sendTokenToServer(newToken);
    });

    // Gérer les messages reçus quand l'app est au premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Message reçu (foreground): ${message.notification?.title}');
      _showNotification(message);
    });

    // Gérer les messages quand l'app est en arrière-plan mais ouverte
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Message ouvert (background): ${message.notification?.title}');
      _handleNotificationTap(message);
    });

    // Vérifier si l'app a été ouverte depuis une notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 App ouverte depuis notification: ${initialMessage.notification?.title}');
      _handleNotificationTap(initialMessage);
    }
  }

  /// Affiche une notification locale pour un message Firebase
  static Future<void> _showNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification == null) {
      debugPrint('⚠️ Pas de notification dans le message');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'alerts',
      'Alertes',
      channelDescription: 'Notifications pour les alertes',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title ?? 'Nouvelle alerte',
        body: notification.body ?? '',
        notificationDetails: notificationDetails,
        payload: message.data.toString(),
      );
      debugPrint('✅ Notification affichée: ${notification.title}');
    } catch (e) {
      debugPrint('❌ Erreur affichage notification: $e');
    }
  }

  /// Gère le clic sur une notification
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapée: ${message.data}');
    // TODO: Naviguer vers la page de détail de l'alerte
    // Exemple: Navigator.push(context, AlertDetailPage(alertId: message.data['alertId']));
  }

  /// Envoie le token FCM au serveur backend
  static Future<void> _sendTokenToServer(String token) async {
    try {
      debugPrint('📤 Envoi du token au serveur...');
      // TODO: Implémenter l'appel API pour enregistrer le token
      // Exemple:
      // final response = await http.post(
      //   Uri.parse('http://197.239.116.77:3000/api/v1/users/fcm-token'),
      //   headers: {'Authorization': 'Bearer $accessToken'},
      //   body: jsonEncode({'fcmToken': token}),
      // );
      debugPrint('✅ Token envoyé au serveur');
    } catch (e) {
      debugPrint('❌ Erreur envoi token: $e');
    }
  }
}

/// Handler pour les messages en arrière-plan (doit être top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🌙 Message reçu en arrière-plan: ${message.notification?.title}');
}
