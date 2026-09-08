import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../constants/keys.dart';
import 'supabase_service.dart';

class PushNotificationService {
  static const String appId = OneSignalKeys.appId;
  static String get restApiKey => OneSignalKeys.restApiKey;

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isLocalNotificationsInitialized = false;

  static Future<void> initialize() async {
    if (kIsWeb) return; // Ignore on Web

    try {
      // 1. Configure OneSignal SDK
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(appId);

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

  static String? _currentLoggedInUserId;

  // Update subscription ID to user profile on Supabase (multi-device support)
  static Future<void> syncSubscriptionId(String userId) async {
    if (kIsWeb) return;

    try {
      _currentLoggedInUserId = userId;

      // 1. Request notification permission ONLY after user is logged in
      await OneSignal.Notifications.requestPermission(true);

      // 2. Log in user to OneSignal SDK
      OneSignal.login(userId);

      // 3. Opt in to push subscription on this device
      OneSignal.User.pushSubscription.optIn();

      // 3. Obtain current subscription token (with retry if registering asynchronously)
      var subscriptionId = OneSignal.User.pushSubscription.id;
      if (subscriptionId == null || subscriptionId.isEmpty) {
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 800));
          subscriptionId = OneSignal.User.pushSubscription.id;
          if (subscriptionId != null && subscriptionId.isNotEmpty) break;
        }
      }

      print("OneSignal: Active Device Token: $subscriptionId for User: $userId");
      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        await SupabaseService().addProfileOneSignalToken(
          id: userId,
          token: subscriptionId,
        );
      }

      // Automatically sync if subscription token rotates later
      OneSignal.User.pushSubscription.addObserver((state) async {
        // Strict guard: Only sync if this user is still the active logged-in user
        if (_currentLoggedInUserId != userId) return;
        final newId = state.current.id;
        if (newId != null && newId.isNotEmpty && areNotificationsGloballyEnabled) {
          print("OneSignal: Push token updated from observer: $newId for User: $userId");
          await SupabaseService().addProfileOneSignalToken(
            id: userId,
            token: newId,
          );
        }
      });
    } catch (e) {
      print("Error syncing OneSignal subscription: $e");
    }
  }

  // Clear OneSignal session & delete device token from Supabase on logout
  static Future<void> clearPushOnLogout(String userId) async {
    if (kIsWeb) return;
    try {
      print("OneSignal: Removing device push token on logout for User: $userId");
      _currentLoggedInUserId = null;

      final currentDeviceId = OneSignal.User.pushSubscription.id;

      // 1. Remove this specific device's token from Supabase multi-device tokens list
      await SupabaseService().removeProfileOneSignalToken(
        id: userId,
        token: currentDeviceId,
      );

      // 2. Opt out push subscription on device so this phone stops receiving any pushes
      OneSignal.User.pushSubscription.optOut();

      // 3. Unbind external ID from OneSignal SDK
      OneSignal.logout();
    } catch (e) {
      print("Error clearing OneSignal push on logout: $e");
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
      print("Error showing local notification: $e");
    }
  }

  // Send Push Notification to active user profiles & multi-device subscriptions
  static Future<void> sendPushNotification({
    required List<String> subscriptionIds,
    List<String>? externalUserIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (kIsWeb) return;
    if (appId.isEmpty || restApiKey.isEmpty) {
      print("OneSignal configuration missing appId or restApiKey.");
      return;
    }

    final validSubIds = subscriptionIds
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    final validUserIds = (externalUserIds ?? [])
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    if (validSubIds.isEmpty && validUserIds.isEmpty) {
      print("OneSignal: No active targets found. Skipping push broadcast.");
      return;
    }

    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');

      // 1. Primary broadcast via external_id aliases (targets all active logged-in devices under these students)
      if (validUserIds.isNotEmpty) {
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
        print("OneSignal Multi-Device Alias Push sent to ${validUserIds.length} users: ${response.statusCode} - ${response.body}");
      }
      
      // 2. Secondary fallback broadcast to subscription IDs
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
        print("OneSignal Subscription Push sent to ${validSubIds.length} active devices: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error sending OneSignal push notification: $e");
    }
  }

  // Broadcast "Bus Trip Started!" to all active logged-in students assigned to a specific bus
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
        // ALWAYS target every assigned student by their profile ID (external_id in OneSignal)
        userIds.add(s.id);
        if (s.onesignalId != null && s.onesignalId!.trim().isNotEmpty) {
          final tokens = s.onesignalId!
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty);
          subIds.addAll(tokens);
        }
      }

      print("OneSignal: Broadcasting trip started for ${userIds.length} assigned students on $vehicleName");

      if (userIds.isNotEmpty || subIds.isNotEmpty) {
        await sendPushNotification(
          subscriptionIds: subIds,
          externalUserIds: userIds,
          title: "🚌 Bus Trip Started!",
          body: "$vehicleName has started its trip and is on the way. Open MAVIO to track live!",
          data: {'tripId': tripId, 'busNumber': vehicleName, 'type': 'trip_started'},
        );
      }
    } catch (e) {
      print("Error broadcasting trip started push notification: $e");
    }
  }
}
