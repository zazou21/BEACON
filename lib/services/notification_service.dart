import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  // ─────────────────────────────────────────────────────────────
  // Singleton
  // ─────────────────────────────────────────────────────────────
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Callback when user taps a notification
  static void Function(String payload)? onNotificationTapped;

  // ─────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTapped?.call(payload);
        }
      },
    );

    await _requestPermissions();
  }

  // ─────────────────────────────────────────────────────────────
  // Permissions (Android 13+)
  // ─────────────────────────────────────────────────────────────
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();

      if (!status.isGranted) {
        debugPrint('[NotificationService] Notification permission not granted');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Chat Notification
  // ─────────────────────────────────────────────────────────────
  Future<void> showChatNotification({
    required String deviceUuid,
    required String deviceName,
    required String message,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_messages', // channel id
      'Chat Messages', // channel name
      channelDescription: 'Notifications for incoming chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Stable notification ID per device
    final int notificationId = deviceUuid.hashCode;

    await _notifications.show(
      notificationId,
      deviceName,
      message,
      notificationDetails,
      payload: deviceUuid, // used for navigation
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Cancel Notifications
  // ─────────────────────────────────────────────────────────────
  Future<void> cancelNotification(String deviceUuid) async {
    await _notifications.cancel(deviceUuid.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
