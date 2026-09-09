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
  double lastSpeed = 0.0;
  double? lastLat;
  double? lastLng;
  final List<_StudentProximityTarget> studentTargets = [];

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('getStats').listen((event) {
    service.invoke('updateStats', {
      'speed': lastSpeed,
      'uploads': uploadCount,
      'latitude': lastLat,
      'longitude': lastLng,
      'isTracking': tripId != null && gpsSub != null,
      'tripId': tripId,
    });
  });

  service.on('stopService').listen((event) {
    gpsSub?.cancel();
    gpsSub = null;
    studentTargets.clear();
    tripId = null;
    uploadCount = 0;
    service.stopSelf();
  });

  service.on('startTracking').listen((event) async {
    final incomingTripId = event?['tripId'] as String?;
    if (incomingTripId == null) return;

    // If this exact trip is ALREADY tracking in background, do NOT restart or reset uploadCount
    if (tripId == incomingTripId && gpsSub != null) {
      print("MAVIO Background: Trip $tripId is already actively running. Retaining uploadCount: $uploadCount");
      service.invoke('updateStats', {
        'speed': lastSpeed,
        'uploads': uploadCount,
        'latitude': lastLat,
        'longitude': lastLng,
        'isTracking': true,
        'tripId': tripId,
      });
      return;
    }

    gpsSub?.cancel();
    studentTargets.clear();
    tripId = incomingTripId;
    vehicleId = event?['vehicleId'] as String?;
    vehicleName = event?['vehicleName'] as String?;

    // If initial count is passed from database/UI, start from that count
    final initialUploads = event?['initialUploads'] as int?;
    if (initialUploads != null && initialUploads > 0) {
      uploadCount = initialUploads;
    } else {
      // Query existing rows count from DB to ensure seamless continuation
      try {
        final countRes = await client
            .from('location_updates')
            .select('id')
            .eq('trip_id', tripId!)
            .count(CountOption.exact);
        uploadCount = countRes.count;
      } catch (_) {
        uploadCount = 0;
      }
    }

    // Load all students assigned to this vehicle with active stop alerts
    final List<dynamic>? passedStudents = event?['students'] as List<dynamic>?;
    if (passedStudents != null && passedStudents.isNotEmpty) {
      for (var s in passedStudents) {
        final onesignalId = s['onesignal_id'] as String?;
        final studentId = s['id'] as String;
        final lat = s['alert_latitude'] != null ? (s['alert_latitude'] as num).toDouble() : null;
        final lon = s['alert_longitude'] != null ? (s['alert_longitude'] as num).toDouble() : null;
        final radius = s['alert_radius_meters'] as int? ?? 500;

        if (lat != null && lon != null) {
          studentTargets.add(_StudentProximityTarget(
            id: studentId,
            name: s['name'] as String? ?? 'Student',
            onesignalId: onesignalId?.trim(),
            lat: lat,
            lon: lon,
            radius: radius,
          ));
        }
      }
      print("MAVIO Background: Loaded ${studentTargets.length} active student proximity targets from foreground for vehicle $vehicleId");
    } else if (vehicleId != null && vehicleId!.isNotEmpty) {
      try {
        final List<dynamic> students = await client
            .from('profiles')
            .select('id, name, onesignal_id, alert_latitude, alert_longitude, alert_radius_meters')
            .eq('assigned_vehicle_id', vehicleId!)
            .eq('role', 'student');

        for (var s in students) {
          final onesignalId = s['onesignal_id'] as String?;
          final studentId = s['id'] as String;
          final lat = s['alert_latitude'] != null ? (s['alert_latitude'] as num).toDouble() : null;
          final lon = s['alert_longitude'] != null ? (s['alert_longitude'] as num).toDouble() : null;
          final radius = s['alert_radius_meters'] as int? ?? 500;

          if (lat != null && lon != null) {
            studentTargets.add(_StudentProximityTarget(
              id: studentId,
              name: s['name'] as String? ?? 'Student',
              onesignalId: onesignalId?.trim(),
              lat: lat,
              lon: lon,
              radius: radius,
            ));
          }
        }
        print("MAVIO Background: Loaded ${studentTargets.length} active student proximity targets for vehicle $vehicleId");
      } catch (e) {
        print("MAVIO Background: Error fetching student targets: $e");
      }
    }

    // Define reusable position handler that uploads GPS and checks student proximity
    Future<void> handlePosition(Position position) async {
      if (tripId == null) return;

      try {
        lastSpeed = position.speed * 3.6;
        lastLat = position.latitude;
        lastLng = position.longitude;

        // Push update directly to DB from background isolate
        await client.from('location_updates').insert({
          'trip_id': tripId!,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': lastSpeed, // convert m/s to km/h
          'heading': position.heading,
          'accuracy': position.accuracy,
        });

        uploadCount++;

        // 1. Emit live stats to Driver UI on every GPS update
        service.invoke('updateStats', {
          'speed': lastSpeed,
          'uploads': uploadCount,
          'latitude': lastLat,
          'longitude': lastLng,
          'isTracking': true,
          'tripId': tripId,
        });

        // 2. Periodically refresh student targets from Supabase if authenticated (every ~30s / 10 updates)
        if (uploadCount % 10 == 0 && vehicleId != null && vehicleId!.isNotEmpty) {
          try {
            final List<dynamic> freshStudents = await client
                .from('profiles')
                .select('id, name, onesignal_id, alert_latitude, alert_longitude, alert_radius_meters')
                .eq('assigned_vehicle_id', vehicleId!)
                .eq('role', 'student');

            if (freshStudents.isNotEmpty) {
              final Set<String> existingNotifiedIds = studentTargets
                  .where((t) => t.hasNotified)
                  .map((t) => t.id)
                  .toSet();

              final List<_StudentProximityTarget> newTargets = [];
              for (var s in freshStudents) {
                final studentId = s['id'] as String;
                final onesignalId = s['onesignal_id'] as String?;
                final lat = s['alert_latitude'] != null ? (s['alert_latitude'] as num).toDouble() : null;
                final lon = s['alert_longitude'] != null ? (s['alert_longitude'] as num).toDouble() : null;
                final radius = s['alert_radius_meters'] as int? ?? 500;

                if (lat != null && lon != null) {
                  final target = _StudentProximityTarget(
                    id: studentId,
                    name: s['name'] as String? ?? 'Student',
                    onesignalId: onesignalId?.trim(),
                    lat: lat,
                    lon: lon,
                    radius: radius,
                  );
                  if (existingNotifiedIds.contains(studentId)) {
                    target.hasNotified = true;
                  }
                  newTargets.add(target);
                }
              }
              if (newTargets.isNotEmpty) {
                studentTargets.clear();
                studentTargets.addAll(newTargets);
              }
            }
          } catch (e) {
            print("MAVIO Background: Error refreshing student targets (retaining existing targets): $e");
          }
        }

        // 3. Check proximity for each assigned student
        for (var target in studentTargets) {
          if (!target.hasNotified) {
            final distance = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              target.lat,
              target.lon,
            );

            print("MAVIO Proximity Check: Student ${target.name} (${target.id}) is ${distance.round()}m away (radius: ${target.radius}m)");

            if (distance <= target.radius) {
              target.hasNotified = true;
              final distText = distance < 1000
                  ? "${distance.round()}m"
                  : "${(distance / 1000).toStringAsFixed(1)}km";

              final tokens = (target.onesignalId ?? '')
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();

              print("MAVIO Proximity Triggered! Sending push for student ${target.name} ($distText away)");

              await _sendBackgroundProximityPush(
                studentId: target.id,
                subscriptionIds: tokens,
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
              title: "MAVIO Driver: Live Trip Active",
              content:
                  "${vehicleName ?? 'Bus'} | Speed: ${lastSpeed.toStringAsFixed(1)} km/h | Pushed $uploadCount points",
            );
          }
        }
      } catch (e) {
        print("MAVIO Background GPS processing error: $e");
      }
    }

    // Process immediate GPS position right upon starting
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      await handlePosition(initialPosition);
    } catch (e) {
      print("MAVIO Background: Initial position capture warning: $e");
    }

    // Start geolocator stream inside background thread using Google Fused Location
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // capture all updates
      intervalDuration: const Duration(seconds: 3), // 3s telemetry interval
      forceLocationManager: false, // ⚡ Use Google Play Services Fused Location for instant fixes indoors/outdoors
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "MAVIO is tracking your bus location in the background for active student routing.",
        notificationTitle: "MAVIO Smart Transit Active",
        enableWakeLock: true,
      ),
    );

    gpsSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      handlePosition,
      onError: (e) {
        print("MAVIO Background GPS Stream error: $e");
      },
    );
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
  required String studentId,
  required List<String> subscriptionIds,
  required String title,
  required String body,
  required String tripId,
  required String busNumber,
}) async {
  const String appId = OneSignalKeys.appId;
  final String restApiKey = OneSignalKeys.restApiKey;

  final validSubIds = subscriptionIds
      .where((id) => id.trim().isNotEmpty)
      .toSet()
      .toList();

  try {
    final url = Uri.parse('https://api.onesignal.com/notifications');
    final authHeader = restApiKey.startsWith('os_v2_')
        ? 'Key $restApiKey'
        : 'Basic $restApiKey';

    // OneSignal strictly requires collapse_id <= 64 bytes
    final collapseId = 'prox_$studentId';

    // 1. Direct hardware subscription token delivery (most reliable when app is closed)
    if (validSubIds.isNotEmpty) {
      final payloadSub = <String, dynamic>{
        'app_id': appId,
        'include_subscription_ids': validSubIds,
        'target_channel': 'push',
        'headings': {'en': title},
        'contents': {'en': body},
        'data': {'tripId': tripId, 'busNumber': busNumber, 'type': 'proximity_alert'},
        'collapse_id': collapseId,
        'priority': 10,
        'android_visibility': 1,
        'android_accent_color': 'FF1E3A8A',
      };
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': authHeader,
        },
        body: jsonEncode(payloadSub),
      );
      print("MAVIO Background Proximity Direct Push to ${validSubIds.length} devices (student $studentId): ${response.statusCode} - ${response.body}");
    } else if (studentId.trim().isNotEmpty) {
      // 2. Fallback broadcast to external_id alias if subscription IDs are not available
      final payload = <String, dynamic>{
        'app_id': appId,
        'include_aliases': {
          'external_id': [studentId]
        },
        'target_channel': 'push',
        'headings': {'en': title},
        'contents': {'en': body},
        'data': {'tripId': tripId, 'busNumber': busNumber, 'type': 'proximity_alert'},
        'collapse_id': collapseId,
        'priority': 10,
        'android_visibility': 1,
        'android_accent_color': 'FF1E3A8A',
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': authHeader,
        },
        body: jsonEncode(payload),
      );
      print("MAVIO Background Proximity Alias Push to student $studentId: ${response.statusCode} - ${response.body}");
    }
  } catch (e) {
    print("MAVIO Background Proximity Push error: $e");
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
