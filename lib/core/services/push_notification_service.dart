import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'supabase_service.dart';

class PushNotificationService {
  static const String appId = "2633169a-2c5f-4856-bfd3-12361105dc17";
  static const String restApiKey = String.fromEnvironment('ONESIGNAL_REST_API_KEY');

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isLocalNotificationsInitialized = false;

  static Future<void> initialize() async {
    if (kIsWeb) return; // Ignore on Web

    try {
      // 1. Configure OneSignal SDK
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(appId);
      OneSignal.Notifications.requestPermission(true);

      // 2. Configure Local Notifications for foreground/heads-up alerts
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);

      await _localNotificationsPlugin.initialize(initSettings);

      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'mavio_bus_alerts',
            'MAVIO Bus Arrival Alerts',
            description:
                'Real-time proximity alerts when your school bus is approaching your stop.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
      _isLocalNotificationsInitialized = true;
    } catch (e) {
      print("OneSignal init error: $e");
    }
  }

  static bool areNotificationsGloballyEnabled = true;

  // Check if push notifications are enabled on this device
  static bool isPushEnabled() {
    if (kIsWeb) return false;
    try {
      return OneSignal.User.pushSubscription.optedIn ?? true;
    } catch (_) {
      return true;
    }
  }

  // Toggle push notification state for this device and sync with Supabase
  static Future<bool> setPushNotificationsEnabled(bool enable, String userId) async {
    areNotificationsGloballyEnabled = enable;
    if (kIsWeb) return enable;

    try {
      if (enable) {
        // 1. Request system notification permission
        await OneSignal.Notifications.requestPermission(true);
        // 2. Opt in to OneSignal push subscription
        OneSignal.User.pushSubscription.optIn();
        // 3. Sync subscription ID to Supabase
        await syncSubscriptionId(userId);
        return true;
      } else {
        // 1. Opt out from OneSignal push subscription
        OneSignal.User.pushSubscription.optOut();
        // 2. Clear OneSignal ID from profile in Supabase
        await SupabaseService().updateProfileOneSignalId(
          id: userId,
          onesignalId: null,
        );
        return false;
      }
    } catch (e) {
      print("Error setting push notification state: $e");
      return enable;
    }
  }

  // Register push permission observer on entering dashboards
  static void setupVerificationObserver(BuildContext context) {
    if (kIsWeb) return;

    try {
      OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      print("Error prompting for notification permission: $e");
    }
  }

  // Update subscription ID to user profile on Supabase
  static Future<void> syncSubscriptionId(String userId) async {
    if (kIsWeb) return;

    try {
      // Bind user external ID to OneSignal
      OneSignal.login(userId);

      final subscriptionId = OneSignal.User.pushSubscription.id;
      print("OneSignal: User Subscription ID: $subscriptionId for User: $userId");
      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        await SupabaseService().updateProfileOneSignalId(
          id: userId,
          onesignalId: subscriptionId,
        );
      }

      // Automatically sync subscription ID if it changes later
      OneSignal.User.pushSubscription.addObserver((state) async {
        final newId = state.current.id;
        if (newId != null && newId.isNotEmpty && areNotificationsGloballyEnabled) {
          await SupabaseService().updateProfileOneSignalId(
            id: userId,
            onesignalId: newId,
          );
        }
      });
    } catch (e) {
      print("Error syncing OneSignal subscription: $e");
    }
  }

  // Show instant heads-up local notification on device
  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'mavio_bus_alerts',
        'MAVIO Bus Arrival Alerts',
        channelDescription:
            'Real-time proximity alerts when your school bus is approaching your stop.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/launcher_icon',
      );
      const NotificationDetails details = NotificationDetails(android: androidDetails);
      await _localNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    } catch (e) {
      print("Error displaying local notification: $e");
    }
  }

  // Send Push Notification to specific OneSignal Subscription IDs or External User IDs via OneSignal REST API
  static Future<void> sendPushNotification({
    List<String>? subscriptionIds,
    List<String>? externalUserIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final validSubIds = subscriptionIds?.where((id) => id.isNotEmpty).toList() ?? [];
    final validUserIds = externalUserIds?.where((id) => id.isNotEmpty).toList() ?? [];

    if (validSubIds.isEmpty && validUserIds.isEmpty) return;

    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');

      // 1. Send by OneSignal Subscription IDs if available (direct & unique)
      if (validSubIds.isNotEmpty) {
        final payload = {
          'app_id': appId,
          'include_subscription_ids': validSubIds,
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data ?? {},
          'priority': 10,
          'android_accent_color': 'FF1E3A8A',
        };

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Basic $restApiKey',
          },
          body: jsonEncode(payload),
        );
        print("OneSignal Push sent: ${response.statusCode} - ${response.body}");
      } else if (validUserIds.isNotEmpty) {
        // 2. Fallback to External User ID alias only if no subscription IDs are present
        final payload = {
          'app_id': appId,
          'include_aliases': {'external_id': validUserIds},
          'target_channel': 'push',
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data ?? {},
          'priority': 10,
          'android_accent_color': 'FF1E3A8A',
        };

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Basic $restApiKey',
          },
          body: jsonEncode(payload),
        );
        print("OneSignal Alias Push sent: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error sending OneSignal push notification: $e");
    }
  }

  // Broadcast "Bus Trip Started!" to all students assigned to a specific bus
  static Future<void> notifyTripStarted({
    required String vehicleId,
    required String vehicleName,
    required String tripId,
  }) async {
    if (kIsWeb) return;

    try {
      final students = await SupabaseService().getAssignedStudentsForVehicle(vehicleId);
      final List<String> subIds = [];
      final List<String> userIds = [];

      for (var s in students) {
        userIds.add(s.id);
        if (s.onesignalId != null && s.onesignalId!.isNotEmpty) {
          subIds.add(s.onesignalId!);
        }
      }

      if (subIds.isNotEmpty || userIds.isNotEmpty) {
        await sendPushNotification(
          subscriptionIds: subIds,
          externalUserIds: userIds,
          title: "🚌 Bus Trip Started!",
          body: "$vehicleName has started its trip and is on the way. Open MAVIO to track live!",
          data: {'tripId': tripId, 'busNumber': vehicleName},
        );
      }
    } catch (e) {
      print("Error broadcasting trip started push notification: $e");
    }
  }
}
