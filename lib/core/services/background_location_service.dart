import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/keys.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
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

  final client = Supabase.instance.client;
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
        await client.from('location_updates').insert({
          'trip_id': tripId!,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': position.speed * 3.6, // convert m/s to km/h
          'heading': position.heading,
          'accuracy': position.accuracy,
        });

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

class BackgroundLocationService {
  static Future<void> initialize() async {
    if (kIsWeb) return;
    final service = FlutterBackgroundService();

    // Create Notification Channel for Android 13/14 compatibility
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'mavio_location_channel', // id
      'MAVIO Live GPS Tracking', // name
      description: 'This channel is used for displaying live trip tracking details.',
      importance: Importance.low,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Explicitly start only when driver starts a trip
        isForegroundMode: true,
        notificationChannelId: 'mavio_location_channel', // Use created channel ID
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
}
