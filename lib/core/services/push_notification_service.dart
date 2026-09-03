import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'supabase_service.dart';

class PushNotificationService {
  static const String appId = "2633169a-2c5f-4856-bfd3-12361105dc17";
  static bool _dialogShown = false;

  static Future<void> initialize() async {
    if (kIsWeb) return; // Ignore on Web

    try {
      // Configure OneSignal SDK
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(appId);
    } catch (e) {
      print("OneSignal init error: $e");
    }
  }

  // Register push subscription observer for verification, triggered on entering the App dashboards
  static void setupVerificationObserver(BuildContext context) {
    if (kIsWeb) return;

    try {
      // Request push permission silently
      OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      print("Error prompting for notification permission: $e");
    }
  }

  // Update subscription ID to user profile on Supabase
  static Future<void> syncSubscriptionId(String userId) async {
    if (kIsWeb) return;

    try {
      final subscriptionId = OneSignal.User.pushSubscription.id;
      print("OneSignal: User Subscription ID: $subscriptionId");
      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        await SupabaseService().updateProfileOneSignalId(
          id: userId,
          onesignalId: subscriptionId,
        );
      }

      // Automatically sync subscription ID if it changes later
      OneSignal.User.pushSubscription.addObserver((state) async {
        final newId = state.current.id;
        if (newId != null && newId.isNotEmpty) {
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
}
