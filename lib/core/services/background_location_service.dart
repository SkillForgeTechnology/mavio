import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/keys.dart';
import 'supabase_service.dart';

class BackgroundLocationService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Explicitly start only when driver starts a trip
        isForegroundMode: true,
        notificationChannelId: 'mavio_location_channel',
        initialNotificationTitle: 'MAVIO Smart Transit',
        initialNotificationContent: 'Initializing background tracking...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialize Supabase inside this background isolate
    try {
      await Supabase.initialize(
        url: SupabaseKeys.url,
        anonKey: SupabaseKeys.anonKey,
      );
    } catch (_) {
      // Already initialized
    }

    final db = SupabaseService();
    StreamSubscription<Position>? gpsSub;
    String? tripId;
    String? vehicleName;
    int uploadCount = 0;

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      gpsSub?.cancel();
      service.stopSelf();
    });

    service.on('startTracking').listen((event) {
      gpsSub?.cancel();
      tripId = event?['tripId'] as String?;
      vehicleName = event?['vehicleName'] as String?;
      uploadCount = 0;

      if (tripId == null) return;

      // Start geolocator stream inside background thread
      final locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // capture all updates
        intervalDuration: const Duration(seconds: 3), // 3s telemetry interval
        forceLocationManager: true,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "MAVIO is tracking your bus location in the background for active student routing.",
          notificationTitle: "MAVIO Smart Transit Active",
          enableWakeLock: true,
        ),
      );

      gpsSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
        if (tripId == null) return;

        try {
          // Push update directly to DB from background isolate
          await db.sendLocationUpdate(
            tripId: tripId!,
            latitude: position.latitude,
            longitude: position.longitude,
            speed: position.speed * 3.6, // convert m/s to km/h
            heading: position.heading,
            accuracy: position.accuracy,
          );

          uploadCount++;

          // Update Notification content in foreground
          if (service is AndroidServiceInstance) {
            if (await service.isForegroundService()) {
              service.setForegroundNotificationInfo(
                title: "MAVIO: ${vehicleName ?? 'Bus'} is Live",
                content: "Speed: ${(position.speed * 3.6).toStringAsFixed(1)} km/h • Uploads: $uploadCount",
              );
            }
          }

          // Broadcast stats back to UI
          service.invoke('updateStats', {
            'speed': position.speed * 3.6,
            'uploads': uploadCount,
            'latitude': position.latitude,
            'longitude': position.longitude,
          });

        } catch (e) {
          print("Background upload error: $e");
        }
      }, onError: (err) {
        print("Background GPS stream error: $err");
      });
    });
  }
}
