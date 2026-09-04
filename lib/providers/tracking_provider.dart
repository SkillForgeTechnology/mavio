import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/services/push_notification_service.dart';
import '../core/services/supabase_service.dart';
import '../models/models.dart';

class TrackingProvider extends ChangeNotifier {
  final SupabaseService _db = SupabaseService();

  bool _isLoading = false;
  MavioVehicle? _assignedVehicle;

  MavioTrip? _activeTrip;
  String _driverName = "Not Assigned";
  String _driverEmail = "";
  String _driverPhone = "";
  MavioLocationUpdate? _latestLocation;
  List<LatLng> _tripPath = [];
  StreamSubscription<MavioLocationUpdate>? _locationSub;
  Timer? _tripCheckTimer;
  final Set<String> _notifiedTripIds = {};

  bool get isLoading => _isLoading;
  MavioVehicle? get assignedVehicle => _assignedVehicle;

  MavioTrip? get activeTrip => _activeTrip;
  String get driverName => _driverName;
  String get driverEmail => _driverEmail;
  String get driverPhone => _driverPhone;
  MavioLocationUpdate? get latestLocation => _latestLocation;
  List<LatLng> get tripPath => _tripPath;

  bool get isTripLive => _activeTrip != null && _activeTrip!.status == 'ACTIVE';

  // Fetch student dashboard details and set up stream
  Future<void> loadStudentDashboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _db.getStudentDashboardData();
      _assignedVehicle = data['vehicle'] as MavioVehicle?;

      _activeTrip = data['activeTrip'] as MavioTrip?;
      _driverName = data['driverName'] as String? ?? "Not Assigned";
      _driverEmail = data['driverEmail'] as String? ?? "";
      _driverPhone = data['driverPhone'] as String? ?? "";

      // If trip is live, listen to location changes
      if (_activeTrip != null && _activeTrip!.status == 'ACTIVE') {
        _subscribeToLocationUpdates(_activeTrip!.id);
      } else {
        _latestLocation = null;
        _unsubscribeFromLocationUpdates();
      }

      // Start periodic status checking
      _startTripStatusPolling();
    } catch (e) {
      print("Error loading student dashboard: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startTripStatusPolling() {
    _tripCheckTimer?.cancel();
    _tripCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final data = await _db.getStudentDashboardData();
        final newActiveTrip = data['activeTrip'] as MavioTrip?;
        
        bool changed = false;
        if (newActiveTrip?.id != _activeTrip?.id || newActiveTrip?.status != _activeTrip?.status) {
          changed = true;
        }

        if (changed) {
          _activeTrip = newActiveTrip;
          _driverName = data['driverName'] as String? ?? "Not Assigned";
          _driverEmail = data['driverEmail'] as String? ?? "";
          _driverPhone = data['driverPhone'] as String? ?? "";
          
          if (_activeTrip != null && _activeTrip!.status == 'ACTIVE') {
            _subscribeToLocationUpdates(_activeTrip!.id);
          } else {
            _latestLocation = null;
            _unsubscribeFromLocationUpdates();
          }
          notifyListeners();
        }
      } catch (e) {
        print("Error polling trip status: $e");
      }
    });
  }

  Future<void> _subscribeToLocationUpdates(String tripId) async {
    _locationSub?.cancel();
    _tripPath = [];
    try {
      final coords = await _db.getTripPathCoordinates(tripId);
      _tripPath = coords.map((c) => LatLng(c['latitude']!, c['longitude']!)).toList();
      notifyListeners();
    } catch (e) {
      print("Error fetching initial trip path: $e");
    }

    _locationSub = _db.streamLocationUpdates(tripId).listen((update) {
      _latestLocation = update;
      final newPoint = LatLng(update.latitude, update.longitude);
      if (_tripPath.isEmpty || _tripPath.last != newPoint) {
        _tripPath.add(newPoint);
      }

      // Check proximity alert for student stop radius
      _checkProximityAlert(tripId, update);

      notifyListeners();
    }, onError: (err) {
      print("Error in location stream: $err");
    });
  }

  void _checkProximityAlert(String tripId, MavioLocationUpdate update) {
    final profile = _db.currentUserProfile;
    if (profile == null ||
        profile.alertLatitude == null ||
        profile.alertLongitude == null) {
      return;
    }

    if (_notifiedTripIds.contains(tripId)) return;

    final distance = Geolocator.distanceBetween(
      update.latitude,
      update.longitude,
      profile.alertLatitude!,
      profile.alertLongitude!,
    );

    final radius = (profile.alertRadiusMeters > 0) ? profile.alertRadiusMeters : 500;
    if (distance <= radius) {
      _notifiedTripIds.add(tripId);

      final busName = _assignedVehicle?.name ?? 'Your Bus';
      final distanceStr = distance < 1000
          ? "${distance.round()}m"
          : "${(distance / 1000).toStringAsFixed(1)}km";

      final alertTitle = "🚌 Bus Approaching!";
      final alertBody =
          "$busName has entered your alert zone ($distanceStr away, ${radius}m radius). Please be ready at your stop!";

      // 1. Show instant Heads-Up Local Notification
      PushNotificationService.showLocalNotification(
        title: alertTitle,
        body: alertBody,
      );

      // 2. Dispatch OneSignal Push Notification if subscription ID exists
      if (profile.onesignalId != null && profile.onesignalId!.isNotEmpty) {
        PushNotificationService.sendPushNotification(
          subscriptionIds: [profile.onesignalId!],
          title: alertTitle,
          body: alertBody,
          data: {'tripId': tripId, 'busNumber': busName},
        );
      }
    }
  }

  void _unsubscribeFromLocationUpdates() {
    _locationSub?.cancel();
    _locationSub = null;
    _tripPath = [];
  }

  @override
  void dispose() {
    _tripCheckTimer?.cancel();
    _unsubscribeFromLocationUpdates();
    super.dispose();
  }
}
