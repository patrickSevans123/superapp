import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network_providers.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
  // NOTE: Plugin initialization (Firebase.initializeApp) is NOT available here.
  // Use shared_preferences or similar for lightweight persistence if needed.
}

/// Simple notification model
class AppNotification {
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const AppNotification({
    required this.title,
    required this.body,
    this.data,
    required this.timestamp,
  });
}

/// Push notification service using Firebase Cloud Messaging
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final Dio _dio;
  final String _gatewayBaseUrl;

  final _notificationController = StreamController<AppNotification>.broadcast();
  Stream<AppNotification> get onNotification => _notificationController.stream;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  NotificationService({required Dio dio, required String gatewayBaseUrl})
      : _dio = dio,
        _gatewayBaseUrl = gatewayBaseUrl;

  /// Initialize FCM: request permissions, get token, set up handlers
  Future<void> initialize({String? userId}) async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('NotificationService: Permission granted');
    } else {
      print('NotificationService: Permission denied');
      return;
    }

    // Get FCM token
    _fcmToken = await _messaging.getToken();
    print('NotificationService: FCM Token: $_fcmToken');

    // Register token with server
    if (_fcmToken != null && userId != null) {
      await _registerDevice(userId, _fcmToken!);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      if (userId != null) {
        _registerDevice(userId, token);
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle message tap (app opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was opened from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _notificationController.add(AppNotification(
        title: notification.title ?? '',
        body: notification.body ?? '',
        data: message.data,
        timestamp: DateTime.now(),
      ));
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _notificationController.add(AppNotification(
        title: notification.title ?? '',
        body: notification.body ?? '',
        data: message.data,
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _registerDevice(String userId, String token) async {
    try {
      await _dio.post(
        '$_gatewayBaseUrl/api/v1/devices/register',
        queryParameters: {
          'user_id': userId,
          'token': token,
          'platform': 'flutter',
        },
      );
    } catch (e) {
      print('NotificationService: Failed to register device: $e');
    }
  }

  /// Unregister device (call on logout)
  Future<void> unregister(String userId) async {
    try {
      await _dio.delete(
        '$_gatewayBaseUrl/api/v1/devices/unregister',
        queryParameters: {'user_id': userId},
      );
    } catch (e) {
      print('NotificationService: Failed to unregister device: $e');
    }
    await _notificationController.close();
  }
}

/// Riverpod provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final dio = ref.watch(authDioProvider);
  // Uses the same gateway base URL as other API calls
  const baseUrl = String.fromEnvironment(
    'API_GATEWAY_URL',
    defaultValue: 'http://localhost:8082',
  );
  return NotificationService(dio: dio, gatewayBaseUrl: baseUrl);
});
