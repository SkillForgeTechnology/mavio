import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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
  String? vehicleId;
  String? vehicleName;
  int uploadCount = 0;
  final List<_StudentProximityTarget> studentTargets = [];

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
    studentTargets.clear();
    service.stopSelf();
  });

  service.on('startTracking').listen((event) async {
    gpsSub?.cancel();
    studentTargets.clear();
    tripId = event?['tripId'] as String?;
    vehicleId = event?['vehicleId'] as String?;
    vehicleName = event?['vehicleName'] as String?;
    uploadCount = 0;

    if (tripId == null) return;

    // Load all students assigned to this vehicle with active stop alerts
    final List<dynamic>? passedStudents = event?['students'] as List<dynamic>?;
    if (passedStudents != null && passedStudents.isNotEmpty) {
      final List<String> allSubIds = [];
      final List<String> allUserIds = [];

      for (var s in passedStudents) {
        final lat = s['alert_latitude'] != null ? (s['alert_latitude'] as num).toDouble() : null;
        final lon = s['alert_longitude'] != null ? (s['alert_longitude'] as num).toDouble() : null;
        final radius = s['alert_radius_meters'] as int? ?? 500;
        final onesignalId = s['onesignal_id'] as String?;
        final studentId = s['id'] as String;

        allUserIds.add(studentId);
        if (onesignalId != null && onesignalId.isNotEmpty) {
          allSubIds.add(onesignalId);
        }

        if (lat != null && lon != null) {
          studentTargets.add(_StudentProximityTarget(
            id: studentId,
            name: s['name'] as String? ?? 'Student',
            onesignalId: onesignalId,
            lat: lat,
            lon: lon,
            radius: radius,
          ));
        }
      }
      print("MAVIO Background: Loaded ${studentTargets.length} student proximity targets from foreground for vehicle $vehicleId");
    } else if (vehicleId != null && vehicleId!.isNotEmpty) {
      try {
        final List<dynamic> students = await client
            .from('profiles')
            .select('id, name, onesignal_id, alert_latitude, alert_longitude, alert_radius_meters')
            .eq('assigned_vehicle_id', vehicleId!)
            .eq('role', 'student');

        final List<String> allSubIds = [];
        final List<String> allUserIds = [];

        for (var s in students) {
          final lat = s['alert_latitude'] != null ? (s['alert_latitude'] as num).toDouble() : null;
          final lon = s['alert_longitude'] != null ? (s['alert_longitude'] as num).toDouble() : null;
          final radius = s['alert_radius_meters'] as int? ?? 500;
          final onesignalId = s['onesignal_id'] as String?;
          final studentId = s['id'] as String;

          allUserIds.add(studentId);
          if (onesignalId != null && onesignalId.isNotEmpty) {
            allSubIds.add(onesignalId);
          }

          if (lat != null && lon != null) {
            studentTargets.add(_StudentProximityTarget(
              id: studentId,
              name: s['name'] as String? ?? 'Student',
              onesignalId: onesignalId,
              lat: lat,
              lon: lon,
              radius: radius,
            ));
          }
        }
        print("MAVIO Background: Loaded ${studentTargets.length} student proximity targets for vehicle $vehicleId");
      } catch (e) {
        print("MAVIO Background: Error fetching student targets: $e");
      }
    }

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

        // Check proximity for each assigned student
        for (var target in studentTargets) {
          if (!target.hasNotified) {
            final distance = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              target.lat,
              target.lon,
            );

            if (distance <= target.radius) {
              target.hasNotified = true;
              final distText = distance < 1000
                  ? "${distance.round()}m"
                  : "${(distance / 1000).toStringAsFixed(1)}km";

              _sendBackgroundProximityPush(
                subscriptionIds: target.onesignalId != null ? [target.onesignalId!] : null,
                externalUserIds: [target.id],
                title: "🚌 Bus Approaching!",
                body:
                    "${vehicleName ?? 'Your school bus'} is approaching your stop ($distText away). Please be ready!",
                tripId: tripId!,
                busNumber: vehicleName ?? 'Mavio Bus',
              );
            }
          }
        }

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

class _StudentProximityTarget {
  final String id;
  final String name;
  final String? onesignalId;
  final double lat;
  final double lon;
  final int radius;
  bool hasNotified = false;

  _StudentProximityTarget({
    required this.id,
    required this.name,
    this.onesignalId,
    required this.lat,
    required this.lon,
    required this.radius,
  });
}

Future<void> _sendBackgroundProximityPush({
  List<String>? subscriptionIds,
  List<String>? externalUserIds,
  required String title,
  required String body,
  required String tripId,
  required String busNumber,
}) async {
  const String appId = "2633169a-2c5f-4856-bfd3-12361105dc17";
  const String restApiKey = String.fromEnvironment('ONESIGNAL_REST_API_KEY');

  final subIds = subscriptionIds?.where((id) => id.isNotEmpty).toList() ?? [];
  final userIds = externalUserIds?.where((id) => id.isNotEmpty).toList() ?? [];

  if (subIds.isEmpty && userIds.isEmpty) return;

  try {
    final url = Uri.parse('https://onesignal.com/api/v1/notifications');

    // 1. Send via OneSignal Subscription IDs if available (direct & unique)
    if (subIds.isNotEmpty) {
      final payload = {
        'app_id': appId,
        'include_subscription_ids': subIds,
        'headings': {'en': title},
        'contents': {'en': body},
        'data': {'tripId': tripId, 'busNumber': busNumber},
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
      print("MAVIO Background Push: ${response.statusCode}");
    } else if (userIds.isNotEmpty) {
      // 2. Fallback to External User ID alias only if no subscription IDs are present
      final payload = {
        'app_id': appId,
        'include_aliases': {'external_id': userIds},
        'target_channel': 'push',
        'headings': {'en': title},
        'contents': {'en': body},
        'data': {'tripId': tripId, 'busNumber': busNumber},
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
      print("MAVIO Background Alias Push: ${response.statusCode}");
    }
  } catch (e) {
    print("MAVIO Background Push error: $e");
  }
}

class BackgroundLocationService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || _isInitialized) return;

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
        initialNotificationContent: 'GPS broadcast active...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    _isInitialized = true;
  }
}
