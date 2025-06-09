import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared/services/local_storage_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  }

  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  static Future<void> subscribeToOrganization(String organizationId) async {
    await _messaging.subscribeToTopic('org_$organizationId');

    final subscriptions = LocalStorageService.getUserPreferences()['subscriptions'] as List<String>? ?? [];
    if (!subscriptions.contains(organizationId)) {
      subscriptions.add(organizationId);
      await LocalStorageService.saveUserPreferences({
        ...LocalStorageService.getUserPreferences(),
        'subscriptions': subscriptions,
      });
    }
  }

  static Future<void> unsubscribeFromOrganization(String organizationId) async {
    await _messaging.unsubscribeFromTopic('org_$organizationId');

    final preferences = LocalStorageService.getUserPreferences();
    final subscriptions = preferences['subscriptions'] as List<String>? ?? [];
    subscriptions.remove(organizationId);
    await LocalStorageService.saveUserPreferences({
      ...preferences,
      'subscriptions': subscriptions,
    });
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _showLocalNotification(
      title: message.notification?.title ?? 'Survey App',
      body: message.notification?.body ?? '新しい通知があります',
      payload: message.data.toString(),
    );
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'survey_channel',
      'Survey Notifications',
      channelDescription: 'アンケートアプリからの通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }
}

Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
}