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

  // Register push subscription observer for verification dialog, triggered on entering the App dashboards
  static void setupVerificationObserver(BuildContext context) {
    if (kIsWeb) return;

    try {
      // 1. Check current subscription status immediately
      final currentId = OneSignal.User.pushSubscription.id;
      if (currentId != null && currentId.isNotEmpty && !currentId.startsWith("local-")) {
        _showSuccessDialog(context);
      }

      // 2. Observe changes
      OneSignal.User.pushSubscription.addObserver((state) {
        final newId = state.current.id;
        if (newId != null && newId.isNotEmpty && !newId.startsWith("local-")) {
          _showSuccessDialog(context);
        }
      });
    } catch (e) {
      print("Error setting up OneSignal observer: $e");
    }
  }

  static void _showSuccessDialog(BuildContext context) {
    if (_dialogShown) return;
    _dialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              "Your OneSignal SDK integration is complete!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: const Text(
              "You can now send Push Notifications & In-App Messages through OneSignal. Tap below to enable push notifications.",
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Request push permission ONLY on dialog confirmation
                  OneSignal.Notifications.requestPermission(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Got it", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    });
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
